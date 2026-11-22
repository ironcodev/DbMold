-- =============================================
-- $(SchemaName).column_type
-- =============================================
-- Returns a single row with type information for a column,
-- or an empty result set if the column does not exist.
--
-- Columns returned:
--   type_name, user_type_id, system_type_id
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).column_type
(
    @name nvarchar(1000)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        type_name,
        user_type_id,
        system_type_id
    FROM $(SchemaName).column_info(@name)
);
GO