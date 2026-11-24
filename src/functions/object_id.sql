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
	return object_id($(SchemaName).quoted_name(@db, @schema, @name), @type)
end
go