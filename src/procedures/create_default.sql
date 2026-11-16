-- =============================================
-- $(SchemaName).create_default
-- =============================================
-- Creates or syncs a DEFAULT constraint on a column.
--
-- Behavior:
--   - If the column already has a default with the same (normalized)
--     value, this is a no-op.
--   - If the column has a default with a different value, the old
--     constraint is dropped and a new one is created.
--   - If the column has no default, a new constraint is created.
--   - If the table or column does not exist, an error is raised.
--
-- Parameters:
--   @column  Column reference: 'Table.Column', 'Schema.Table.Column',
--            'Db.Schema.Table.Column', '[sales].[My.Table].[Col]', etc.
--   @value   SQL expression for the default (e.g. '0', N''hello'',
--            'getdate()', '' for empty string). It is inserted verbatim
--            into the ALTER statement; the caller is responsible for
--            quoting strings.
--   @name    Optional constraint name. If NULL, the default name is
--            DF_<table>_<column>.
-- =============================================
CREATE OR ALTER PROCEDURE $(SchemaName).create_default
(
    @column nvarchar(1000),
    @value  nvarchar(max),
    @name   sysname = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    -- ---------------------------------------------------------
    -- 1. Validate inputs.
    -- ---------------------------------------------------------
    IF @column IS NULL OR LTRIM(RTRIM(@column)) = N''
    BEGIN
        RAISERROR('create_default: @column is required.', 16, 1);
        RETURN;
    END

    IF @value IS NULL
    BEGIN
        RAISERROR('create_default: @value is required.', 16, 1);
        RETURN;
    END

    -- ---------------------------------------------------------
    -- 2. Parse the column reference.
    -- ---------------------------------------------------------
    DECLARE @db sysname, @schema sysname, @table sysname, @col sysname;

    SELECT
        @db     = ISNULL(p.[db], DB_NAME()),
        @schema = p.[schema],
        @table  = p.[table],
        @col    = p.[column]
    FROM $(SchemaName).parse_column_name(@column) p;

    IF @db IS NULL OR @schema IS NULL OR @table IS NULL OR @col IS NULL
    BEGIN
        RAISERROR('create_default: invalid column reference "%s".', 16, 1, @column);
        RETURN;
    END

    -- ---------------------------------------------------------
    -- 3. Verify the table and column exist.
    -- ---------------------------------------------------------
    DECLARE @full_name nvarchar(1000) =
        QUOTENAME(@db) + N'.' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table);

    DECLARE @table_id int = OBJECT_ID(@full_name, N'U');
    IF @table_id IS NULL
    BEGIN
        RAISERROR('create_default: table "%s" does not exist.', 16, 1, @full_name);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = @table_id AND name = @col
    )
    BEGIN
        RAISERROR('create_default: column "%s" does not exist on "%s".', 16, 1, @col, @full_name);
        RETURN;
    END

    -- ---------------------------------------------------------
    -- 4. Look up the existing default (name + definition) in one go.
    -- ---------------------------------------------------------
    DECLARE @existing_constraint sysname;
    DECLARE @existing_definition nvarchar(max);

    SELECT
        @existing_constraint = dc.name,
        @existing_definition = dc.definition
    FROM sys.default_constraints dc
    JOIN sys.columns c
      ON c.object_id = dc.parent_object_id
     AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = @table_id
      AND c.name = @col;

    IF @existing_constraint IS NOT NULL
    BEGIN
        DECLARE @actual_norm   nvarchar(max) = $(SchemaName)._normalize_default(@existing_definition);
        DECLARE @expected_norm nvarchar(max) = $(SchemaName)._normalize_default(@value);

        -- 4a. Same value: no-op.
        IF @actual_norm = @expected_norm
        BEGIN
            PRINT 'create_default: default already exists; nothing to do.';
            RETURN;
        END

        -- 4b. Different value: drop the old constraint.
        DECLARE @drop_sql nvarchar(max) =
            N'ALTER TABLE ' + @full_name
          + N' DROP CONSTRAINT ' + QUOTENAME(@existing_constraint) + N';';
        EXEC sp_executesql @drop_sql;
        PRINT 'create_default: dropped existing constraint "' + @existing_constraint + '".';
    END

    -- ---------------------------------------------------------
    -- 5. Determine the constraint name.
    -- ---------------------------------------------------------
    DECLARE @constraint_name sysname =
        ISNULL(@name, N'DF_' + @table + N'_' + @col);

    -- ---------------------------------------------------------
    -- 6. Create the new default constraint.
    -- ---------------------------------------------------------
    DECLARE @add_sql nvarchar(max) =
        N'ALTER TABLE ' + @full_name
      + N' ADD CONSTRAINT ' + QUOTENAME(@constraint_name)
      + N' DEFAULT ' + @value
      + N' FOR ' + QUOTENAME(@col) + N';';
    EXEC sp_executesql @add_sql;

    PRINT 'create_default: created constraint "' + @constraint_name + '" on '
        + @full_name + N'.' + QUOTENAME(@col) + '.';
END;
GO