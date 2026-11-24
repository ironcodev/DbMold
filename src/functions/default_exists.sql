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
    @name           $(SchemaName).object_name,
    @expected_value nvarchar(max) = NULL
)
RETURNS bit
AS
BEGIN
    DECLARE @existing_default nvarchar(max)

    SET @existing_default = $(SchemaName).column_default(@name)

    IF @existing_default IS NULL
        RETURN 0;

    -- Presence-only check.
    IF @expected_value IS NULL
        RETURN 1;

    -- Value check.
    DECLARE @actual_norm   nvarchar(max) = $(SchemaName)._normalize_default(@existing_default);
    DECLARE @expected_norm nvarchar(max) = $(SchemaName)._normalize_default(@expected_value);

    RETURN CASE WHEN @actual_norm = @expected_norm THEN 1 ELSE 0 END;
END;
GO