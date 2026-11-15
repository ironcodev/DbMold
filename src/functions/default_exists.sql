-- =============================================
-- $(SchemaName).default_exists
-- =============================================
-- Returns 1 if the column has a default constraint (optionally matching
-- a specific value), 0 otherwise.
--
-- Accepts a column reference in these forms:
--   'Products.IsShipped'                -> dbo.Products.IsShipped
--   'sales.Products.IsShipped'          -> sales.Products.IsShipped
--   'db.sales.Products.IsShipped'       -> db.sales.Products.IsShipped
--   '[sales].[My.Table].[IsShipped]'    -> sales.[My.Table].[IsShipped]
--
-- If @expected_value is NULL, only the presence of the default is checked.
-- If @expected_value is provided, the default definition is normalized
-- (via _normalize_default) and compared to the normalized expected value.
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).default_exists
(
    @name           nvarchar(1000),
    @expected_value nvarchar(max) = NULL
)
RETURNS bit
AS
BEGIN
    IF @name IS NULL OR LTRIM(RTRIM(@name)) = ''
        RETURN 0;

    DECLARE @db sysname, @schema sysname, @table sysname, @column sysname;

    SELECT
        @db     = ISNULL(p.[db], DB_NAME()),
        @schema = p.[schema],
        @table  = p.[table],
        @column = p.[column]
    FROM $(SchemaName).parse_column_name(@name) p;

    IF @schema IS NULL OR @table IS NULL OR @column IS NULL
        RETURN 0;

    DECLARE @table_id int = OBJECT_ID(
        QUOTENAME(@db) + N'.' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table), N'U');

    IF @table_id IS NULL
        RETURN 0;

    DECLARE @definition nvarchar(max);

    SELECT @definition = dc.definition
    FROM sys.default_constraints dc
    JOIN sys.columns c
      ON c.object_id = dc.parent_object_id
     AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = @table_id
      AND c.name = @column;

    IF @definition IS NULL
        RETURN 0;

    -- Presence-only check.
    IF @expected_value IS NULL
        RETURN 1;

    -- Value check.
    DECLARE @actual_norm   nvarchar(max) = $(SchemaName)._normalize_default(@definition);
    DECLARE @expected_norm nvarchar(max) = $(SchemaName)._normalize_default(@expected_value);

    RETURN CASE WHEN @actual_norm = @expected_norm THEN 1 ELSE 0 END;
END;
GO