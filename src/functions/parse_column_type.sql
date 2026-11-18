-- ============================================================================
-- $(SchemaName).parse_column_type
--
-- Syntactic parser for a column data-type declaration:
--   int, varchar(100), nvarchar(max), decimal(18,2), float(53),
--   datetime2(7), dbo.MyUserDefinedType, sysname
--
-- Returns exactly one row; [error] is NOT NULL when input is invalid.
--
-- Performs NO catalog lookups. For system types the output is complete.
-- For schema-qualified / unknown names, needs_catalog = 1 and the CALLER
-- must resolve name/schema against sys.types in the target database
-- (UDFs cannot span databases; only procs can).
--
-- max_length is in storage bytes, matching sys.columns.max_length:
--   nchar/nvarchar(n) -> n*2 ; char/varchar/binary/varbinary(n) -> n ; max -> -1
-- ============================================================================
create or alter function $(SchemaName).parse_column_type
(
    @type nvarchar(500)
)
returns @result table
(
    [schema]      sysname       null,
    name          sysname       null,
    max_length    int           null,
    [precision]   int           null,
    scale         int           null,
    is_max        bit           null,
    needs_catalog bit           null,
    ddl_fragment  nvarchar(500) null,
    [error]       nvarchar(400) null
)
as
begin
    declare @raw nvarchar(500) = ltrim(rtrim(@type));

    if nullif(@raw, '') is null
    begin
        insert @result ([error]) values ('type is empty');
        return;
    end

    -- ---------- split head / argument list ----------
    declare @p int = charindex('(', @raw);
    declare @head nvarchar(300), @args nvarchar(200);

    if @p > 0
    begin
        if right(@raw, 1) <> ')'
        begin
            insert @result ([error]) values ('unbalanced parentheses');
            return;
        end
        set @head = ltrim(rtrim(left(@raw, @p - 1)));
        set @args = nullif(ltrim(rtrim(substring(@raw, @p + 1, len(@raw) - @p - 1))), '');
    end
    else
    begin
        set @head = @raw;
        set @args = null;
    end

    -- ---------- split [schema.]name (parsename handles brackets) ----------
    if parsename(@head, 3) is not null
    begin
        insert @result ([error]) values ('type name has more than two parts');
        return;
    end

    declare @sch sysname = nullif(parsename(@head, 2), '');
    declare @nam sysname = parsename(@head, 1);

    if @nam is null
    begin
        insert @result ([error]) values ('invalid type name');
        return;
    end

    set @nam = lower(ltrim(rtrim(@nam)));
    set @nam = case @nam when 'integer' then 'int' when 'dec' then 'decimal' else @nam end;

    -- ---------- split up to two arguments (no ordinal dependency) ----------
    declare @a1 nvarchar(100), @a2 nvarchar(100);
    if @args is not null
    begin
        declare @c int = charindex(',', @args);
        if @c = 0
            set @a1 = @args;
        else
        begin
            set @a1 = left(@args, @c - 1);
            set @a2 = substring(@args, @c + 1, 200);
            if charindex(',', @a2) > 0
            begin
                insert @result ([error]) values ('too many arguments');
                return;
            end
        end
        set @a1 = nullif(ltrim(rtrim(@a1)), '');
        set @a2 = nullif(ltrim(rtrim(@a2)), '');
    end

    declare @isMax bit = case when lower(@a1) = 'max' then 1 else 0 end;
    declare @i1 int = case when @isMax = 1 then null else try_convert(int, @a1) end;
    declare @i2 int = try_convert(int, @a2);

    if @a1 is not null and @isMax = 0 and (@i1 is null or @i1 < 0)
    begin
        insert @result ([error]) values ('invalid length/precision: ' + @a1);
        return;
    end
    if @a2 is not null and @i2 is null
    begin
        insert @result ([error]) values ('invalid scale: ' + @a2);
        return;
    end
    if @isMax = 1 and @a2 is not null
    begin
        insert @result ([error]) values ('(max) does not take a second argument');
        return;
    end

    -- ---------- classify ----------
    declare @cat tinyint =
        case
            when @sch is not null then 9
            when @nam in ('bigint','int','smallint','tinyint','bit','date','datetime','smalldatetime',
                          'money','smallmoney','real','uniqueidentifier','xml','sql_variant',
                          'rowversion','timestamp','hierarchyid','geometry','geography') then 1
            when @nam in ('char','varchar','binary','varbinary') then 2
            when @nam in ('nchar','nvarchar') then 3
            when @nam in ('decimal','numeric') then 4
            when @nam = 'float' then 5
            when @nam in ('time','datetime2','datetimeoffset') then 6
            else 9
        end;

    if @cat = 1
    begin
        if @args is not null
        begin
            insert @result ([error]) values ('type ' + @nam + ' does not take arguments');
            return;
        end
        insert @result ([schema], name, needs_catalog, ddl_fragment)
        values (null, @nam, 0, @nam);
        return;
    end

    if @cat in (2, 3)
    begin
        if @a1 is null
        begin
            insert @result ([error]) values ('type ' + @nam + ' requires a length or (max)');
            return;
        end
        declare @lim int = case when @cat = 3 then 4000 else 8000 end;
        if @isMax = 0 and (@i1 < 1 or @i1 > @lim)
        begin
            insert @result ([error]) values ('length for ' + @nam + ' must be between 1 and ' + convert(varchar(10), @lim));
            return;
        end
        insert @result ([schema], name, max_length, is_max, needs_catalog, ddl_fragment)
        values (null, @nam,
                case when @isMax = 1 then -1 when @cat = 3 then @i1 * 2 else @i1 end,
                @isMax, 0,
                @nam + '(' + case when @isMax = 1 then 'max' else convert(varchar(10), @i1) end + ')');
        return;
    end

    if @cat = 4
    begin
        if @i1 is null
        begin
            insert @result ([error]) values ('type ' + @nam + ' requires (precision[, scale])');
            return;
        end
        set @i2 = coalesce(@i2, 0);
        if @i1 < 1 or @i1 > 38 or @i2 < 0 or @i2 > @i1
        begin
            insert @result ([error]) values ('invalid precision/scale for ' + @nam);
            return;
        end
        insert @result ([schema], name, [precision], scale, is_max, needs_catalog, ddl_fragment)
        values (null, @nam, @i1, @i2, 0, 0,
                @nam + '(' + convert(varchar(10), @i1) + ',' + convert(varchar(10), @i2) + ')');
        return;
    end

    if @cat = 5
    begin
        if @i1 is not null and (@i1 < 1 or @i1 > 53)
        begin
            insert @result ([error]) values ('float precision must be between 1 and 53');
            return;
        end
        insert @result ([schema], name, [precision], is_max, needs_catalog, ddl_fragment)
        values (null, 'float', @i1, 0, 0,
                case when @i1 is null then 'float' else 'float(' + convert(varchar(10), @i1) + ')' end);
        return;
    end

    if @cat = 6
    begin
        if @i1 is not null and (@i1 < 0 or @i1 > 7)
        begin
            insert @result ([error]) values ('scale for ' + @nam + ' must be between 0 and 7');
            return;
        end
        insert @result ([schema], name, scale, is_max, needs_catalog, ddl_fragment)
        values (null, @nam, coalesce(@i1, 7), 0, 0,
                case when @i1 is null then @nam else @nam + '(' + convert(varchar(10), @i1) + ')' end);
        return;
    end

    -- ---------- catalog path: alias types and UDTs ----------
    if @args is not null
    begin
        insert @result ([error]) values ('user-defined type ' + coalesce(@sch + '.', '') + @nam + ' does not take arguments');
        return;
    end

    insert @result ([schema], name, needs_catalog, ddl_fragment)
    values (@sch, @nam, 1, coalesce(@sch + '.', '') + @nam);
    return;
end

go