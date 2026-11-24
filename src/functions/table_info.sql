-- =============================================
-- $(SchemaName).table_info
-- =============================================
-- Returns detailed information for every column in a table.
--
-- Input formats:
--   'Table'                 -> dbo.Table
--   'Schema.Table'          -> Schema.Table
--   'Db.Schema.Table'       -> Db.Schema.Table
--   '[sales].[My.Table]'    -> sales.[My.Table]
--
-- Returns:
--   - The same columns and metadata as $(SchemaName).column_info.
--   - One row per column when the column has no child-side foreign key
--     mappings, and one row per foreign-key mapping when it participates
--     in multiple child-side foreign keys.
--   - Rows are ordered by column_id when the caller specifies ORDER BY.
--
-- Notes:
--   - Metadata is delegated to column_info; this helper does not duplicate
--     column metadata logic.
--   - The table name is parsed by parse_table_name. An omitted schema is
--     treated as dbo, and an omitted database is treated as the current DB.
--   - As with column_info, catalog metadata is read from the current
--     database's system catalog views.
-- =============================================

CREATE OR ALTER FUNCTION $(SchemaName).table_info
(
    @name nvarchar(1000)
)
RETURNS TABLE
AS
RETURN
(
    SELECT ci.*
    FROM $(SchemaName).column_info(@name) AS ci
);
GO
