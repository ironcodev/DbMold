-- ============================================================================
-- $(SchemaName).create_column
--
-- Idempotent create-or-alter of a table column driven by a JSON spec.
--
-- Spec:
--   {
--     "table":        "required, {db}.{schema}.{table}",
--     "name":         "required, column name",
--     "type":         "required unless computed, e.g. varchar(100), dbo.MyUDT",
--     "nullable":     "optional, default false",
--     "sparse":       "optional, default false",
--     "identity":     "optional object { seed, increment }, create-only",
--     "default":      "optional, default value expression, e.g. \"'hello'\", \"(getdate())\"",
--     "default_name": "optional, default constraint name; otherwise existing/DF_{table}_{column}",
--     "computed":     "optional object { expression, persisted }; type is ignored",
--     "dryRun":       "optional, returns the script without executing",
--     "timeout":      "optional, lock timeout ms (default 10000 for applock)"
--   }
--
-- Contract:
--   * Always createOrAlter; always errors on unsupported scenarios.
--   * Existing column + FK or index participation  -> error listing blockers.
--   * Existing identity/computed columns are preserved; drift that requires
--     a rebuild raises a descriptive error.
--   * "default" omitted => existing default left untouched.
--   * Result set: one row per executed/planned action, or 'NO CHANGE'.
--     With dryRun = 1 the [sql] column is the exact executable script.
-- ============================================================================
create or alter procedure $(SchemaName).create_column
    @spec nvarchar(max)
