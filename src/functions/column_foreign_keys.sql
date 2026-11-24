
create or alter function $(SchemaName).column_foreign_keys
(
    @column $(SchemaName).object_name,
    @dir varchar(8)
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
    ),
    target_columns as
    (
        select
            c.object_id,
            c.column_id
        from            parsed      p
            inner join  sys.columns c   on  c.object_id = p.object_id
                                            and (c.name = p.[column] or p.[column] is null)
        where p.object_id is not null
            and p.[db] = db_name()
    )
    select
        direction               = cast('outgoing' as varchar(8)),
        constraint_name         = fk.name,

        child_schema            = object_schema_name(fk.parent_object_id),
        child_table             = object_name(fk.parent_object_id),
        child_column            = pc.name,

        parent_schema           = object_schema_name(fk.referenced_object_id),
        parent_table            = object_name(fk.referenced_object_id),
        parent_column           = rc.name,

        constraint_column_id    = fkc.constraint_column_id,
        is_disabled             = fk.is_disabled,
        is_not_trusted          = fk.is_not_trusted,
        delete_rule             = fk.delete_referential_action_desc,
        update_rule             = fk.update_referential_action_desc
    from            target_columns          tc
        inner join  sys.foreign_key_columns fkc on  fkc.parent_object_id = tc.object_id
                                                    and fkc.parent_column_id = tc.column_id
        inner join  sys.foreign_keys        fk  on  fk.object_id = fkc.constraint_object_id
        inner join  sys.columns             pc  on  pc.object_id = fkc.parent_object_id
                                                    and pc.column_id = fkc.parent_column_id
        inner join  sys.columns             rc  on  rc.object_id = fkc.referenced_object_id
                                                    and rc.column_id = fkc.referenced_column_id
    where @dir is null or @dir = '' or @dir in ('out', 'outgoing')

    union all

    select
        direction               = cast('incoming' as varchar(8)),
        constraint_name         = fk.name,

        child_schema            = object_schema_name(fk.parent_object_id),
        child_table             = object_name(fk.parent_object_id),
        child_column            = pc.name,

        parent_schema           = object_schema_name(fk.referenced_object_id),
        parent_table            = object_name(fk.referenced_object_id),
        parent_column           = rc.name,

        constraint_column_id    = fkc.constraint_column_id,
        is_disabled             = fk.is_disabled,
        is_not_trusted          = fk.is_not_trusted,
        delete_rule             = fk.delete_referential_action_desc,
        update_rule             = fk.update_referential_action_desc
    from            target_columns          tc
        inner join  sys.foreign_key_columns fkc on  fkc.referenced_object_id = tc.object_id
                                                    and fkc.referenced_column_id = tc.column_id
        inner join  sys.foreign_keys        fk  on  fk.object_id = fkc.constraint_object_id
        inner join  sys.columns             pc  on  pc.object_id = fkc.parent_object_id
                                                    and pc.column_id = fkc.parent_column_id
        inner join  sys.columns             rc  on  rc.object_id = fkc.referenced_object_id
                                                    and rc.column_id = fkc.referenced_column_id
    where @dir is null or @dir = '' or @dir in ('in', 'incoming')
);
go
