drop function if exists m.column_info;
go
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
--   - parent_column is the fully qualified referenced column when this
--     column participates in a foreign key as the child side; NULL
--     otherwise. For a column in a composite FK, it names the single
--     referenced column this column maps to.
--   - is_primary_key is 1 when the column is part of the primary key.
--   - parent_column is NULL for the parent (referenced) side of an FK;
--     to find "who references me", query sys.foreign_key_columns with
--     referenced_object_id / referenced_column_id instead.
--   - primary_key_constraint is the name of the primary key constraint
--     when the column participates in the PK, NULL otherwise.
--   - foreign_key_constraint is the name of the foreign key constraint
--     when the column is the child side of an FK, NULL otherwise.
--     For a composite FK, every column in the constraint gets the same
--     constraint name.
--   - parent_column and foreign_key_constraint are both NULL for the
--     referenced (parent) side of an FK; the join reports the child side.
-- =============================================
create or alter function $(SchemaName).column_info
(
    @name nvarchar(1000)
)
returns @result table
(
    [db]                nvarchar(1000),
    schema_name         nvarchar(500),
    table_name          nvarchar(500),
    column_name         nvarchar(500),
    column_id           int,
    type_name           nvarchar(500),
    type_schema_id      int,
    type_schema_name    nvarchar(500),
    user_type_id        int,
    system_type_id      int,
    max_length          int,
    [length]            int,
    [precision]         int,
    scale               int,
    collation_name      nvarchar(500),
    is_nullable         bit,
    is_identity         bit,
    is_computed         bit,
    is_persisted        bit,
    is_sparse           bit,
    is_filestream       bit,
    is_xml              bit,
    is_xml_document     bit,
    is_rowguidcol       bit,
    default_value       nvarchar(max),
    default_name        nvarchar(500),
    computed_definition nvarchar(max),
    column_description  nvarchar(max),
    parent_column       nvarchar(1000),   -- fully qualified parent column when this is an FK, else NULL
    is_primary_key      bit,              -- 1 when the column participates in the PK, else 0
    primary_key_constraint  nvarchar(500),   -- name of the PK constraint, NULL if not in the PK
    foreign_key_constraint  nvarchar(500)   -- name of the FK constraint, NULL if not an FK
)
begin
    with parsed as
    (
        select
            [db], [schema], [table], [column],
            object_id = object_id(
                quotename(isnull([db], db_name()))
              + N'.' + quotename(isnull([schema], N'dbo'))
              + N'.' + quotename([table]))
        from $(SchemaName).parse_column_name(@name)
    )
    insert @result
    select
        [db]                = isnull(p.[db], db_name()),
        schema_name         = p.[schema],
        table_name          = p.[table],
        column_name         = p.[column],
        column_id           = c.column_id,
        type_name           = t.name,
        type_schema_id      = t.schema_id,
        type_schema_name    = schema_name(t.schema_id),
        user_type_id        = c.user_type_id,
        system_type_id      = c.system_type_id,
        max_length          = c.max_length,
        [length]            = case
                                  when c.max_length = -1 then -1
                                  when c.system_type_id in (231, 239) then c.max_length / 2
                                  when c.system_type_id in (165, 167, 173, 175) then c.max_length
                                  else 0
                              end,
        [precision]         = c.[precision],
        scale               = c.scale,
        collation_name      = c.collation_name,
        is_nullable         = c.is_nullable,
        is_identity         = c.is_identity,
        is_computed         = c.is_computed,
        is_persisted        = isnull(cc.is_persisted, 0),
        is_sparse           = c.is_sparse,
        is_filestream       = c.is_filestream,
        is_xml              = case when c.system_type_id = 241 then 1 else 0 end,
        is_xml_document     = c.is_xml_document,
        is_rowguidcol       = c.is_rowguidcol,
        default_value       = $(SchemaName)._normalize_default(dc.definition),
        default_name        = dc.name,
        computed_definition = cc.definition,
        column_description  = cast(ep.value as nvarchar(max)),
        parent_column       = case
                                  when fk.object_id is null then null
                                  else quotename(object_schema_name(fkc.referenced_object_id))
                                     + N'.' + quotename(object_name(fkc.referenced_object_id))
                                     + N'.' + quotename(rc.name)
                              end,
        is_primary_key          = case when pk.column_id is not null then 1 else 0 end,
        primary_key_constraint  = pk.pk_name,
        foreign_key_constraint  = fk.name
    from             parsed                       as p
          inner join sys.columns                  as c    on  c.object_id = p.object_id
                                                              and c.name = p.[column]
          inner join sys.types                    as t    on  t.user_type_id = c.user_type_id
          left  join sys.default_constraints      as dc   on  dc.parent_object_id = c.object_id
                                                              and dc.parent_column_id = c.column_id
          left  join sys.computed_columns         as cc   on  cc.object_id = c.object_id
                                                              and cc.column_id = c.column_id
          left  join sys.extended_properties      as ep   on  ep.major_id = c.object_id
                                                              and ep.minor_id = c.column_id
                                                              and ep.name = N'MS_Description'
                                                              and ep.class = 1
          left  join sys.foreign_key_columns      as fkc  on  fkc.parent_object_id = c.object_id
                                                              and fkc.parent_column_id = c.column_id
          left  join sys.foreign_keys             as fk   on  fk.object_id = fkc.constraint_object_id
          left  join sys.columns                  as rc   on  rc.object_id = fkc.referenced_object_id
                                                              and rc.column_id = fkc.referenced_column_id
          left  join (select ic.object_id, ic.column_id, i.name as pk_name
                       from sys.index_columns ic
                       join sys.indexes       i on i.object_id = ic.object_id and i.index_id = ic.index_id
                       where i.is_primary_key = 1) as pk
                                                 on  pk.object_id = c.object_id
                                                              and pk.column_id = c.column_id
  return;
end
go
