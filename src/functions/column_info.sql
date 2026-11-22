-- =============================================
-- $(SchemaName).column_info
-- =============================================
-- Returns a single row with detailed information about a column,
-- or an empty result set if the column does not exist.
--
-- Input formats:
--   'Table.Column'                  -> dbo.Table.Column
--   'Schema.Table.Column'           -> Schema.Table.Column
--   'Db.Schema.Table.Column'        -> Db.Schema.Table.Column
--   '[sales].[My.Table].[My.Column]'-> sales.[My.Table].[My.Column]
--
-- Columns returned:
--   db, schema_name, table_name, column_name
--   type_name, type_id, user_type_id, system_type_id
--   max_length, precision, scale, collation_name
--   is_nullable, is_identity, is_computed, is_sparse
--   is_filestream, is_xml, is_rowguidcol
--   default_value, computed_definition
--   column_description
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).column_info
(
    @name nvarchar(1000)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        [db]                = ISNULL(p.[db], DB_NAME()),
        schema_name         = p.[schema],
        table_name          = p.[table],
        column_name         = p.[column],

			  column_id			      = c.column_id,
        type_id             = c.system_type_id,
        type_name           = t.name,
        type_schema_id      = t.schema_id,
        type_schema_name    = schema_name(t.schema_id),
        user_type_id        = c.user_type_id,
        system_type_id      = c.system_type_id,

        max_length          = c.max_length,
			  [length]      			= case when t.name in ('nchar', 'ntext', 'nvarchar') then c.max_length / 2 else c.max_length end,
        [precision]         = c.[precision],
        scale               = c.scale,
        collation_name      = c.collation_name,

        is_nullable         = c.is_nullable,
        is_identity         = c.is_identity,
        is_computed         = c.is_computed,
			  is_persisted		    = c.is_persisted,
        is_sparse           = c.is_sparse,
        is_filestream       = c.is_filestream,
        is_xml              = c.is_xml_document,
        is_rowguidcol       = c.is_rowguidcol,

        default_value       = $(SchemaName)._normalize_default(dc.definition),
        default_name        = dc.name,
        computed_definition = cc.definition,
        column_description  = CAST(ep.value AS nvarchar(max))
    FROM $(SchemaName).parse_column_name(@name) p
    JOIN sys.columns c
      ON c.object_id = OBJECT_ID(
            QUOTENAME(ISNULL(p.[db], DB_NAME())) + N'.'
          + QUOTENAME(p.[schema]) + N'.'
          + QUOTENAME(p.[table]), N'U')
     AND c.name = p.[column]
    JOIN sys.types t
      ON t.user_type_id = c.user_type_id
    LEFT JOIN sys.default_constraints dc
      ON dc.parent_object_id = c.object_id
     AND dc.parent_column_id = c.column_id
    LEFT JOIN sys.computed_columns cc
      ON cc.object_id = c.object_id
     AND cc.column_id = c.column_id
    LEFT JOIN sys.extended_properties ep
      ON ep.major_id = c.object_id
     AND ep.minor_id = c.column_id
     AND ep.name = N'MS_Description'
     AND ep.class = 1
);
GO