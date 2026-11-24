create or alter function $(SchemaName).resolve_db(@db sysname)
returns sysname
as
begin
	RETURN (CASE WHEN $(SchemaName).is_null_or_empty(@db) = 1 THEN DB_NAME() ELSE @db END);
end
go