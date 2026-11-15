-- =============================================
-- $(SchemaName).table_exists
-- =============================================
-- Returns 1 if the specified table exists, 0 otherwise.
--
-- Supported input formats:
--   'Products'                  -> dbo.Products
--   'sales.Products'            -> sales.Products
--   'db.sales.Products'         -> db.sales.Products
--   '#tmp1'                     -> tempdb..#tmp1 (local temp table)
--   '##tmp2'                    -> tempdb..##tmp2 (global temp table)
--   '[sales].[My.Table]'        -> sales.[My.Table]
--
-- Temp tables:
--    Global templ tables (##x) are supported.
--    Local temp tables (#x): are NOT FULLY supported.
--      (Only supported if temp table is create in the current execution context).
--
-- Unqualified names resolve to dbo (not the caller's DEFAULT_SCHEMA).
-- Only user tables (type 'U') are recognized. Views, synonyms,
-- and other object types return 0.
--
-- See docs/table_exists.md for full documentation.
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).table_exists
(
    @name nvarchar(776)
)
RETURNS bit
AS
BEGIN
    IF @name IS NULL OR LTRIM(RTRIM(@name)) = ''
        RETURN 0;

    DECLARE @normalized nvarchar(776) = LTRIM(RTRIM(@name));
    DECLARE @result bit = 0;

    -- Temp tables: #local and ##global.
    IF LEFT(@normalized, 1) = N'#'
    BEGIN
        SET @result = CASE
            WHEN OBJECT_ID(N'tempdb..' + @normalized, N'U') IS NOT NULL THEN 1
            ELSE 0
        END;
        RETURN @result;
    END

    -- No dot: assume default schema (dbo).
    IF CHARINDEX(N'.', @normalized) = 0
        SET @normalized = N'dbo.' + QUOTENAME(@normalized);

    SET @result = CASE
        WHEN OBJECT_ID(@normalized, N'U') IS NOT NULL THEN 1
        ELSE 0
    END;

    RETURN @result;
END;
GO

