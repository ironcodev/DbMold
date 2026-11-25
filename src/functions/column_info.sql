set ansi_nulls on
go

set quoted_identifier on
go

drop function if exists $(SchemaName).column_info;
go
-- =============================================
-- $(SchemaName).column_info
-- =============================================
-- Returns one row per column with detailed information,
-- or an empty result set if the specified column or table does not exist.
--
-- Input formats:
--   'Table.Column'                  -> dbo.Table.Column
--   'Schema.Table.Column'           -> Schema.Table.Column
--   'Db.Schema.Table.Column'        -> Db.Schema.Table.Column
--   '[sales].[My.Table].[My.Column]'-> sales.[My.Table].[My.Column]
--
-- Notes:
--   - max_length is the raw sys.columns value, in bytes; -1 means (max).
--   - length is the character count for nchar/nvarchar, the byte count
--     for char/varchar/binary/varbinary, and -1 for (max). It is
--     determined from system_type_id so UDTs based on those types are
--     handled correctly.
--   - is_xml is 1 for the xml system type; is_xml_document is the
--     separate flag from sys.columns that constrains the xml to document
--     form.
--   - default_value is normalized via _normalize_default; default_name
--     is the raw constraint name.
--   - parent_column contains the comma-separated list of distinct,
--     fully qualified referenced columns when this column participates
--     in one or more outgoing foreign keys; NULL otherwise.
--     For composite FKs, each child column maps to its corresponding
--     referenced column.
--   - parent_column is populated only for the child (referencing) side
--     of an FK. To find columns referencing this column, query
--     column_foreign_keys() or sys.foreign_key_columns.
--   - is_primary_key is 1 when the column is part of the primary key.
--   - primary_key_constraint is the name of the primary key constraint
--     when the column participates in the PK, NULL otherwise.
--   - is_primary_key is 1 when the column is part of the primary key.
--   - parent_column is NULL for the parent (referenced) side of an FK;
--     to find "who references me", query sys.foreign_key_columns with
--     referenced_object_id / referenced_column_id instead.
--   - primary_key_constraint is the name of the primary key constraint
--     when the column participates in the PK, NULL otherwise.
--   - parent_column and foreign_key_constraint are both NULL for the
--     referenced (parent) side of an FK; the join reports the child side.
--   - Returned table
-- @result table
-- (
--     [object_id]               int,
--     [db]                      sysname,
--     [schema_name]             sysname,
--     [table_name]              sysname,
--     [column_name]             sysname,
--     [column_id]               int,
--     [type_name]               sysname,
--     [type_schema_id]          int,
--     [type_schema_name]        sysname,
--     [user_type_id]            int,
--     [system_type_id]          int,
--     [max_length]              int,
--     [length]                  int,
--     [precision]               int,
--     [scale]                   int,
--     [collation_name]          sysname,
--     [is_nullable]             bit,
--     [is_identity]             bit,
--     [is_computed]             bit,
--     [is_persisted]            bit,
--     [is_sparse]               bit,
--     [is_filestream]           bit,
--     [is_xml]                  bit,
--     [is_xml_document]         bit,
--     [is_rowguidcol]           bit,
--     [default_value]           nvarchar(max),
--     [default_name]            sysname,
--     [computed_definition]     nvarchar(max),
--     [column_description]      nvarchar(max),
--     [parent_column]           nvarchar(max),   -- fully qualified parent column(s) when column participates in an FK, else NULL
--     [is_primary_key]          bit,              -- 1 when the column participates in the PK, else 0
--     [primary_key_constraint]  sysname,   -- name of the PK constraint, NULL if not in the PK
-- )
-- =============================================
create or alter function $(SchemaName).column_info
(
    @column $(SchemaName).object_name
)
returns table
as
return
(
    with parsed as
    (
        select
            [object_id], [db], [schema], [table], [column]
        from $(SchemaName).parse_column_name(@column)
        where [column] is not null

        union all

        select
            [object_id], [db], [schema], [table], [column]
        from $(SchemaName).parse_table_name(@column)
        where [column] is null
    )
    select
        [object_id]                       = p.[object_id],
        [db]                              = p.[db],
        [schema_name]                     = p.[schema],
        [table_name]                      = p.[table],
        [column_name]                     = c.name,
        [column_id]                       = c.column_id,
        [type_name]                       = t.name,
        [type_schema_id]                  = t.schema_id,
        [type_schema_name]                = schema_name(t.schema_id),
        [user_type_id]                    = c.user_type_id,
        [system_type_id]                  = c.system_type_id,
        [has_user_defined_type]           = t.is_user_defined,
        [has_assembly_type]               = t.is_assembly_type,
        [max_length]                      = c.max_length,
        [length]                          = $(SchemaName)._string_length(c.system_type_id, c.max_length),
        [precision]                       = c.[precision],
        [scale]                           = c.scale,
        [collation_name]                  = c.collation_name,
        [is_nullable]                     = c.is_nullable,
        [is_identity]                     = c.is_identity,
        [is_computed]                     = c.is_computed,
        [is_persisted]                    = isnull(cc.is_persisted, 0),
        [is_sparse]                       = c.is_sparse,
        [is_filestream]                   = c.is_filestream,
        [is_xml]                          = case when c.system_type_id = 241 then 1 else 0 end,
        [is_xml_document]                 = c.is_xml_document,
        [xml_schema_collection_id]        = nullif(c.xml_collection_id, 0),
        [xml_schema_collection_name]      = xsc.name,
        [xml_schema_collection_schema_id] = xsc.schema_id,
        [xml_schema_collection_schema_name] = schema_name(xsc.schema_id),
        [is_rowguidcol]                   = c.is_rowguidcol,
        [default_value]                   = $(SchemaName)._normalize_default(dc.definition),
        [default_name]                    = dc.name,
        [computed_definition]             = cc.definition,
        [column_description]              = cast(ep.value as nvarchar(max)),
        [parent_column]                   = fk.parent_column,
        [is_primary_key]                  = case when pk.column_id is not null then 1 else 0 end,
        [primary_key_constraint]          = pk.pk_name
    from            parsed                      p
        inner join  sys.columns                 c    on  c.object_id = p.object_id
                                                            and (c.name = p.[column] or p.[column] is null)
        inner join  sys.types                   t    on  t.user_type_id = c.user_type_id
        left join   sys.xml_schema_collections  xsc  on  xsc.xml_collection_id = c.xml_collection_id
        left join   sys.default_constraints     dc   on  dc.parent_object_id = c.object_id
                                                            and dc.parent_column_id = c.column_id
        left join   sys.computed_columns        cc   on  cc.object_id = c.object_id
                                                            and cc.column_id = c.column_id
        left join   sys.extended_properties     ep   on  ep.major_id = c.object_id
                                                            and ep.minor_id = c.column_id
                                                            and ep.name = N'MS_Description'
                                                            and ep.class = 1
        left join
        (
            select
                ic.object_id, ic.column_id, i.name pk_name
            from            sys.index_columns ic
                inner join  sys.indexes       i on i.object_id = ic.object_id and i.index_id = ic.index_id
            where i.is_primary_key = 1
        ) pk on  pk.object_id = c.object_id and pk.column_id = c.column_id
        outer apply
        (
            select
                parent_column = stuff
                (
                    (
                        select
                            N', ' + pc.parent_column
                        from
                        (
                            select distinct
                                parent_column =
                                    quotename(object_schema_name(fkc.referenced_object_id))
                                    + N'.' + quotename(object_name(fkc.referenced_object_id))
                                    + N'.' + quotename(rc.name)
                            from            sys.foreign_key_columns fkc
                                inner join  sys.columns             rc
                                    on  rc.object_id = fkc.referenced_object_id
                                            and rc.column_id = fkc.referenced_column_id
                            where fkc.parent_object_id = c.object_id
                                and fkc.parent_column_id = c.column_id
                        ) pc
                        order by pc.parent_column
                        for xml path(''), type
                    ).value('.', 'nvarchar(max)'),
                    1,
                    2,
                    N''
                )
        ) fk
    where p.object_id is not null
        and p.[db] = db_name()
);
go