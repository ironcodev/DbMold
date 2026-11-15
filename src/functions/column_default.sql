-- =============================================
-- $(SchemaName).column_default
-- =============================================
-- Returns the default-constraint definition for a column, or NULL if
-- the column has no default constraint (or the table/column does not
-- exist).
--
-- The returned value is the raw definition from sys.default_constraints
-- (e.g. '((0))', '(getdate())', 'N''hello'''). Use default_exists if you
-- want to compare against an expected value; that function normalizes
-- both sides via _normalize_default.
--
-- Input formats:
--   'Products.IsShipped'                -> dbo.Products.IsShipped
--   'sales.Products.IsShipped'          -> sales.Products.IsShipped
--   'db.sales.Products.IsShipped'       -> db.sales.Products.IsShipped
--   '[sales].[My.Table].[IsShipped]'    -> sales.[My.Table].[IsShipped]
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).column_default
(
    @name nvarchar(1000)
)
RETURNS nvarchar(max)
AS
BEGIN
    IF @name IS NULL OR LTRIM(RTRIM(@name)) = ''
        RETURN NULL;

    DECLARE @db sysname, @schema sysname, @table sysname, @column sysname;

    SELECT
        @db     = ISNULL(p.[db], DB_NAME()),
        @schema = p.[schema],
        @table  = p.[table],
        @column = p.[column]
    FROM $(SchemaName).parse_column_name(@name) p;

    IF @schema IS NULL OR @table IS NULL OR @column IS NULL
        RETURN NULL;

    DECLARE @full_name nvarchar(1000) =
        QUOTENAME(@db) + N'.' + QUOTENAME(@schema) + N'.' + QUOTENAME(@table);

    DECLARE @table_id int = OBJECT_ID(@full_name, N'U');
    IF @table_id IS NULL
        RETURN NULL;

    DECLARE @definition nvarchar(max);

    SELECT @definition = dc.definition
    FROM sys.default_constraints dc
    JOIN sys.columns c
      ON c.object_id = dc.parent_object_id
     AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = @table_id
      AND c.name = @column;

    RETURN @definition;
END;
GO