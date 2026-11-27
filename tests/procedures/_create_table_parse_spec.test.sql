
create or alter procedure sstr.create_table_parse_spec_defaults
as
begin
    set nocount on;

    create table #create_table_spec
    (
        [table_name]             nvarchar(776)  null,
        [columns_json]           nvarchar(4000)  null,
        [primary_key_json]       nvarchar(4000)  null,
        [primary_key_type]       int            null,
        [filegroups_json]        nvarchar(4000)  null,
        [dry_run]                bit            not null,
        [timeout]                int            not null,
        [primary_key_supplied]   bit            not null,
        [filegroups_supplied]    bit            not null
    );

    exec $(SchemaName)._create_table_parse_spec
        N'{
            "name": "sales.Products",
            "columns": [
                { "name": "Id", "type": "int" }
            ]
        }';

    declare
        @table_name             nvarchar(776),
        @columns_json           nvarchar(4000),
        @columns_are_equal      bit,
        @primary_key_supplied   bit,
        @filegroups_supplied    bit,
        @dry_run                bit,
        @timeout                int;

    select
        @table_name = [table_name],
        @columns_json = [columns_json],
        @primary_key_supplied = [primary_key_supplied],
        @filegroups_supplied = [filegroups_supplied],
        @dry_run = [dry_run],
        @timeout = [timeout]
    from #create_table_spec;

    set @columns_are_equal = $(SchemaName).json_equals
    (
        @columns_json,
        N'[
            {
                "name": "Id",
                "type": "int"
            }
        ]'
    );

    exec Assert.Equals @table_name, N'sales.Products', 'table_name';
    exec Assert.Equals @columns_are_equal, 1, 'columns';
    exec Assert.Equals @primary_key_supplied, 0, 'primary_key_supplied';
    exec Assert.Equals @filegroups_supplied, 0, 'filegroups_supplied';
    exec Assert.Equals @dry_run, 0, 'dry_run';
    exec Assert.Equals @timeout, -1, 'timeout';
end;
go


create or alter procedure sstr.create_table_parse_spec_primary_key_forms
as
begin
    set nocount on;

    create table #create_table_spec
    (
        [table_name]             nvarchar(776)  null,
        [columns_json]           nvarchar(4000)  null,
        [primary_key_json]       nvarchar(4000)  null,
        [primary_key_type]       int            null,
        [filegroups_json]        nvarchar(4000)  null,
        [dry_run]                bit            not null,
        [timeout]                int            not null,
        [primary_key_supplied]   bit            not null,
        [filegroups_supplied]    bit            not null
    );

    declare
        @primary_key_json       nvarchar(4000),
        @primary_key_type       int,
        @primary_key_supplied   bit;

    -- String form
    exec $(SchemaName)._create_table_parse_spec
        N'{
            "name": "dbo.Users",
            "columns": [{ "name": "Id", "type": "int" }],
            "primaryKey": "Id"
        }';

    select
        @primary_key_json = [primary_key_json],
        @primary_key_type = [primary_key_type],
        @primary_key_supplied = [primary_key_supplied]
    from #create_table_spec;

    exec Assert.Equals @primary_key_json, N'Id';
    exec Assert.Equals @primary_key_type, 1;
    exec Assert.Equals @primary_key_supplied, 1;

    delete from #create_table_spec;

    -- Array form
    exec $(SchemaName)._create_table_parse_spec
        N'{
            "name": "dbo.UserRoles",
            "columns": [
                { "name": "UserId", "type": "int" },
                { "name": "RoleId", "type": "int" }
            ],
            "primaryKey": ["UserId", "RoleId"]
        }';

    select
        @primary_key_json = [primary_key_json],
        @primary_key_type = [primary_key_type],
        @primary_key_supplied = [primary_key_supplied]
    from #create_table_spec;

    exec Assert.Equals @primary_key_json, N'["UserId", "RoleId"]';
    exec Assert.Equals @primary_key_type, 4;
    exec Assert.Equals @primary_key_supplied, 1;

    delete from #create_table_spec;

    -- Object form
    exec $(SchemaName)._create_table_parse_spec
        N'{
            "name": "dbo.UserRoles",
            "columns": [
                { "name": "UserId", "type": "int" },
                { "name": "RoleId", "type": "int" }
            ],
            "primaryKey": {
                "columns": ["UserId", "RoleId"],
                "clustered": true,
                "name": "PK_UserRoles"
            }
        }';

    select
        @primary_key_json = [primary_key_json],
        @primary_key_type = [primary_key_type],
        @primary_key_supplied = [primary_key_supplied]
    from #create_table_spec;

    exec Assert.Equals @primary_key_type, 5;
    exec Assert.Equals @primary_key_supplied, 1;

    if isjson(@primary_key_json) <> 1
        throw 51000, N'Expected primary-key JSON to be preserved.', 1;
end;
go


