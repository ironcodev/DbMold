
create or alter procedure $(SchemaName)._create_table_validate_columns
as
begin
    set nocount on;

    declare
        @columns_json nvarchar(max),
        @error_message nvarchar(2048);

    if object_id(N'tempdb..#create_table_spec') is null
        throw 50000, N'_create_table_validate_columns: #create_table_spec does not exist.', 1;

    if object_id(N'tempdb..#create_table_columns') is null
        throw 50000, N'_create_table_validate_columns: #create_table_columns does not exist.', 1;

    if (select count(*) from #create_table_spec) <> 1
        throw 50000, N'_create_table_validate_columns: #create_table_spec must contain exactly one row.', 1;

    if exists (select 1 from #create_table_columns)
        throw 50000, N'_create_table_validate_columns: #create_table_columns must be empty.', 1;

    select @columns_json = [columns_json]
    from #create_table_spec;

    if @columns_json is null or isjson(@columns_json) <> 1
        throw 50000, N'_create_table_validate_columns: invalid columns JSON.', 1;

    create table #create_table_column_items
    (
        [ordinal]       int            not null,
        [spec_json]     nvarchar(max)  not null,
        [json_type]     int            not null
    );

    insert into #create_table_column_items
    (
        [ordinal],
        [spec_json],
        [json_type]
    )
    select
        convert(int, [key]) + 1,
        [value],
        [type]
    from openjson(@columns_json);

    if not exists (select 1 from #create_table_column_items)
        throw 50000, N'_create_table_validate_columns: columns must not be empty.', 1;

    if exists
    (
        select 1
        from #create_table_column_items
        where [json_type] <> 5
    )
        throw 50000, N'_create_table_validate_columns: every column definition must be a JSON object.', 1;

    create table #create_table_column_properties
    (
        [ordinal]       int             not null,
        [property_name] nvarchar(4000)  not null,
        [property_value] nvarchar(max) null,
        [json_type]     int             not null
    );

    insert into #create_table_column_properties
    (
        [ordinal],
        [property_name],
        [property_value],
        [json_type]
    )
    select
        i.[ordinal],
        p.[key],
        p.[value],
        p.[type]
    from #create_table_column_items i
        cross apply openjson(i.[spec_json]) p;

    -- Reject duplicate properties.
    if exists
    (
        select 1
        from #create_table_column_properties
        group by
            [ordinal],
            [property_name] collate Latin1_General_100_BIN2
        having count(*) > 1
    )
        throw 50000, N'_create_table_validate_columns: duplicate column property.', 1;

    -- Reject unknown properties.
    if exists
    (
        select 1
        from #create_table_column_properties
        where [property_name] collate Latin1_General_100_BIN2 not in
        (
            N'name',
            N'type',
            N'nullable',
            N'sparse',
            N'identity',
            N'default',
            N'default_name',
            N'computed'
        )
    )
        throw 50000, N'_create_table_validate_columns: unknown column property.', 1;

    create table #create_table_column_work
    (
        [ordinal]              int             not null,
        [spec_json]            nvarchar(max)   not null,
        [name]                 nvarchar(max)   null,
        [name_type]            int             null,
        [type_declaration]     nvarchar(max)   null,
        [type_type]            int             null,
        [nullable_value]       nvarchar(max)   null,
        [nullable_type]        int             null,
        [sparse_value]         nvarchar(max)   null,
        [sparse_type]          int             null,
        [identity_json]        nvarchar(max)   null,
        [identity_type]        int             null,
        [default_expression]   nvarchar(max)   null,
        [default_type]         int             null,
        [default_name]         nvarchar(max)   null,
        [default_name_type]    int             null,
        [computed_json]        nvarchar(max)   null,
        [computed_type]        int             null
    );

    insert into #create_table_column_work
    (
        [ordinal],
        [spec_json],
        [name],
        [name_type],
        [type_declaration],
        [type_type],
        [nullable_value],
        [nullable_type],
        [sparse_value],
        [sparse_type],
        [identity_json],
        [identity_type],
        [default_expression],
        [default_type],
        [default_name],
        [default_name_type],
        [computed_json],
        [computed_type]
    )
    select
        i.[ordinal],
        i.[spec_json],
        max(case when p.[property_name] = N'name' then p.[property_value] end),
        max(case when p.[property_name] = N'name' then p.[json_type] end),
        max(case when p.[property_name] = N'type' then p.[property_value] end),
        max(case when p.[property_name] = N'type' then p.[json_type] end),
        max(case when p.[property_name] = N'nullable' then p.[property_value] end),
        max(case when p.[property_name] = N'nullable' then p.[json_type] end),
        max(case when p.[property_name] = N'sparse' then p.[property_value] end),
        max(case when p.[property_name] = N'sparse' then p.[json_type] end),
        max(case when p.[property_name] = N'identity' then p.[property_value] end),
        max(case when p.[property_name] = N'identity' then p.[json_type] end),
        max(case when p.[property_name] = N'default' then p.[property_value] end),
        max(case when p.[property_name] = N'default' then p.[json_type] end),
        max(case when p.[property_name] = N'default_name' then p.[property_value] end),
        max(case when p.[property_name] = N'default_name' then p.[json_type] end),
        max(case when p.[property_name] = N'computed' then p.[property_value] end),
        max(case when p.[property_name] = N'computed' then p.[json_type] end)
    from #create_table_column_items i
        left join #create_table_column_properties p
            on p.[ordinal] = i.[ordinal]
    group by
        i.[ordinal],
        i.[spec_json];

    -- Validate the required column name.
    if exists
    (
        select 1
        from #create_table_column_work
        where [name_type] is null
            or [name_type] <> 1
            or nullif(ltrim(rtrim([name])), N'') is null
            or datalength([name]) > 256
    )
        throw 50000, N'_create_table_validate_columns: every column requires a valid name of at most 128 characters.', 1;

    -- Reject duplicate column names.
    if exists
    (
        select 1
        from #create_table_column_work
        group by [name]
        having count(*) > 1
    )
        throw 50000, N'_create_table_validate_columns: duplicate column names.', 1;

    -- Validate the JSON types of nullable and sparse.
    if exists
    (
        select 1
        from #create_table_column_work
        where
            ([nullable_type] is not null and
                ([nullable_type] <> 3 or [nullable_value] not in (N'true', N'false')))
            or
            ([sparse_type] is not null and
                ([sparse_type] <> 3 or [sparse_value] not in (N'true', N'false')))
    )
        throw 50000, N'_create_table_validate_columns: nullable and sparse must be JSON booleans.', 1;

    -- Validate the JSON type of identity.
    if exists
    (
        select 1
        from #create_table_column_work
        where [identity_type] is not null
            and [identity_type] <> 5
    )
        throw 50000, N'_create_table_validate_columns: identity must be a JSON object.', 1;

    -- Validate default and default_name.
    if exists
    (
        select 1
        from #create_table_column_work
        where
            ([default_type] is not null and [default_type] <> 1)
            or
            ([default_name_type] is not null and [default_name_type] <> 1)
    )
        throw 50000, N'_create_table_validate_columns: default and default_name must be strings.', 1;

    -- Validate computed object type.
    if exists
    (
        select 1
        from #create_table_column_work
        where [computed_type] is not null
            and [computed_type] <> 5
    )
        throw 50000, N'_create_table_validate_columns: computed must be a JSON object.', 1;

    -- Computed-column properties.
    create table #create_table_computed_properties
    (
        [ordinal]          int             not null,
        [property_name]    nvarchar(4000)  not null,
        [property_value]   nvarchar(max)   null,
        [json_type]        int             not null
    );

    insert into #create_table_computed_properties
    (
        [ordinal],
        [property_name],
        [property_value],
        [json_type]
    )
    select
        w.[ordinal],
        p.[key],
        p.[value],
        p.[type]
    from #create_table_column_work w
        cross apply openjson(w.[computed_json]) p
    where w.[computed_type] = 5;

    if exists
    (
        select 1
        from #create_table_computed_properties
        group by
            [ordinal],
            [property_name] collate Latin1_General_100_BIN2
        having count(*) > 1
    )
        throw 50000, N'_create_table_validate_columns: duplicate computed property.', 1;

    if exists
    (
        select 1
        from #create_table_computed_properties
        where [property_name] collate Latin1_General_100_BIN2 not in
        (
            N'expression',
            N'persisted'
        )
    )
        throw 50000, N'_create_table_validate_columns: unknown computed property.', 1;

    create table #create_table_computed_work
    (
        [ordinal]          int             not null,
        [expression]       nvarchar(max)   null,
        [expression_type]  int             null,
        [persisted]        nvarchar(max)   null,
        [persisted_type]   int             null
    );

    insert into #create_table_computed_work
    (
        [ordinal],
        [expression],
        [expression_type],
        [persisted],
        [persisted_type]
    )
    select
        w.[ordinal],
        max(case when p.[property_name] = N'expression' then p.[property_value] end),
        max(case when p.[property_name] = N'expression' then p.[json_type] end),
        max(case when p.[property_name] = N'persisted' then p.[property_value] end),
        max(case when p.[property_name] = N'persisted' then p.[json_type] end)
    from #create_table_column_work w
        left join #create_table_computed_properties p
            on p.[ordinal] = w.[ordinal]
    where w.[computed_type] = 5
    group by w.[ordinal];

    if exists
    (
        select 1
        from #create_table_computed_work
        where [expression_type] is null
            or [expression_type] <> 1
            or nullif(ltrim(rtrim([expression])), N'') is null
    )
        throw 50000, N'_create_table_validate_columns: computed.expression is required and must be a nonempty string.', 1;

    if exists
    (
        select 1
        from #create_table_computed_work
        where [persisted_type] is not null
            and ([persisted_type] <> 3 or [persisted] not in (N'true', N'false'))
    )
        throw 50000, N'_create_table_validate_columns: computed.persisted must be a JSON boolean.', 1;

    -- Ordinary columns require a type declaration.
    if exists
    (
        select 1
        from #create_table_column_work
        where [computed_type] is null
            and
            (
                [type_type] is null
                or [type_type] <> 1
                or nullif(ltrim(rtrim([type_declaration])), N'') is null
                or datalength([type_declaration]) > 8000
            )
    )
        throw 50000, N'_create_table_validate_columns: type is required and must be a nonempty string of at most 4000 characters.', 1;

    -- Parse ordinary column types.
    create table #create_table_parsed_types
    (
        [ordinal]              int             not null,
        [type_metadata_json]   nvarchar(max)   not null,
        [is_nullable]          bit             not null,
        [is_valid]             bit             not null,
        [validation_error]     nvarchar(4000)  null
    );

    insert into #create_table_parsed_types
    (
        [ordinal],
        [type_metadata_json],
        [is_nullable],
        [is_valid],
        [validation_error]
    )
    select
        w.[ordinal],
        parsed.[metadata],
        case json_value(parsed.[metadata], N'$.is_nullable')
            when N'true' then 1
            else 0
        end,
        case json_value(parsed.[metadata], N'$.is_valid')
            when N'true' then 1
            else 0
        end,
        json_value(parsed.[metadata], N'$.validation_error')
    from #create_table_column_work w
        cross apply
        (
            select
            (
                select pt.*
                from $(SchemaName).parse_type(w.[type_declaration]) pt
                for json path, without_array_wrapper
            ) [metadata]
        ) parsed
    where w.[computed_type] is null;

    if exists
    (
        select 1
        from #create_table_parsed_types
        where [is_valid] = 0
    )
    begin
        select top (1) @error_message = [validation_error]
        from #create_table_parsed_types
        where [is_valid] = 0
        order by [ordinal];

        throw 50002, @error_message, 1;
    end;

    -- A nullable type suffix conflicts with explicit nullable:false.
    if exists
    (
        select 1
        from #create_table_column_work w
            inner join #create_table_parsed_types p
                on p.[ordinal] = w.[ordinal]
        where p.[is_nullable] = 1
            and w.[nullable_type] = 3
            and w.[nullable_value] = N'false'
    )
        throw 50002, N'create_column: nullabality conflict. column is set explicitly not nullable, but its "type" says it is nullable.', 1;

    -- Populate normalized staging table.
    insert into #create_table_columns
    (
        [ordinal],
        [name],
        [type_declaration],
        [type_metadata_json],
        [is_nullable],
        [is_sparse],
        [identity_json],
        [default_expression],
        [default_name],
        [is_computed],
        [computed_expression],
        [computed_persisted],
        [column_spec_json]
    )
    select
        w.[ordinal],
        convert(sysname, w.[name]),
        case when w.[computed_type] is null then convert(nvarchar(4000), w.[type_declaration]) end,
        p.[type_metadata_json],
        case
            when w.[computed_type] = 5 then null
            when p.[is_nullable] = 1 then 1
            when w.[nullable_type] = 3 and w.[nullable_value] = N'true' then 1
            else 0
        end,
        case when w.[computed_type] = 5 then 0
            when w.[sparse_type] = 3 and w.[sparse_value] = N'true' then 1
            else 0
        end,
        case when w.[computed_type] = 5 then null else w.[identity_json] end,
        case when w.[computed_type] = 5 then null else w.[default_expression] end,
        case when w.[computed_type] = 5 then null else convert(sysname, w.[default_name]) end,
        case when w.[computed_type] = 5 then 1 else 0 end,
        cw.[expression],
        case
            when w.[computed_type] = 5
                then case when cw.[persisted] = N'true' then 1 else 0 end
        end,
        w.[spec_json]
    from #create_table_column_work w
        left join #create_table_parsed_types p
            on p.[ordinal] = w.[ordinal]
        left join #create_table_computed_work cw
            on cw.[ordinal] = w.[ordinal];
end;
go