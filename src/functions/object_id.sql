create or alter function $(SchemaName).object_id
(
	@db		sysname,
	@schema	sysname,
	@name	sysname,
	@type	nvarchar(60)
)
returns int
as
begin
	return object_id($(SchemaName).quote_name(@db, @schema, @name, null), @type)
end
go