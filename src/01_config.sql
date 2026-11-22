create or alter proc $(SchemaName).set_config(@key varchar(50), @value nvarchar(1000))
as
begin
    set nocount on;

    set @key = trim(isnull(@key, ''))

    if @key = ''
        raiserror('$(SchemaName) set config: key is required', 16, 1)

    if not exists (select 1 from $(SchemaName).config where [key] = @key)
        insert into $(SchemaName).config([key], [value])
        values (@key, @value)
    else
        update $(SchemaName).config set [value] = @value where [key] = @key
end
go

create or alter function $(SchemaName).get_config(@key varchar(50))
returns nvarchar(1000)
as
begin
    return (select [value] from $(SchemaName).config where [key] = @key)
end
go