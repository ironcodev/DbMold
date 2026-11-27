
create or alter procedure $(SchemaName)._create_table_parse_spec
    @spec nvarchar(max)
as
begin
    set nocount on;

    declare
        @first_char             nchar(1),
        @position               int = 1,
        @table_name             nvarchar(max),
        @columns_json           nvarchar(max),
        @primary_key_json       nvarchar(max),
        @primary_key_type       int,
        @filegroups_json        nvarchar(max),
        @dry_run_value          nvarchar(max),
        @timeout_value          nvarchar(max),
        @dry_run_type           int,
        @timeout_type           int,
        @dry_run                bit = 0,
        @timeout                int = -1,
        @primary_key_supplied   bit = 0,
        @filegroups_supplied    bit = 0;

    declare @properties table
    (
        [key]   nvarchar(4000) collate Latin1_General_100_BIN2 not null,
        [value] nvarchar(max) null,
        [type]  int not null
    );

    if @spec is null or isjson(@spec) <> 1
        throw 50000, N'Invalid JSON specification.', 1;

    -- Require a JSON object, not an array or scalar.
    while @position <= len(@spec)
    begin
        set @first_char = substring(@spec, @position, 1);

        if @first_char not in (N' ', nchar(9), nchar(10), nchar(13))
            break;

        set @position += 1;
    end;

    if substring(@spec, @position, 1) <> N'{'
        throw 50000, N'The specification must be a JSON object.', 1;

    insert into @properties
    (
        [key],
        [value],
        [type]
    )
    select
        [key],
        [value],
        [type]
    from openjson(@spec);

    if exists
    (
        select [key]
        from @properties
        group by [key]
        having count(*) > 1
    )
        throw 50000, N'Duplicate JSON properties are not allowed.', 1;

    if exists
    (
        select 1
        from @properties
        where [key] not in
        (
            N'name',
            N'columns',
            N'primaryKey',
            N'filegroups',
            N'dryRun',
            N'timeout'
        )
    )
        throw 50000, N'Unknown property in table specification.', 1;

    -- name
    if not exists
    (
        select 1
        from @properties
        where [key] = N'name'
          and [type] = 1
    )
        throw 50000, N'The table name is required and must be a string.', 1;

    select @table_name = [value]
    from @properties
    where [key] = N'name';

    if nullif(ltrim(rtrim(@table_name)), N'') is null
        throw 50000, N'The table name cannot be empty.', 1;

    -- columns
    if not exists
    (
        select 1
        from @properties
        where [key] = N'columns'
          and [type] = 4
    )
        throw 50000, N'The columns property is required and must be an array.', 1;

    select @columns_json = [value]
    from @properties
    where [key] = N'columns';

    if not exists (select 1 from openjson(@columns_json))
        throw 50000, N'The columns array cannot be empty.', 1;

    -- primaryKey
    if exists
    (
        select 1
        from @properties
        where [key] = N'primaryKey'
    )
    begin
        set @primary_key_supplied = 1;

        select
            @primary_key_json = [value],
            @primary_key_type = [type]
        from @properties
        where [key] = N'primaryKey';

        if @primary_key_type not in (1, 4, 5)
            throw 50000, N'primaryKey must be a string, an array, or an object.', 1;
    end;

    -- filegroups
    if exists
    (
        select 1
        from @properties
        where [key] = N'filegroups'
    )
    begin
        set @filegroups_supplied = 1;

        select @filegroups_json = [value]
        from @properties
        where [key] = N'filegroups'
          and [type] = 5;

        if @filegroups_json is null
            throw 50000, N'filegroups must be an object.', 1;
    end;

    -- dryRun
    if exists
    (
        select 1
        from @properties
        where [key] = N'dryRun'
    )
    begin
        select
            @dry_run_value = [value],
            @dry_run_type = [type]
        from @properties
        where [key] = N'dryRun';

        if @dry_run_type <> 3
            throw 50000, N'dryRun must be a boolean.', 1;

        set @dry_run =
            case @dry_run_value
                when N'true'  then 1
                else 0
            end;
    end;

    -- timeout
    if exists
    (
        select 1
        from @properties
        where [key] = N'timeout'
    )
    begin
        select
            @timeout_value = [value],
            @timeout_type = [type]
        from @properties
        where [key] = N'timeout';

        if @timeout_type <> 2
           or try_convert(int, @timeout_value) is null
            throw 50000, N'timeout must be an integer.', 1;

        set @timeout = convert(int, @timeout_value);

        if @timeout < -1
            throw 50000, N'timeout cannot be less than -1.', 1;
    end;

    if object_id(N'tempdb..#create_table_spec') is null
        throw 50000, N'Required staging table #create_table_spec does not exist.', 1;

    if exists (select 1 from #create_table_spec)
        throw 50000, N'Staging table #create_table_spec must be empty.', 1;

    insert into #create_table_spec
    (
        [table_name],
        [columns_json],
        [primary_key_json],
        [primary_key_type],
        [filegroups_json],
        [dry_run],
        [timeout],
        [primary_key_supplied],
        [filegroups_supplied]
    )
    values
    (
        @table_name,
        @columns_json,
        @primary_key_json,
        @primary_key_type,
        @filegroups_json,
        @dry_run,
        @timeout,
        @primary_key_supplied,
        @filegroups_supplied
    );
end;
go
