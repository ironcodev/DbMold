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
    DECLARE @object_id      int,
            @column_id      int,
            @db             sysname,
            @table          sysname;

    SELECT TOP(1)
        @object_id      = p.[object_id],
        @db             = p.[db],
        @table          = p.[table],
        @column_id      = p.[column_id]
    FROM $(SchemaName).parse_column_name(@column) p;

    -- Current database only
    IF @db <> DB_NAME()
        RETURN 0;

    -- Object and column must exist
    IF @object_id IS NULL OR @column_id IS NULL
        RETURN 0;

    -- For temp tables, parse_column_name returns schema = NULL and
    -- table = '#...'. Reject them (UDFs cannot access temp tables).
    IF LEFT(@table, 1) = N'#'   -- we can't support temp tables in a UDF, so reject them
        RETURN 0;

    RETURN 1;
END;
GO