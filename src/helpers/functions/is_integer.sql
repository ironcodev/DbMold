create or alter function $(SchemaName).[is_integer]
(
	@x varchar(20)
)
returns bit
as
begin
	return (select isnull((select 0 where @x like '%[^0-9]%'), 1))
end
go