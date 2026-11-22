create or alter function $(SchemaName).string_equals
(
	@a nvarchar(max),
	@b nvarchar(max),
	@trim bit,
	@ignoreCase bit
)
returns bit
as
begin
	declare @result bit

	set @a = isnull(@a, '')
	set @b = isnull(@b, '')
	
	if @trim = 1
	begin
		set @a = trim(@a)
		set @b = trim(@b)
	end
	if @ignoreCase = 1
		set @result = case when @a = @b then 1 else 0 end
	else
		set @result = case when @a COLLATE Latin1_General_CS_AS = @b COLLATE Latin1_General_CS_AS then 1 else 0 end
	
	return @result
end

GO