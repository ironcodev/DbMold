-- =============================================
-- mold.table_exists
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
-- The function is idempotent and safe to call any number of times.
-- =============================================
CREATE OR ALTER FUNCTION mold.table_exists
(
    @name nvarchar(776)
)
RETURNS bit
AS
BEGIN
    -- Null or empty: nothing exists.
    IF @name IS NULL OR LTRIM(RTRIM(@name)) = ''
        RETURN 0;

    DECLARE @normalized nvarchar(776) = LTRIM(RTRIM(@name));
    DECLARE @result bit = 0;

    -- Temp tables: #local and ##global.
    -- OBJECT_ID needs the tempdb prefix to resolve them.
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

    -- Resolve the object id. OBJECT_ID handles quoted names natively.
    SET @result = CASE
        WHEN OBJECT_ID(@normalized, N'U') IS NOT NULL THEN 1
        ELSE 0
    END;

    RETURN @result;
END;
GO
