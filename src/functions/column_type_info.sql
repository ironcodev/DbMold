-- =============================================
-- $(SchemaName).column_type_info
-- =============================================
-- Returns a single row with type information for a column,
-- or an empty result set if the column does not exist.
--
-- Columns returned:
--   type_name, user_type_id, system_type_id
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).column_type_info
(
    @column $(SchemaName).object_name
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        [type_name],
        [type_schema_id],
        [type_schema_name],
        [user_type_id],
        [system_type_id],
        [has_user_defined_type],
        [has_assembly_type]
    FROM $(SchemaName).column_info(@column)
);
GO