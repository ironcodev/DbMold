create or alter function $(SchemaName).parse_column_name
(
	@name $(SchemaName).object_name
)
returns @result table 
(
	[object_id]		int null,
	[db] 			sysname null,
	[schema] 		sysname null,
	[table] 		sysname null,
	[column] 		sysname null,
	[quoted_table]	$(SchemaName).object_name null,
	[quoted_column]	$(SchemaName).object_name null
)
as
begin
	if $(SchemaName).is_null_or_empty(@name) = 1
		return
	
	declare @db		sysname
	declare @schema sysname
	declare @table	sysname
	declare @column sysname

	declare @part1 sysname
	declare @part2 sysname
	declare @part3 sysname
	declare @part4 sysname

	select
		@part1 = parsename(@name, 4),
		@part2 = parsename(@name, 3),
		@part3 = parsename(@name, 2),
		@part4 = parsename(@name, 1)

	if @part1 is null and @part2 is null and @part3 is null
	begin
		set @column = @part4
	end
	else
	if @part1 is null and @part2 is null
	begin
		set @table = @part3
		set @column = @part4
	end
	else
	if @part1 is null
	begin
		set @schema = @part2
		set @table = @part3
		set @column = @part4
	end
	else
	begin
		set @db = @part1
		set @schema = @part2
		set @table = @part3
		set @column = @part4
	end

	set @db = $(SchemaName).resolve_db(@db)
	set @schema = $(SchemaName).resolve_schema(@db, @schema);

	insert into @result
	(
		[object_id],
		[db],
		[schema],
		[table],
		[column],
		[quoted_table],
		[quoted_column]
	)
	values
	(
		$(SchemaName).object_id(@db, @schema, @table, N'U'),
		@db,
    	@schema,
		@table,
		@column,
		$(SchemaName).quote_name(@db, @schema, @table, null),
		$(SchemaName).quote_name(@db, @schema, @table, @column)
	)

	return
end

go