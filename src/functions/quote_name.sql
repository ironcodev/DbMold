create or alter function $(SchemaName).quote_name
(
	@db			sysname,
	@schema		sysname,
	@table		sysname,
	@column		sysname
)
returns $(SchemaName).object_name
as
begin
	RETURN
	(
		                QUOTENAME($(SchemaName).resolve_db(@db))
		       + N'.' + QUOTENAME($(SchemaName).resolve_schema(@db, @schema))
		+ ISNULL(N'.' + QUOTENAME(@table), N'')
		+ ISNULL(N'.' + QUOTENAME(@column), N'')
	);
end
go