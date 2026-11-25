create or alter function $(SchemaName).column_summary
(
    @column $(SchemaName).object_name
)
returns table
as
return
(
    select
        [column_id]     = c.column_id,
        [pk]            = c.is_primary_key,
        [name]          = c.column_name,
        [type]          = $(SchemaName).column_type
        (
                     quotename(c.schema_name)
            + N'.' + quotename(c.table_name)
            + N'.' + quotename(c.column_name)
        ),
        [length]        = c.[length],
        [nullable]      = c.is_nullable,
        [identity]      = c.is_identity,
        [computed]      = c.is_computed,
        [persisted]     = c.is_persisted,
        [sparse]        = c.is_sparse,
        [filestream]    = c.is_filestream,
        [default]       = c.default_value,
        [formula]       = c.computed_definition,
        [description]   = c.column_description,
        [parent]        = c.parent_column
    from $(SchemaName).column_info(@column) c
);
go