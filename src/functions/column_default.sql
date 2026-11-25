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
    @column $(SchemaName).object_name
)
RETURNS nvarchar(max)
AS
BEGIN
    DECLARE @object_id  int
    DECLARE @default_value nvarchar(max)

    SELECT
        @object_id = [object_id],
        @default_value = [default_value]
    FROM $(SchemaName).column_info(@column);

    IF @object_id IS NULL
        RETURN NULL;

    RETURN @default_value;
END;
GO