create or alter procedure sstr.create_table_parse_spec_optional_settings
as
begin
    set nocount on;

    create table #create_table_spec
    (
        [table_name]             nvarchar(776)  null,
        [columns_json]           nvarchar(4000)  null,
        [primary_key_json]       nvarchar(4000)  null,
        [primary_key_type]       int            null,
        [filegroups_json]        nvarchar(4000)  null,
        [dry_run]                bit            not null,
        [timeout]                int            not null,
        [primary_key_supplied]   bit            not null,
        [filegroups_supplied]    bit            not null
    );

    declare
        @dry_run             bit,
        @timeout             int,
        @filegroups_json     nvarchar(4000),
        @filegroups_supplied bit;

    -- Explicit true
    exec $(SchemaName)._create_table_parse_spec
        N'{
            "name": "dbo.Products",
            "columns": [{ "name": "Id", "type": "int" }],
            "dryRun": true,
            "timeout": 5000,
            "filegroups": {
                "data": "FG_DATA",
                "textImage": "FG_LOB"
            }
        }';

    select
        @dry_run = [dry_run],
        @timeout = [timeout],
        @filegroups_json = [filegroups_json],
        @filegroups_supplied = [filegroups_supplied]
    from #create_table_spec;

    exec Assert.Equals @dry_run, 1;
    exec Assert.Equals @timeout, 5000;
    exec Assert.Equals @filegroups_supplied, 1;

    if isjson(@filegroups_json) <> 1
        throw 51000, N'Expected filegroups JSON to be preserved.', 1;

    delete from #create_table_spec;

    -- Explicit false
    exec $(SchemaName)._create_table_parse_spec
        N'{
            "name": "dbo.Products",
            "columns": [{ "name": "Id", "type": "int" }],
            "dryRun": false
        }';

    select @dry_run = [dry_run]
    from #create_table_spec;

    exec Assert.Equals @dry_run, 0;
end;
go


create or alter procedure sstr.create_table_parse_spec_invalid_root
as
begin
    set nocount on;

    create table #create_table_spec
    (
        [table_name]             nvarchar(776)  null,
        [columns_json]           nvarchar(4000)  null,
        [primary_key_json]       nvarchar(4000)  null,
        [primary_key_type]       int            null,
        [filegroups_json]        nvarchar(4000)  null,
        [dry_run]                bit            not null,
        [timeout]                int            not null,
        [primary_key_supplied]   bit            not null,
        [filegroups_supplied]    bit            not null
    );

    declare
        @spec  nvarchar(4000),
        @error int;

    -- Invalid JSON
    set @spec = N'{ invalid json }';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- Root array instead of object
    set @spec = N'[]';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- Missing name
    set @spec = N'{"columns": [{"name": "Id", "type": "int"}]}';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- Empty name
    set @spec = N'{"name": " ", "columns": [{"name": "Id", "type": "int"}]}';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- Missing columns
    set @spec = N'{"name": "dbo.Products"}';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- Columns is not an array
    set @spec = N'{"name": "dbo.Products", "columns": {}}';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- Empty columns array
    set @spec = N'{"name": "dbo.Products", "columns": []}';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;
end;
go


create or alter procedure sstr.create_table_parse_spec_invalid_options
as
begin
    set nocount on;

    create table #create_table_spec
    (
        [table_name]             nvarchar(776)  null,
        [columns_json]           nvarchar(4000)  null,
        [primary_key_json]       nvarchar(4000)  null,
        [primary_key_type]       int            null,
        [filegroups_json]        nvarchar(4000)  null,
        [dry_run]                bit            not null,
        [timeout]                int            not null,
        [primary_key_supplied]   bit            not null,
        [filegroups_supplied]    bit            not null
    );

    declare
        @spec  nvarchar(4000),
        @error int;

    -- Unsupported primaryKey type
    set @spec = N'{
        "name": "dbo.Products",
        "columns": [{"name": "Id", "type": "int"}],
        "primaryKey": 123
    }';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- filegroups must be an object
    set @spec = N'{
        "name": "dbo.Products",
        "columns": [{"name": "Id", "type": "int"}],
        "filegroups": []
    }';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- dryRun must be a boolean
    set @spec = N'{
        "name": "dbo.Products",
        "columns": [{"name": "Id", "type": "int"}],
        "dryRun": "true"
    }';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- timeout must be an integer
    set @spec = N'{
        "name": "dbo.Products",
        "columns": [{"name": "Id", "type": "int"}],
        "timeout": "5000"
    }';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- timeout cannot be less than -1
    set @spec = N'{
        "name": "dbo.Products",
        "columns": [{"name": "Id", "type": "int"}],
        "timeout": -2
    }';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;
end;
go


create or alter procedure sstr.create_table_parse_spec_duplicate_unknown_properties
as
begin
    set nocount on;

    create table #create_table_spec
    (
        [table_name]             nvarchar(776)  null,
        [columns_json]           nvarchar(4000)  null,
        [primary_key_json]       nvarchar(4000)  null,
        [primary_key_type]       int            null,
        [filegroups_json]        nvarchar(4000)  null,
        [dry_run]                bit            not null,
        [timeout]                int            not null,
        [primary_key_supplied]   bit            not null,
        [filegroups_supplied]    bit            not null
    );

    declare
        @spec  nvarchar(4000),
        @error int;

    -- Duplicate root property
    set @spec = N'{
        "name": "dbo.Products",
        "name": "dbo.OtherProducts",
        "columns": [{"name": "Id", "type": "int"}]
    }';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;

    -- Unknown root property
    set @spec = N'{
        "name": "dbo.Products",
        "columns": [{"name": "Id", "type": "int"}],
        "unknownOption": true
    }';
    set @error = 0;

    begin try
        exec $(SchemaName)._create_table_parse_spec @spec;
    end try
    begin catch
        set @error = error_number();
    end catch;

    exec Assert.Equals @error, 50000;
end;
go
