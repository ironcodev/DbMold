-- =============================================
-- $(SchemaName).column_exists
-- =============================================
-- Returns 1 if the specified column exists on a user table, 0 otherwise.
--
-- Input formats:
--   'Table.Column'                  -> dbo.Table.Column
--   'Schema.Table.Column'           -> Schema.Table.Column
--   'Db.Schema.Table.Column'        -> Db.Schema.Table.Column
--   '[sales].[My.Table].[My.Column]'-> sales.[My.Table].[My.Column]
--
-- Temp tables are NOT supported (UDF limitation).
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).column_exists
(
    @column $(SchemaName).object_name
)
RETURNS bit
AS
BEGIN
    DECLARE @object_id              int,
            @column_id              int,
            @db                     sysname,
            @table                  sysname,
            @column_name            sysname,
            @original_column_name   sysname;

    SELECT TOP(1)
        @object_id              = p.[object_id],
        @db                     = p.[db],
        @table                  = p.[table_name],
        @column_id              = p.[column_id],
        @column_name            = p.[column_name],
        @original_column_name   = p.[original_column_name]
    FROM $(SchemaName).column_info(@column) p;

    -- Current database only
    IF @db <> DB_NAME()
        RETURN 0;

    -- Object and column must exist
    IF @object_id IS NULL
        OR @original_column_name IS NULL
        OR @column_name IS NULL
        OR @column_name <> @original_column_name
        OR datalength(@column_name) <> datalength(@original_column_name)
        OR @column_id IS NULL
        RETURN 0;

    -- For temp tables, parse_column_name returns schema = NULL and
    -- table = '#...'. Reject them (UDFs cannot access temp tables).
    IF LEFT(@table, 1) = N'#'   -- we can't support temp tables in a UDF, so reject them
        RETURN 0;

    RETURN 1;
END;
GO