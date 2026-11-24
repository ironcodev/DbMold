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
    @name nvarchar(1000)
)
RETURNS bit
AS
BEGIN
    IF @name IS NULL OR LTRIM(RTRIM(@name)) = ''
        RETURN 0;

    DECLARE @object_id  int,
            @db         sysname,
            @schema     sysname,
            @table      sysname,
            @column     sysname;

    SELECT
        @object_id = p.[object_id],
        @db     = ISNULL(p.[db], DB_NAME()),
        @schema = p.[schema],
        @table  = p.[table],
        @column = p.[column]
    FROM $(SchemaName).parse_column_name(@name) p;

    -- For temp tables, parse_column_name returns schema = NULL and
    -- table = '#...'. Reject them (UDFs cannot access temp tables).
    IF @schema IS NULL OR @table IS NULL OR @column IS NULL
        RETURN 0;

    IF LEFT(@table, 1) = N'#'
        RETURN 0;

    DECLARE @full_name nvarchar(1000) =
        QUOTENAME(@db) + N'.' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table);

    IF OBJECT_ID(@full_name, N'U') IS NULL
        RETURN 0;

    IF COL_LENGTH(@full_name, @column) IS NULL
        RETURN 0;

    RETURN 1;
END;
GO