as
begin
    set nocount on;
    set xact_abort on;

    declare @msg nvarchar(2048), @sql nvarchar(max);

    ------------------------------------------------------------------
    -- 1. Validate spec
    ------------------------------------------------------------------
    if @spec is null or isjson(@spec) <> 1
        throw 50001, 'create_column: @spec must be a valid JSON object.', 1;

    -- reject unknown keys (catches typos like "spare": true)
    select @msg = string_agg(j.[key], ', ')
    from openjson(@spec) j
    where j.[key] not in ('table','name','type','nullable','sparse','identity',
                          'default','default_name','computed','dryRun','timeout');
    if @msg is not null
    begin
        set @msg = 'create_column: unknown spec properties: ' + @msg;
        throw 50001, @msg, 1;
    end

    declare @tableName   nvarchar(1000) = json_value(@spec, '$.table');
    declare @colName     nvarchar(500)  = json_value(@spec, '$.name');
    declare @typeName    nvarchar(500)  = json_value(@spec, '$.type');
    declare @defaultName nvarchar(500)  = json_value(@spec, '$.default_name');
    declare @timeout     int            = try_convert(int, json_value(@spec, '$.timeout'));

    declare @nullable bit = case json_value(@spec, '$.nullable') when 'true' then 1 when 'false' then 0 end;
    declare @sparse   bit = case json_value(@spec, '$.sparse')   when 'true' then 1 when 'false' then 0 end;
    declare @dryRun   bit = case json_value(@spec, '$.dryRun')   when 'true' then 1 when 'false' then 0 end;
    set @nullable = coalesce(@nullable, 0);
    set @sparse   = coalesce(@sparse, 0);
    set @dryRun   = coalesce(@dryRun, 0);

    -- long strings: JSON_VALUE truncates at 4000
    declare @defaultVal nvarchar(max);
    select @defaultVal = convert(nvarchar(max), [value]) from openjson(@spec) where [key] = 'default';

    -- presence of an OBJECT means specified; null/absent means unspecified
    declare @hasComputed bit = case when exists (select 1 from openjson(@spec) where [key] = 'computed' and [type] = 5) then 1 else 0 end;
    declare @hasIdentity bit = case when exists (select 1 from openjson(@spec) where [key] = 'identity' and [type] = 5) then 1 else 0 end;

    declare @expr nvarchar(max), @persisted bit;
    if @hasComputed = 1
    begin
        select @expr = convert(nvarchar(max), [value]) from openjson(@spec, '$.computed') where [key] = 'expression';
        set @persisted = case (select convert(nvarchar(100), [value]) from openjson(@spec, '$.computed') where [key] = 'persisted')
                         when 'true' then 1 when 'false' then 0 end;
        set @persisted = coalesce(@persisted, 0);
    end

    declare @idSeed int = 1, @idIncr int = 1;
    if @hasIdentity = 1
    begin
        select @idSeed = coalesce(try_convert(int, [value]), 1) from openjson(@spec, '$.identity') where [key] = 'seed';
        select @idIncr = coalesce(try_convert(int, [value]), 1) from openjson(@spec, '$.identity') where [key] = 'increment';
    end

    if nullif(ltrim(rtrim(@tableName)), '') is null throw 50001, 'create_column: "table" is required.', 1;
    if nullif(ltrim(rtrim(@colName)), '')   is null throw 50001, 'create_column: "name" is required.', 1;
    if @hasComputed = 0 and nullif(ltrim(rtrim(@typeName)), '') is null
        throw 50001, 'create_column: "type" is required unless "computed" is provided.', 1;
    if @timeout is not null and @timeout < -1
        throw 50001, 'create_column: "timeout" must be >= -1.', 1;
    if @defaultName is not null and len(@defaultName) > 128
        throw 50001, 'create_column: "default_name" exceeds 128 characters.', 1;

    if @hasComputed = 1 and @hasIdentity = 1
        throw 50001, 'create_column: "computed" cannot be combined with "identity".', 1;
    if @hasComputed = 1 and @sparse = 1
        throw 50001, 'create_column: "computed" cannot be combined with "sparse".', 1;
    if @hasComputed = 1 and @defaultVal is not null
        throw 50001, 'create_column: "computed" cannot be combined with "default".', 1;

    ------------------------------------------------------------------
    -- 2. Resolve identifiers
    ------------------------------------------------------------------
    declare @db sysname, @sch sysname, @tbl sysname;
    select @db  = coalesce(nullif([db], ''), db_name()),
           @sch = coalesce(nullif([schema], ''), 'dbo'),
           @tbl = [table]
    from $(SchemaName).parse_table_name(@tableName);

    -- defensive: strip a single pair of wrapping brackets if the parser
    -- returns bracketed parts (e.g. [My.Table]); QUOTENAME re-adds them.
    set @colName = case when left(@colName,1)='[' and right(@colName,1)=']'
                         and charindex(']', substring(@colName,2,len(@colName)-2)) = 0
                        then substring(@colName,2,len(@colName)-2) else @colName end;
    set @tbl = case when left(@tbl,1)='[' and right(@tbl,1)=']'
                     and charindex(']', substring(@tbl,2,len(@tbl)-2)) = 0
                    then substring(@tbl,2,len(@tbl)-2) else @tbl end;
    set @sch = case when left(@sch,1)='[' and right(@sch,1)=']'
                     and charindex(']', substring(@sch,2,len(@sch)-2)) = 0
                    then substring(@sch,2,len(@sch)-2) else @sch end;
    set @db  = case when left(@db,1)='[' and right(@db,1)=']'
                     and charindex(']', substring(@db,2,len(@db)-2)) = 0
                    then substring(@db,2,len(@db)-2) else @db end;

    if @tbl is null or @tbl = '' throw 50001, 'create_column: could not parse "table".', 1;

    ------------------------------------------------------------------
    -- 3. Serialize concurrent runs on this table
    ------------------------------------------------------------------
    declare @prevLockTimeout int = @@lock_timeout;
    declare @lockKey nvarchar(255) = '$(SchemaName).create_column:' + @db + '.' + @sch + '.' + @tbl;
    declare @lockRc int;

    exec @lockRc = sys.sp_getapplock
        @Resource = @lockKey, @LockMode = 'Exclusive',
        @LockOwner = 'Session', @LockTimeout = coalesce(@timeout, 10000);
    if @lockRc < 0
        throw 50001, 'create_column: could not acquire the application lock (timeout or deadlock); retry.', 1;

    if @timeout is not null
    begin
        set @sql = N'set lock_timeout ' + convert(varchar(20), @timeout) + N';';
        exec sp_executesql @sql;
    end

    declare @plan table (step int identity(1,1), action nvarchar(60) not null, [sql] nvarchar(max) not null);

    begin try
        ------------------------------------------------------------------
        -- 4. Snapshot current state (all cross-db catalog access is here)
        ------------------------------------------------------------------
        declare @oid bigint;
        set @sql = N'select @oid = o.object_id
                     from ' + quotename(@db) + N'.sys.objects o
                     join ' + quotename(@db) + N'.sys.schemas s on s.schema_id = o.schema_id
                     where o.name = @t and s.name = @s and o.type = ''U'';';
        exec sp_executesql @sql, N'@t sysname, @s sysname, @oid bigint output', @tbl, @sch, @oid output;
        if @oid is null
        begin
            set @msg = 'create_column: table ' + @db + '.' + @sch + '.' + @tbl + ' not found (or not a user table).';
            throw 50001, @msg, 1;
        end

        declare @colId int, @curTypeId int, @curSysTypeId int, @curMaxLen int, @curPrec int, @curScale int,
                @curNullable bit, @curSparse bit, @curComputed bit, @curIdentity bit,
                @curComputedDef nvarchar(max), @curPersisted bit, @curSeed bigint, @curIncr bigint,
                @curDefaultName sysname, @curDefaultDef nvarchar(max);

        set @sql = N'
            select @colId = c.column_id, @curTypeId = c.user_type_id, @curSysTypeId = c.system_type_id,
                   @curMaxLen = c.max_length, @curPrec = c.[precision], @curScale = c.scale,
                   @curNullable = c.is_nullable, @curSparse = c.is_sparse, @curComputed = c.is_computed,
                   @curIdentity = convert(bit, case when ic.object_id is null then 0 else 1 end),
                   @curComputedDef = cc.definition, @curPersisted = convert(bit, coalesce(cc.is_persisted, 0)),
                   @curSeed = convert(bigint, ic.seed_value), @curIncr = convert(bigint, ic.increment_value),
                   @curDefaultName = dc.name, @curDefaultDef = dc.definition
            from ' + quotename(@db) + N'.sys.columns c
            left join ' + quotename(@db) + N'.sys.computed_columns cc
                   on cc.object_id = c.object_id and cc.column_id = c.column_id
            left join ' + quotename(@db) + N'.sys.identity_columns ic
                   on ic.object_id = c.object_id and ic.column_id = c.column_id
            left join ' + quotename(@db) + N'.sys.default_constraints dc
                   on dc.parent_object_id = c.object_id and dc.parent_column_id = c.column_id
            where c.object_id = @oid and c.name = @cn;';
        exec sp_executesql @sql,
            N'@oid bigint, @cn sysname, @colId int output, @curTypeId int output, @curSysTypeId int output,
              @curMaxLen int output, @curPrec int output, @curScale int output, @curNullable bit output,
              @curSparse bit output, @curComputed bit output, @curIdentity bit output,
              @curComputedDef nvarchar(max) output, @curPersisted bit output, @curSeed bigint output,
              @curIncr bigint output, @curDefaultName sysname output, @curDefaultDef nvarchar(max) output',
            @oid, @colName,
            @colId output, @curTypeId output, @curSysTypeId output, @curMaxLen output, @curPrec output,
            @curScale output, @curNullable output, @curSparse output, @curComputed output, @curIdentity output,
            @curComputedDef output, @curPersisted output, @curSeed output, @curIncr output,
            @curDefaultName output, @curDefaultDef output;

        ------------------------------------------------------------------
        -- 5. v1 guardrails: refuse FK/index-bound columns
        ------------------------------------------------------------------
        if @colId is not null
        begin
            declare @blockers nvarchar(max);
            set @sql = N'
                select @blockers = string_agg(x.b, ''; '')
                from (
                    select ''FK '' + fk.name as b
                    from ' + quotename(@db) + N'.sys.foreign_keys fk
                    join ' + quotename(@db) + N'.sys.foreign_key_columns fkc
                      on fkc.constraint_object_id = fk.object_id
                    where (fkc.parent_object_id = @oid and fkc.parent_column_id = @cid)
                       or (fkc.referenced_object_id = @oid and fkc.referenced_column_id = @cid)
                    union all
                    select ''INDEX '' + i.name
                    from ' + quotename(@db) + N'.sys.indexes i
                    join ' + quotename(@db) + N'.sys.index_columns ic
                      on ic.object_id = i.object_id and ic.index_id = i.index_id
                    where ic.object_id = @oid and ic.column_id = @cid
                      and i.index_id > 0 and i.is_hypothetical = 0
                ) x;';
            exec sp_executesql @sql, N'@oid bigint, @cid int, @blockers nvarchar(max) output',
                @oid, @colId, @blockers output;

            if @blockers is not null
            begin
                set @msg = 'create_column: column already exists and is referenced by: ' + @blockers
                         + '. Drop these first, then retry.';
                throw 50001, @msg, 1;
            end
        end

        ------------------------------------------------------------------
        -- 6. Plan
        ------------------------------------------------------------------
        declare @prefix nvarchar(600) = N'use ' + quotename(@db) + N';' + char(10)
                                     + N'alter table ' + quotename(@sch) + N'.' + quotename(@tbl) + N' ';
        declare @qcol sysname = quotename(@colName);

        if @hasComputed = 1
        begin
            if nullif(ltrim(rtrim(@expr)), '') is null
                throw 50001, 'create_column: "computed.expression" is required.', 1;

            if @colId is null
            begin
                insert @plan (action, [sql]) values (N'CREATE COMPUTED COLUMN',
                    @prefix + N'add ' + @qcol + N' as (' + @expr + N')'
                    + case when @persisted = 1 then N' persisted' end + N';');
            end
            else
            begin
                if @curComputed = 0
                    throw 50001, 'create_column: column exists and is not computed; conversion is not supported.', 1;

                -- normalized text compare (paren-stripping helper; case-insensitive for identifiers)
                declare @nExpr nvarchar(max) = lower(ltrim(rtrim($(SchemaName)._normalize_default(@expr))));
                declare @nCur  nvarchar(max) = lower(ltrim(rtrim($(SchemaName)._normalize_default(@curComputedDef))));

                if @nExpr <> @nCur
                    throw 50001, 'create_column: cannot alter a computed column expression; drop and recreate it manually.', 1;

                if @persisted <> @curPersisted
                    insert @plan (action, [sql]) values (N'ALTER PERSISTED',
                        @prefix + N'alter column ' + @qcol
                        + case when @persisted = 1 then N' add persisted' else N' drop persisted' end + N';');
            end
        end
        else
        begin
            -- parse + resolve type against TARGET database catalog
            declare @p_sch sysname, @p_name sysname, @p_maxlen int, @p_prec int, @p_scale int,
                    @p_cat bit, @p_frag nvarchar(500), @p_err nvarchar(400);
            select @p_sch = t.[schema], @p_name = t.name, @p_maxlen = t.max_length, @p_prec = t.[precision],
                   @p_scale = t.scale, @p_cat = t.needs_catalog, @p_frag = t.ddl_fragment, @p_err = t.[error]
            from $(SchemaName).parse_column_type(@typeName) t;

            if @p_err is not null
            begin
                set @msg = 'create_column: invalid type "' + @typeName + '": ' + @p_err;
                throw 50001, @msg, 1;
            end

            declare @tid int, @stid int, @isAsm bit, @isTblType bit;
            set @sql = N'
                select top (1) @tid = t.user_type_id, @stid = t.system_type_id,
                       @isAsm = t.is_assembly_type, @isTblType = t.is_table_type
                from ' + quotename(@db) + N'.sys.types t
                left join ' + quotename(@db) + N'.sys.schemas s on s.schema_id = t.schema_id
                where t.name = @n
                  and ( @pcat = 0 and t.is_user_defined = 0
                     or @pcat = 1 and ( @psch is null or s.name = @psch ) )
                order by t.is_user_defined asc;';
            exec sp_executesql @sql,
                N'@n sysname, @pcat bit, @psch sysname, @tid int output, @stid int output, @isAsm bit output, @isTblType bit output',
                @p_name, @p_cat, @p_sch, @tid output, @stid output, @isAsm output, @isTblType output;

            if @tid is null
            begin
                set @msg = 'create_column: unknown data type "' + @typeName + '" in database ' + @db + '.';
                throw 50001, @msg, 1;
            end
            if @isAsm = 1 throw 50001, 'create_column: CLR types are not supported.', 1;
            if @isTblType = 1 throw 50001, 'create_column: table types cannot be used as column types.', 1;

            -- identity / sparse rules
            if @hasIdentity = 1
            begin
                if @stid not in (48, 52, 56, 127, 106, 108) -- tinyint, smallint, int, bigint, decimal, numeric
                    throw 50001, 'create_column: identity requires tinyint, smallint, int, bigint, decimal(p,0) or numeric(p,0).', 1;
                if @stid in (106, 108) and @p_scale <> 0
                    throw 50001, 'create_column: identity requires scale 0 for decimal/numeric.', 1;
                if @nullable = 1
                    throw 50001, 'create_column: identity columns must be NOT NULL (omit "nullable" or set it to false).', 1;
            end

            if @sparse = 1
            begin
                if @stid in (34, 35, 99, 189) or @p_name in ('geometry', 'geography') or @p_cat = 1
                    throw 50001, 'create_column: sparse is not supported for this data type.', 1;
                if @hasIdentity = 1
                    throw 50001, 'create_column: sparse cannot be combined with identity.', 1;
            end

            if @colId is null
            begin
                -- adding NOT NULL to a non-empty table requires a default
                if @nullable = 0 and @defaultVal is null
                begin
                    declare @rc bigint;
                    set @sql = N'select @rc = sum(p.rows) from ' + quotename(@db) + N'.sys.partitions p
                                where p.object_id = @oid and p.index_id in (0, 1);';
                    exec sp_executesql @sql, N'@oid bigint, @rc bigint output', @oid, @rc output;
                    if @rc > 0
                        throw 50001, 'create_column: adding a NOT NULL column to a non-empty table requires a "default".', 1;
                end

                declare @frag nvarchar(max) = @qcol + N' ' + @p_frag
                    + case when @sparse = 1 then N' sparse' end
                    + case when @nullable = 0 then N' not null' else N' null' end
                    + case when @hasIdentity = 1
                           then N' identity(' + convert(varchar(20), @idSeed) + N',' + convert(varchar(20), @idIncr) + N')'
                      end;

                insert @plan (action, [sql]) values (N'CREATE COLUMN', @prefix + N'add ' + @frag + N';');
            end
            else
            begin
                if @curComputed = 1
                    throw 50001, 'create_column: the existing column is computed; provide a "computed" spec instead.', 1;

                -- identity columns must restate IDENTITY in ALTER COLUMN
                declare @idFrag nvarchar(100) = N'';
                if @curIdentity = 1
                begin
                    if @hasIdentity = 1 and (@curSeed <> @idSeed or @curIncr <> @idIncr)
                        throw 50001, 'create_column: identity seed/increment differ; cannot be altered in place.', 1;
                    set @idFrag = N' identity(' + convert(varchar(20), @curSeed) + N',' + convert(varchar(20), @curIncr) + N')';
                end
                else if @hasIdentity = 1
                    throw 50001, 'create_column: cannot add identity to an existing column (table rebuild required).', 1;

                -- type drift (lossless, same-family only)
                declare @typeChanged bit = case
                    when @curTypeId <> @tid then 1
                    when @p_maxlen is not null and @p_maxlen <> @curMaxLen then 1
                    when @p_prec  is not null and @p_prec  <> @curPrec  then 1
                    when @p_scale is not null and @p_scale <> @curScale then 1
                    else 0 end;

                if @typeChanged = 1
                begin
                    if @curSysTypeId <> @stid
                        throw 50001, 'create_column: changing to a different data type family is not supported.', 1;

                    if @p_name in ('char','varchar','binary','varbinary','nchar','nvarchar')
                    begin
                        if not (@p_maxlen = -1 or @p_maxlen >= @curMaxLen)
                            throw 50001, 'create_column: narrowing a character/binary type is not supported.', 1;
                    end
                    else if @p_name in ('decimal','numeric')
                    begin
                        if @p_prec < @curPrec or @p_scale <> @curScale
                            throw 50001, 'create_column: decimal/numeric changes must grow precision and keep scale unchanged.', 1;
                    end
                    else if @p_name = 'float'
                    begin
                        if @p_prec < @curPrec
                            throw 50001, 'create_column: narrowing float is not supported.', 1;
                    end
                    else if @p_name in ('time','datetime2','datetimeoffset')
                    begin
                        if @p_scale < @curScale
                            throw 50001, 'create_column: reducing scale is not supported.', 1;
                    end
                    else
                        throw 50001, 'create_column: this type change is not supported in place.', 1;
                end

                declare @nullChanged bit = case when @nullable <> @curNullable then 1 else 0 end;
                declare @sparseChanged bit = case when @sparse <> @curSparse then 1 else 0 end;

                if @nullChanged = 1 and @nullable = 0
                begin
                    declare @nc bigint;
                    set @sql = N'use ' + quotename(@db) + N'; select @nc = count_big(*) from '
                             + quotename(@sch) + N'.' + quotename(@tbl) + N' where ' + @qcol + N' is null;';
                    exec sp_executesql @sql, N'@nc bigint output', @nc output;
                    if @nc > 0
                    begin
                        set @msg = 'create_column: cannot set NOT NULL: ' + convert(varchar(20), @nc) + ' row(s) contain NULL.';
                        throw 50001, @msg, 1;
                    end
                end

                if @typeChanged = 1 or @nullChanged = 1 or @sparseChanged = 1
                    insert @plan (action, [sql]) values (N'ALTER COLUMN',
                        @prefix + N'alter column ' + @qcol + N' ' + @p_frag
                        + N' ' + case when @nullable = 0 then N'not null' else N'null' end
                        + case when @sparse = 1 then N' sparse' end
                        + @idFrag + N';');
            end

            ------------------------------------------------------------------
            -- 7. Default convergence (both create and alter paths)
            --    exact normalized-text compare: literals are never lowercased,
            --    so 'Hello' vs 'hello' defaults are correctly treated as different
            ------------------------------------------------------------------
            if @defaultVal is not null
            begin
                declare @normNew nvarchar(max) = $(SchemaName)._normalize_default(@defaultVal);
                declare @normCur nvarchar(max) = $(SchemaName)._normalize_default(@curDefaultDef);

                if @normCur is null
                begin
                    insert @plan (action, [sql]) values (N'ADD DEFAULT',
                        @prefix + N'add constraint ' + quotename(coalesce(@defaultName, N'DF_' + @tbl + N'_' + @colName))
                        + N' default (' + @defaultVal + N') for ' + @qcol + N';');
                end
                else if @normCur <> @normNew
                begin
                    insert @plan (action, [sql]) values (N'DROP DEFAULT',
                        @prefix + N'drop constraint ' + quotename(@curDefaultName) + N';');
                    insert @plan (action, [sql]) values (N'ADD DEFAULT',
                        @prefix + N'add constraint ' + quotename(coalesce(@defaultName, @curDefaultName))
                        + N' default (' + @defaultVal + N') for ' + @qcol + N';');
                end
            end
        end

        ------------------------------------------------------------------
        -- 8. Execute (or not)
        ------------------------------------------------------------------
        if @dryRun = 0 and exists (select 1 from @plan)
        begin
            begin transaction;
            declare @stmt nvarchar(max);
            declare cur cursor local fast_forward for select [sql] from @plan order by step;
            open cur;
            fetch next from cur into @stmt;
            while @@fetch_status = 0
            begin
                exec sp_executesql @stmt;
                fetch next from cur into @stmt;
            end
            close cur;
            deallocate cur;
            commit transaction;
        end
    end try
    begin catch
        if @@trancount > 0 rollback transaction;
        exec sys.sp_releaseapplock @Resource = @lockKey, @LockOwner = 'Session';
        set @sql = N'set lock_timeout ' + convert(varchar(20), @prevLockTimeout) + N';';
        exec sp_executesql @sql;
        throw;
    end catch

    ------------------------------------------------------------------
    -- 9. Cleanup + result
    ------------------------------------------------------------------
    exec sys.sp_releaseapplock @Resource = @lockKey, @LockOwner = 'Session';
    set @sql = N'set lock_timeout ' + convert(varchar(20), @prevLockTimeout) + N';';
    exec sp_executesql @sql;

    if exists (select 1 from @plan)
        select step, action, [sql] from @plan order by step;
    else
        select 0 as step, 'NO CHANGE' as action, convert(nvarchar(max), null) as [sql];
end
go