create or alter function $(SchemaName).parse_column_name(@name nvarchar(1000))
returns @result table 
(
	[db] nvarchar(500),
	[schema] nvarchar(500),
	[table] nvarchar(500),
	[column] nvarchar(500)
)
as
begin
	set @name = trim(@name)
	
	if @name is null or len(@name) = 0
		return
	
	declare @db nvarchar(500)
	declare @schema nvarchar(500)
	declare @table nvarchar(500)
	declare @column nvarchar(500)

	declare @part1 nvarchar(500)
	declare @part2 nvarchar(500)
	declare @part3 nvarchar(500)
	declare @part4 nvarchar(500)

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
		set @schema = 'dbo'
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

	insert into @result([db], [schema], [table], [column])
	values (@db, @schema, @table, @column)

	return
end

go