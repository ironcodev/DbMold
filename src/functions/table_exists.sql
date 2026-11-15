-- =============================================
-- $(SchemaName).table_exists
-- =============================================
-- Returns 1 if the specified table exists, 0 otherwise.
--
-- Input formats:
--   'Products'             -> dbo.Products
--   'sales.Products'       -> sales.Products
--   'db.sales.Products'    -> db.sales.Products
--   '#tmp1'                -> tempdb..#tmp1
--   '##tmp2'               -> tempdb..##tmp2
--   '[sales].[My.Table]'   -> sales.[My.Table]
--
-- Unqualified names resolve to dbo (via parse_table_name).
-- Only user tables (type 'U') are recognized.
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).table_exists
(
    @name nvarchar(1000)
)
RETURNS bit
AS
BEGIN
    IF @name IS NULL OR LTRIM(RTRIM(@name)) = ''
        RETURN 0;

    DECLARE @normalized nvarchar(1000) = LTRIM(RTRIM(@name));

    -- Temp tables: parse_table_name returns schema = NULL and table = '#...'.
    -- Resolve them in tempdb explicitly.
    IF LEFT(@normalized, 1) = N'#'
    BEGIN
        RETURN CASE
            WHEN OBJECT_ID(N'tempdb..' + @normalized, N'U') IS NOT NULL THEN 1
            ELSE 0
        END;
    END

    -- Regular tables.
    DECLARE @db sysname, @schema sysname, @table sysname;

    SELECT
        @db     = ISNULL(p.[db], DB_NAME()),
        @schema = p.[schema],
        @table  = p.[table]
    FROM $(SchemaName).parse_table_name(@normalized) p;

    -- parse_table_name returns schema = NULL only for temp tables
    -- (handled above). Any other NULL means an invalid input.
    IF @schema IS NULL OR @table IS NULL
        RETURN 0;

    DECLARE @full_name nvarchar(1000) =
        QUOTENAME(@db) + N'.' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table);

    RETURN CASE
        WHEN OBJECT_ID(@full_name, N'U') IS NOT NULL THEN 1
        ELSE 0
    END;
END;
GO