SET ANSI_NULLS ON;
GO

SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- $(SchemaName).create_column
-- =============================================
-- Creates or converges a column on a table from a JSON spec. Idempotent:
-- re-running with the same @spec is safe and produces no side effects.
--
-- Input:
--   @spec  JSON document with the following shape:
--
--   {
--     "table":        "sales.Products",          -- required, dotted name
--     "name":         "DiscountPrice",           -- required
--     "type":         "int",                     -- required unless "computed"
--     "nullable":     true,                      -- optional, default false
--     "sparse":       true,                      -- optional, default false
--     "identity":     { "seed": 1, "increment": 1 },  -- optional
--     "default":      "0",                       -- optional, SQL expression
--     "default_name": "DF_Products_DiscountPrice",-- optional
--     "computed":     { "expression": "Qty * Price", "persisted": true }, -- optional
--     "dryRun":       false,                     -- optional, default false
--     "timeout":      10000                      -- optional, lock timeout ms
--   }
--
--   "type" follows T-SQL declaration syntax and is parsed by parse_column_type
--   (e.g. 'varchar(100)', 'decimal(18,2)', 'nvarchar(max)', 'datetime2(7)').
--   When "computed" is supplied, "type" and the identity/sparse/default fields
--   are ignored; the computed expression and persisted flag are the contract.
--
-- Result:
--   Returns one row:  status, detail
--     status  'CREATED' | 'ALTERED' | 'NO CHANGE' | 'DRY RUN'
--     detail  human-readable summary, or the T-SQL that would be run for
--             a dry run. On error, no row is returned; the caller gets a
--             THROW instead. The status row is the pipeline's control
--             signal; informational messages are returned only through
--             this result row (no duplicate message-stream output).
--
-- Behavior:
--   CREATE  (column absent)
--     Adds the column with type, nullable, sparse, identity, computed,
--     and default (if supplied) in one ALTER TABLE.
--
--   ALTER   (column present)
--     - type       : widening, narrowing (with data check), or lateral
--                    nvarchar<->varchar (with data and collation checks),
--                    as classified by column_type_change. Family changes
--                    and unsupported conversions are refused.
--     - nullable   : toggled; NULL -> NOT NULL scans existing rows first.
--     - sparse     : toggled.
--     - default    : added or replaced only when "default" is supplied;
--                    delegated to create_default inside the same
--                    transaction and lock.
--     - identity   : must match the existing column; cannot be added to
--                    or removed from an existing column.
--     - computed   : expression and persisted flag must match the
--                    existing column; the formula cannot be changed.
--
--   The default is never touched when "default" is absent from @spec,
--   even if the column currently has one. To remove a default, use
--   drop_default explicitly.
--
-- Safety:
--   - sp_getapplock on db.schema.table, exclusive, for the duration of
--     the transaction. Concurrent create_column calls on the same table
--     serialize instead of racing.
--   - Uses a transaction when called standalone, or a savepoint when called
--     inside a caller-owned transaction. It commits/rolls back only a
--     transaction it started; caller-owned transactions remain caller-owned.
--   - Any committable failure rolls back this helper's work. If a caller-owned
--     transaction becomes uncommittable, the caller must roll it back.
--   - Column dependencies (index, FK, computed column, view, module) are
--     detected via column_dependencies and refuse the ALTER with a
--     message naming the blocker. Drop or alter the dependent object
--     first, or apply the change manually.
--
-- Reserved error states:
--   50000  invalid @spec (missing table/name/type)
--   50001  target table does not exist
--   50002  invalid type declaration
--   50003  could not acquire app lock within timeout
--   50010  column has a blocking dependency
--   50011  existing column is IDENTITY; cannot convert
--   50012  existing column is not IDENTITY; cannot convert
--   50013  existing column is computed; cannot convert
--   50014  existing column is not computed; cannot convert
--   50015  computed expression differs from existing column
--   50016  type change is forbidden (different family or unsupported)
--   50017  existing rows would not fit the target type or NOT NULL
--   50018  Unicode-to-non-Unicode change requires an explicit COLLATE
--   50019  specified collation matches the current one (no-op change)
--   50020  caller transaction is not committable
--
-- Examples:
--   EXEC m.create_column @spec = N'{
--     "table": "sales.Products",
--     "name": "DiscountPrice",
--     "type": "int",
--     "nullable": true,
--     "default": "0"
--   }';
--
--   EXEC m.create_column @spec = N'{
--     "table": "sales.Products",
--     "name": "Total",
--     "computed": { "expression": "Qty * Price", "persisted": true }
--   }';
--
--   EXEC m.create_column @spec = N'{
--     "table": "sales.Products",
--     "name": "Notes",
--     "type": "nvarchar(500)",
--     "nullable": true,
--     "dryRun": true
--   }';
-- =============================================
CREATE OR ALTER PROCEDURE $(SchemaName).create_column
(
    @spec nvarchar(max)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    ------------------------------------------------------------------
    -- 1. Parse @spec
    ------------------------------------------------------------------
    DECLARE @table        nvarchar(1000),
            @name         nvarchar(500),
            @type         nvarchar(4000),
            @nullable     bit = 0,
            @sparse       bit = 0,
            @default      nvarchar(max),
            @default_name nvarchar(500),
            @identity     bit = 0,
            @seed         bigint,
            @increment    bigint,
            @computed     bit = 0,
            @expression   nvarchar(max),
            @persisted    bit = 0,
            @dry_run      bit = 0,
            @timeout      int = 10000;

    BEGIN TRY
        SELECT
            @table        = j.[table],
            @name         = j.[name],
            @type         = j.[type],
            @nullable     = ISNULL(j.[nullable], 0),
            @sparse       = ISNULL(j.[sparse], 0),
            @default      = j.[default],
            @default_name = j.default_name,
            @identity     = CASE WHEN j.[identity] IS NOT NULL THEN 1 ELSE 0 END,
            @seed         = TRY_CAST(JSON_VALUE(@spec, '$.identity.seed')      AS bigint),
            @increment    = TRY_CAST(JSON_VALUE(@spec, '$.identity.increment') AS bigint),
            @computed     = CASE WHEN j.computed IS NOT NULL THEN 1 ELSE 0 END,
            @expression   = JSON_VALUE(@spec, '$.computed.expression'),
            @persisted    = ISNULL(TRY_CAST(JSON_VALUE(@spec, '$.computed.persisted') AS bit), 0),
            @dry_run      = ISNULL(TRY_CAST(JSON_VALUE(@spec, '$.dryRun')  AS bit), 0),
            @timeout      = ISNULL(TRY_CAST(JSON_VALUE(@spec, '$.timeout') AS int), 10000)
        FROM OPENJSON(@spec)
        WITH
        (
            [table]        nvarchar(1000) '$.table',
            [name]         nvarchar(500)  '$.name',
            [type]         nvarchar(4000) '$.type',
            [nullable]     bit            '$.nullable',
            [sparse]       bit            '$.sparse',
            [default]      nvarchar(max)  '$.default',
            default_name   nvarchar(500)  '$.default_name',
            [identity]     nvarchar(max)  '$.identity'   AS JSON,
            computed       nvarchar(max)  '$.computed'   AS JSON
        ) AS j;

        IF @table IS NULL OR @name IS NULL
        BEGIN
            ;THROW 50000, N'create_column: @spec must contain "table" and "name".', 1;
        END

        IF @computed = 0 AND @type IS NULL
        BEGIN
            ;THROW 50000, N'create_column: @spec must contain "type" unless "computed" is provided.', 1;
        END

        ------------------------------------------------------------------
        -- 2. Resolve names, validate table
        ------------------------------------------------------------------
        DECLARE @db     sysname, @schema sysname, @tbl sysname;

        SELECT @db = [db], @schema = [schema], @tbl = [table]
        FROM $(SchemaName).parse_table_name(@table);

        IF @db IS NULL SET @db = DB_NAME();
        IF @schema IS NULL SET @schema = N'dbo';

        IF $(SchemaName).table_exists(@table) = 0
        BEGIN
            ;THROW 50001, N'create_column: target table does not exist.', 1;
        END

        DECLARE @full_table  nvarchar(1500) = QUOTENAME(@schema) + N'.' + QUOTENAME(@tbl);
        DECLARE @full_column nvarchar(1500) = @full_table + N'.' + QUOTENAME(@name);

        ------------------------------------------------------------------
        -- 3. Validate type (unless computed)
        ------------------------------------------------------------------
        DECLARE @t TABLE (
            normalized_type  nvarchar(4000),
            type_name        nvarchar(500),
            system_type_id   int,
            user_type_id     int,
            is_user_defined  bit,
            is_valid         bit,
            validation_error nvarchar(max),
            collation_name   nvarchar(500),
            char_length      int,
            byte_length      int,
            precision        int,
            scale            int,
            fractional_scale int
        );

        IF @computed = 0
        BEGIN
            INSERT @t
            SELECT
                normalized_type,
                type_name,
                system_type_id,
                user_type_id,
                is_user_defined,
                is_valid,
                validation_error,
                collation_name,
                char_length,
                byte_length,
                precision,
                scale,
                fractional_scale
            FROM $(SchemaName).parse_column_type(@type);

            IF (SELECT is_valid FROM @t) = 0
            BEGIN
                DECLARE @msg_type nvarchar(2048) =
                    N'create_column: ' + ISNULL((SELECT validation_error FROM @t), N'invalid type.');
                ;THROW 50002, @msg_type, 1;
            END
        END

        ------------------------------------------------------------------
        -- 4. Applock + transaction
        ------------------------------------------------------------------
        DECLARE @lock_resource nvarchar(255) =
            N'create_column:' + QUOTENAME(@db) + N'.' + QUOTENAME(@schema) + N'.' + QUOTENAME(@tbl);

        DECLARE @lock_rc int;
        DECLARE @started_transaction bit = 0;
        DECLARE @savepoint_created bit = 0;

        BEGIN TRY
            -- Respect a transaction owned by the caller. A savepoint lets
            -- this procedure undo its own work without rolling back the
            -- caller's transaction.
            IF @@TRANCOUNT = 0
            BEGIN
                BEGIN TRANSACTION;
                SET @started_transaction = 1;
            END
            ELSE
            BEGIN
                IF XACT_STATE() <> 1
                BEGIN
                    ;THROW 50020, N'create_column: the caller transaction is not committable.', 1;
                END

                SAVE TRANSACTION create_column_savepoint;
                SET @savepoint_created = 1;
            END

            -- Transaction-owned application locks require an active
            -- transaction, so acquire the lock only after transaction setup.
            EXEC @lock_rc = sp_getapplock
                 @Resource    = @lock_resource,
                 @LockMode    = N'Exclusive',
                 @LockOwner   = N'Transaction',
                 @LockTimeout = @timeout;

            IF @lock_rc < 0
            BEGIN
                ;THROW 50003, N'create_column: could not acquire lock within timeout.', 1;
            END
            ------------------------------------------------------------------
            -- 5. CREATE path
            ------------------------------------------------------------------
            IF $(SchemaName).column_exists(@full_column) = 0
            BEGIN
                DECLARE @ddl nvarchar(max) =
                    N'ALTER TABLE ' + @full_table + N' ADD ' + QUOTENAME(@name) + N' ';

                IF @computed = 1
                BEGIN
                    SET @ddl += N'AS (' + @expression + N')'
                             + CASE WHEN @persisted = 1 THEN N' PERSISTED' ELSE N'' END;
                END
                ELSE
                BEGIN
                    SET @ddl += (SELECT normalized_type FROM @t)
                             + CASE WHEN @identity = 1
                                        THEN N' IDENTITY(' + CAST(ISNULL(@seed, 1) AS nvarchar(20))
                                             + N',' + CAST(ISNULL(@increment, 1) AS nvarchar(20)) + N')'
                                        ELSE N'' END
                             + CASE WHEN @sparse = 1 THEN N' SPARSE' ELSE N'' END
                             + CASE WHEN @nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END
                             + CASE WHEN @default IS NOT NULL
                                        THEN N' CONSTRAINT ' + QUOTENAME(ISNULL(@default_name, N'DF_' + @tbl + N'_' + @name))
                                             + N' DEFAULT ' + @default
                                        ELSE N'' END;
                END

                IF @dry_run = 1
                BEGIN
                    IF @started_transaction = 1
                        COMMIT TRANSACTION;

                    SELECT status = N'DRY RUN', detail = @ddl;
                    RETURN;
                END

                EXEC sp_executesql @ddl;

                IF @started_transaction = 1
                    COMMIT TRANSACTION;

                DECLARE @msg_new nvarchar(4000) = N'create_column: ' + @full_column + N' -> CREATED';

                SELECT status = N'CREATED', detail = N'column added';
                RETURN;
            END

            ------------------------------------------------------------------
            -- 6. ALTER path: read current state
            ------------------------------------------------------------------
            DECLARE @ci TABLE (
                type_name            nvarchar(500),
                system_type_id       int,
                user_type_id         int,
                max_length           int,
                [precision]          int,
                scale                int,
                collation_name       nvarchar(500),
                is_nullable          bit,
                is_identity          bit,
                is_computed          bit,
                is_sparse            bit,
                default_value   nvarchar(max),
                computed_definition  nvarchar(max)
            );

            INSERT @ci
            SELECT
                type_name,
                system_type_id,
                user_type_id,
                max_length,
                [precision],
                scale,
                collation_name,
                is_nullable,
                is_identity,
                is_computed,
                is_sparse,
                default_value,
                computed_definition
            FROM $(SchemaName).column_info(@full_column);

            DECLARE @cur TABLE (
                type_name           nvarchar(500),
                system_type_id      int,
                max_length          int,
                [precision]         int,
                scale               int,
                collation_name      nvarchar(500),
                is_nullable         bit,
                is_identity         bit,
                is_computed         bit,
                is_sparse           bit,
                default_value       nvarchar(max),
                computed_definition nvarchar(max)
            );
            INSERT @cur
            SELECT
                type_name,
                system_type_id,
                max_length,
                [precision],
                scale,
                collation_name,
                is_nullable,
                is_identity,
                is_computed,
                is_sparse,
                default_value,
                computed_definition
            FROM @ci;

            ------------------------------------------------------------------
            -- 7. Dependency gate
            ------------------------------------------------------------------
            DECLARE @deps TABLE (dependency nvarchar(1000), type nvarchar(64));
            INSERT @deps
            SELECT dependency, type
            FROM $(SchemaName).column_dependencies(@full_column);

            DECLARE @blocker nvarchar(1000), @blocker_type nvarchar(64);
            SELECT TOP (1)
                   @blocker      = dependency,
                   @blocker_type = type
            FROM @deps
            WHERE type IN (N'index', N'foreign key', N'computed column', N'view', N'module')
            ORDER BY
                CASE type
                    WHEN N'index'           THEN 1
                    WHEN N'foreign key'     THEN 2
                    WHEN N'computed column' THEN 3
                    WHEN N'view'            THEN 4
                    WHEN N'module'          THEN 5
                    ELSE 99
                END;

            IF @blocker IS NOT NULL
            BEGIN
                DECLARE @dep_msg nvarchar(4000) =
                    N'create_column: cannot alter column because it is referenced by '
                    + CASE @blocker_type
                          WHEN N'index'           THEN N'index '
                          WHEN N'foreign key'     THEN N'foreign key '
                          WHEN N'computed column' THEN N'computed column '
                          WHEN N'view'            THEN N'view '
                          WHEN N'module'          THEN N'module '
                          ELSE N'dependency '
                      END
                    + @blocker
                    + N'. Drop or alter the dependent object first, or change the column manually.';
                ;THROW 50010, @dep_msg, 1;
            END

            ------------------------------------------------------------------
            -- 8. Identity and computed must match, not change
            ------------------------------------------------------------------
            IF (SELECT is_identity FROM @cur) = 1 AND @identity = 0
            BEGIN
                ;THROW 50011, N'create_column: existing column is IDENTITY; cannot convert.', 1;
            END
            IF (SELECT is_identity FROM @cur) = 0 AND @identity = 1
            BEGIN
                ;THROW 50012, N'create_column: existing column is not IDENTITY; cannot convert.', 1;
            END

            IF (SELECT is_computed FROM @cur) = 1 AND @computed = 0
            BEGIN
                ;THROW 50013, N'create_column: existing column is computed; cannot convert to a regular column.', 1;
            END
            IF (SELECT is_computed FROM @cur) = 0 AND @computed = 1
            BEGIN
                ;THROW 50014, N'create_column: existing column is not computed; cannot convert to computed.', 1;
            END

            IF @computed = 1
            BEGIN
                DECLARE @cur_expr nvarchar(max) = (SELECT computed_definition FROM @cur);
                IF $(SchemaName)._normalize_default(@cur_expr) <> $(SchemaName)._normalize_default(@expression)
                BEGIN
                    ;THROW 50015, N'create_column: computed expression differs from existing column.', 1;
                END
            END

            ------------------------------------------------------------------
            -- 9. Build the ALTER statements needed
            ------------------------------------------------------------------
            DECLARE @alter_type       bit = 0,
                    @alter_nullable   bit = 0,
                    @alter_sparse     bit = 0,
                    @alter_default    bit = 0,
                    @new_type         nvarchar(4000),
                    @new_collation    sysname;

            -- 9a. Type change
            IF @computed = 0
            BEGIN
                DECLARE @from_type      nvarchar(128) = (SELECT type_name       FROM @cur),
                        @from_length    int           = (SELECT max_length      FROM @cur),
                        @from_precision int           = (SELECT [precision]     FROM @cur),
                        @from_scale     int           = (SELECT scale           FROM @cur),
                        @cur_collation  sysname       = (SELECT collation_name  FROM @cur),
                        @to_type        nvarchar(128) = (SELECT type_name       FROM @t),
                        @to_length      int           = (SELECT byte_length     FROM @t),
                        @to_precision   int           = (SELECT precision       FROM @t),
                        @to_scale       int           = (SELECT scale           FROM @t),
                        @spec_collation sysname       = (SELECT collation_name  FROM @t);

                IF @from_type <> @to_type
                   OR @from_length <> @to_length
                   OR ISNULL(@from_precision, -1) <> ISNULL(@to_precision, -1)
                   OR ISNULL(@from_scale, -1)     <> ISNULL(@to_scale, -1)
                BEGIN
                    DECLARE @cls nvarchar(20),
                            @needs_data_check bit,
                            @needs_collation_check bit,
                            @reason nvarchar(4000);

                    SELECT
                        @cls = [class],
                        @needs_data_check = requires_data_check,
                        @needs_collation_check = requires_collation_check,
                        @reason = reason
                    FROM $(SchemaName).column_type_change(
                        @from_type, @from_length, @from_precision, @from_scale,
                        @to_type,   @to_length,   @to_precision,   @to_scale
                    );

                    IF @cls = N'forbidden'
                    BEGIN
                        DECLARE @msg_forbid nvarchar(2048) = N'create_column: ' + @reason;
                        ;THROW 50016, @msg_forbid, 1;
                    END

                    IF @needs_data_check = 1
                    BEGIN
                        DECLARE @bad int;

                        DECLARE @chk nvarchar(max) =
                            N'SELECT @b = COUNT(*) FROM ' + @full_table
                            + N' WHERE ' + QUOTENAME(@name) + N' IS NOT NULL AND ('
                            + N'TRY_CAST(' + QUOTENAME(@name) + N' AS '
                            + (SELECT normalized_type FROM @t) + N') IS NULL';

                        -- Detect silent truncation when narrowing varchar or nvarchar.
                        -- DATALENGTH measures bytes, which matches SQL Server's length
                        -- semantics for these types.
                        IF @from_type = @to_type
                        AND @from_type IN (N'varchar', N'nvarchar')
                        AND @to_length >= 0
                        BEGIN
                            SET @chk +=
                                N' OR DATALENGTH(' + QUOTENAME(@name) + N') > @target_bytes';
                        END

                        SET @chk += N');';

                        EXEC sp_executesql
                            @chk,
                            N'@b int OUTPUT, @target_bytes int',
                            @b = @bad OUTPUT,
                            @target_bytes = @to_length;

                        IF @bad > 0
                        BEGIN
                            DECLARE @msg_data nvarchar(2048) =
                                N'create_column: ' + @reason
                                + N' (' + CAST(@bad AS nvarchar(20)) + N' row(s) would not fit).';

                            ;THROW 50017, @msg_data, 1;
                        END
                    END

                    IF @needs_collation_check = 1
                    BEGIN
                        IF @spec_collation IS NULL
                        BEGIN
                            ;THROW 50018, N'create_column: Unicode-to-non-Unicode change requires an explicit COLLATE clause in @spec.type.', 1;
                        END
                        IF @spec_collation = @cur_collation
                        BEGIN
                            ;THROW 50019, N'create_column: specified collation matches the current one; the encoding change has no effect.', 1;
                        END

                        SET @new_collation = @spec_collation;
                    END

                    SET @alter_type = 1;
                    SET @new_type   = (SELECT normalized_type FROM @t)
                                    + CASE WHEN @needs_collation_check = 1
                                                THEN N' COLLATE ' + @new_collation
                                                ELSE N'' END;
                END
            END

            -- 9b. Nullable
            IF (SELECT is_nullable FROM @cur) <> @nullable
            BEGIN
                IF (SELECT is_nullable FROM @cur) = 1 AND @nullable = 0
                BEGIN
                    DECLARE @has_nulls bit = 0;
                    DECLARE @sql_chk nvarchar(max) =
                        N'SELECT @h = CASE WHEN EXISTS (SELECT 1 FROM ' + @full_table
                        + N' WHERE ' + QUOTENAME(@name) + N' IS NULL) THEN 1 ELSE 0 END;';
                    EXEC sp_executesql @sql_chk, N'@h bit OUTPUT', @h = @has_nulls OUTPUT;

                    IF @has_nulls = 1
                    BEGIN
                        ;THROW 50017, N'create_column: cannot set NOT NULL; column contains NULLs.', 1;
                    END
                END
                SET @alter_nullable = 1;
            END

            -- 9c. Sparse
            IF (SELECT is_sparse FROM @cur) <> @sparse
                SET @alter_sparse = 1;

            -- 9d. Default: delegate to create_default, only when @default is supplied
            IF @default IS NOT NULL
               AND $(SchemaName).default_exists(@full_column, @default) = 0
                SET @alter_default = 1;

            ------------------------------------------------------------------
            -- 10. No change?
            ------------------------------------------------------------------
            IF @alter_type = 0 AND @alter_nullable = 0 AND @alter_sparse = 0 AND @alter_default = 0
            BEGIN
                IF @started_transaction = 1
                    COMMIT TRANSACTION;

                SELECT status = N'NO CHANGE', detail = N'column already matches spec';
                RETURN;
            END

            ------------------------------------------------------------------
            -- 11. Apply column-level DDL
            ------------------------------------------------------------------
            DECLARE @ddl2 nvarchar(max) = N'';

            IF @alter_type = 1
                SET @ddl2 += N'ALTER TABLE ' + @full_table
                          + N' ALTER COLUMN ' + QUOTENAME(@name) + N' ' + @new_type
                          + CASE
                                WHEN @alter_nullable = 1
                                    THEN CASE WHEN @nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END
                                ELSE CASE WHEN (SELECT is_nullable FROM @cur) = 1 THEN N' NULL' ELSE N' NOT NULL' END
                            END
                          + N'; ';

            IF @alter_nullable = 1 AND @alter_type = 0
                SET @ddl2 += N'ALTER TABLE ' + @full_table
                          + N' ALTER COLUMN ' + QUOTENAME(@name) + N' ' + (SELECT normalized_type FROM @t)
                          + CASE WHEN @nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END
                          + N'; ';

            IF @alter_sparse = 1
                SET @ddl2 += N'ALTER TABLE ' + @full_table
                        + N' ALTER COLUMN ' + QUOTENAME(@name)
                        + CASE
                                WHEN @sparse = 1 THEN N' ADD SPARSE'
                                ELSE N' DROP SPARSE'
                            END
                        + N'; ';

            IF @dry_run = 1
            BEGIN

                IF @alter_default = 1
                BEGIN
                    DECLARE @dry_default nvarchar(max) =
                        N'EXEC ' + QUOTENAME(N'$(SchemaName)') + N'.create_default @column = '
                        + QUOTENAME(@full_column, '''') + N', @value = '
                        + QUOTENAME(@default, '''')
                        + CASE WHEN @default_name IS NOT NULL
                                    THEN N', @name = ' + QUOTENAME(@default_name, '''')
                                    ELSE N'' END + N';';
                END

                IF @started_transaction = 1
                    COMMIT TRANSACTION;

                SELECT status = N'DRY RUN', detail = @ddl2
                       + CASE WHEN @alter_default = 1
                                   THEN N' -- plus create_default for ' + @full_column
                                   ELSE N'' END;
                RETURN;
            END

            IF @ddl2 <> N''
                EXEC sp_executesql @ddl2;

            ------------------------------------------------------------------
            -- 12. Apply default via helper (same transaction, same lock)
            ------------------------------------------------------------------
            IF @alter_default = 1
                EXEC $(SchemaName).create_default
                     @column = @full_column,
                     @value  = @default,
                     @name   = @default_name;

            IF @started_transaction = 1
                COMMIT TRANSACTION;

            DECLARE @msg_alt nvarchar(4000) = N'create_column: ' + @full_column + N' -> ALTERED';

            SELECT status = N'ALTERED', detail = @ddl2
                   + CASE WHEN @alter_default = 1
                               THEN N' -- default synced via create_default'
                               ELSE N'' END;
        END TRY
        BEGIN CATCH
            IF @started_transaction = 1
            BEGIN
                -- This procedure owns the transaction, so it can roll it
                -- back completely (including releasing its applock).
                IF XACT_STATE() <> 0
                    ROLLBACK TRANSACTION;
            END
            ELSE IF @savepoint_created = 1 AND XACT_STATE() = 1
            BEGIN
                -- The caller owns the transaction. Undo only this
                -- procedure's work; never roll back the caller's transaction.
                ROLLBACK TRANSACTION create_column_savepoint;
            END
            -- If XACT_STATE() = -1 in a caller-owned transaction, SQL Server
            -- does not permit rollback to a savepoint. Leave the full rollback
            -- decision to the caller.
            ;THROW;
        END CATCH
    END TRY
    BEGIN CATCH
        ;THROW;
    END CATCH
END
GO
