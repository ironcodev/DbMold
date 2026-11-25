create or alter function $(SchemaName)._string_max_length
(
    @system_type_id int,
    @length int
)
returns int
as
begin
    if @system_type_id is null
        return null;

    declare @max_length int = 0;

    ;with string_type_families as
    (
        select
            system_type_id,
            case
                when name in (N'varchar', N'char', N'varbinary', N'binary')
                    then N'bytes'

                when name in (N'nvarchar', N'nchar')
                    then N'unicode'

                when name in (N'text', N'ntext', N'xml', N'image')
                    then N'max'
            end size_family
        from sys.types
        where user_type_id = system_type_id
            and is_user_defined = 0
    )
    select @max_length =
        case size_family
            when N'bytes'   then @length
            when N'unicode' then case when @length = -1 then -1 else @length * 2 end
            when N'max'     then -1
            else 0
        end
    from string_type_families
    where system_type_id = @system_type_id;

    return @max_length;
end;
go

create or alter function $(SchemaName).string_max_length
(
    @type sysname,
    @length int
)
returns int
as
begin
    return
    (
        select $(SchemaName)._string_max_length(bt.system_type_id, @length)
        from            sys.types rt -- requested type
            inner join  sys.types bt
                on  bt.user_type_id = rt.system_type_id
                    and bt.user_type_id = bt.system_type_id
        where rt.user_type_id = type_id(@type)
    );
end;
go