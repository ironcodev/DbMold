-- =============================================
-- $(SchemaName).column_dependencies
-- =============================================
-- Returns every dependency on a column: indexes, statistics, foreign keys
-- (on either side), computed columns, views, and other referencing modules.
--
-- Input formats:
--   'Table.Column'                  -> dbo.Table.Column
--   'Schema.Table.Column'           -> Schema.Table.Column
--   'Db.Schema.Table.Column'        -> Db.Schema.Table.Column
--   '[sales].[My.Table].[My.Column]'-> sales.[My.Table].[My.Column]
--
-- Returns:
--   dependency  nvarchar(1000)  -- object name (may be schema-qualified)
--   type        nvarchar(64)    -- 'index' | 'statistics' | 'foreign key' |
--                                 'computed column' | 'view' | 'module'
--
-- Notes:
--   - Primary key and unique constraints are reported as 'index' (the
--     underlying index is what blocks ALTER COLUMN).
--   - A column that participates in an FK is reported once per constraint,
--     with the constraint name, not the table name.
--   - `sys.sql_expression_dependencies` is the source for view and module
--     dependencies; it is authoritative for schema-bound objects and
--     best-effort for non-schema-bound ones.
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).column_dependencies
(
    @column nvarchar(1000)
)
RETURNS TABLE
AS
RETURN
(
    WITH
    parsed AS
    (
        SELECT [object_id], [db], [schema], [table], [column]
        FROM $(SchemaName).parse_column_name(@column)
    ),
    resolved AS
    (
        SELECT
            object_id  = p.[object_id],
            column_id  = COLUMNPROPERTY(p.[object_id], p.[column], 'ColumnId'),
            schema_name = ISNULL(p.[schema], N'dbo'),
            table_name  = p.[table],
            column_name = p.[column]
        FROM parsed AS p
    ),
    -- Indexes and statistics that reference the column. PK/unique constraints
    -- are reported as 'index' because that is what blocks ALTER COLUMN.
    idx AS
    (
        SELECT
            dependency = QUOTENAME(OBJECT_SCHEMA_NAME(i.object_id))
                       + N'.' + QUOTENAME(OBJECT_NAME(i.object_id))
                       + N'.' + QUOTENAME(i.name),
            type       = N'index'
        FROM            resolved            AS r
            INNER JOIN  sys.index_columns   AS ic   ON ic.object_id = r.object_id AND ic.column_id = r.column_id
            INNER JOIN  sys.indexes         AS i    ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.type <> 0                          -- skip heaps
          AND i.is_hypothetical = 0
    ),
    stats AS
    (
        SELECT
            dependency = QUOTENAME(OBJECT_SCHEMA_NAME(s.object_id))
                       + N'.' + QUOTENAME(OBJECT_NAME(s.object_id))
                       + N'.' + QUOTENAME(s.name),
            type       = N'statistics'
        FROM            resolved            AS r
            INNER JOIN  sys.stats_columns   AS sc   ON sc.object_id = r.object_id AND sc.column_id = r.column_id
            INNER JOIN  sys.stats           AS s    ON s.object_id = sc.object_id AND s.stats_id = sc.stats_id
        -- user-created stats only; auto-created stats are not a dependency
        -- the user can act on and should not block ALTER COLUMN
        WHERE s.auto_created = 0
          AND s.user_created = 1
    ),
    fk AS
    (
        SELECT
            dependency = QUOTENAME(OBJECT_SCHEMA_NAME(fk.object_id))
                       + N'.' + QUOTENAME(OBJECT_NAME(fk.object_id))
                       + N'.' + QUOTENAME(fk.name),
            type       = N'foreign key'
        FROM            resolved                AS r
            INNER JOIN  sys.foreign_key_columns AS fkc  ON
                (fkc.parent_object_id = r.object_id AND fkc.parent_column_id = r.column_id)
                OR
                (fkc.referenced_object_id = r.object_id AND fkc.referenced_column_id = r.column_id)
            INNER JOIN  sys.foreign_keys        AS fk   ON fk.object_id = fkc.constraint_object_id
    ),
    -- Computed columns in the same table that reference this column
    computed AS
    (
        SELECT
            dependency = QUOTENAME(OBJECT_SCHEMA_NAME(c.object_id))
                       + N'.' + QUOTENAME(OBJECT_NAME(c.object_id))
                       + N'.' + QUOTENAME(c.name),
            type       = N'computed column'
        FROM            resolved                        AS r
            INNER JOIN  sys.sql_expression_dependencies AS d
                ON d.referenced_id = r.object_id AND d.referenced_minor_id = r.column_id
            INNER JOIN  sys.columns                     AS c
                ON c.object_id = d.referencing_id AND c.column_id = d.referencing_minor_id
        WHERE c.is_computed = 1
    ),
    -- Views and other modules (procs, functions, triggers) that reference
    -- the column. sys.sql_expression_dependencies covers schema-bound
    -- objects and is best-effort for non-schema-bound ones.
    modules AS
    (
        SELECT
            dependency = QUOTENAME(OBJECT_SCHEMA_NAME(d.referencing_id))
                       + N'.' + QUOTENAME(OBJECT_NAME(d.referencing_id)),
            type       = CASE o.type
                             WHEN N'V' THEN N'view'
                             WHEN N'P' THEN N'module'
                             WHEN N'FN' THEN N'module'
                             WHEN N'IF' THEN N'module'
                             WHEN N'TF' THEN N'module'
                             WHEN N'TR' THEN N'module'
                             ELSE N'module'
                         END
        FROM            resolved                        AS r
            INNER JOIN  sys.sql_expression_dependencies AS d
                ON d.referenced_id = r.object_id AND d.referenced_minor_id = r.column_id
            INNER JOIN  sys.objects                     AS o
                ON o.object_id = d.referencing_id
        WHERE o.type IN (N'V', N'P', N'FN', N'IF', N'TF', N'TR')
    ),
    all_deps AS
    (
        SELECT dependency, type FROM idx
        UNION ALL
        SELECT dependency, type FROM stats
        UNION ALL
        SELECT dependency, type FROM fk
        UNION ALL
        SELECT dependency, type FROM computed
        UNION ALL
        SELECT dependency, type FROM modules
    )
    SELECT
        dependency,
        type
    FROM all_deps
    WHERE dependency IS NOT NULL
);
GO