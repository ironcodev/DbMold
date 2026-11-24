create or alter function $(SchemaName).default_schema()
returns sysname
as
begin
	return ISNULL(SCHEMA_NAME(), N'dbo')
end
go