CREATE OR ALTER FUNCTION $(SchemaName).table_summary
(
    @name $(SchemaName).object_name
)
RETURNS TABLE
AS
RETURN
(
    SELECT ci.*
    FROM $(SchemaName).column_summary(@name) AS ci
);
GO
