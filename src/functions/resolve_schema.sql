create or alter function $(SchemaName).resolve_schema(@db sysname, @schema sysname)
returns sysname
as
begin
	DECLARE @current_db	sysname = DB_NAME();
	DECLARE @target_db	sysname = ISNULL(@db, @current_db);

	RETURN
	(
		ISNULL(
			@schema,
			CASE
				WHEN @target_db = @current_db THEN $(SchemaName).default_schema()
				ELSE N'dbo'
			END
		)
	);
end
go