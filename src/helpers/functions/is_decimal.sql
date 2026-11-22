create or alter function $(SchemaName).is_decimal
(
	@x varchar(50)
)
returns bit
as
begin
	declare @result bit

	set @result = $(SchemaName).is_empty(@x)

	if @result = 0
	begin
		declare @i int

		set @i = charindex('.', @x)

		if @i > 0
		begin
			declare @left varchar(50)
			declare @right varchar(50)

			set @left = case when @i > 1 then ltrim(left(@x, @i - 1)) else '' end
			set @right = ltrim(right(@x, len(@x) - @i))

			if @left = '' and @right = ''
				set @result = 0
			else
			if @left = ''
				set @result = $(SchemaName).is_integer(@right)
			else
			if @right = ''
				set @result = $(SchemaName).is_integer(@left)
			else
				set @result = $(SchemaName).is_integer(@left) & $(SchemaName).is_integer(@right)
		end
		else
			set @result = $(SchemaName).is_integer(@x)
	end
	else
		set @result = 0

	return @result
end
go