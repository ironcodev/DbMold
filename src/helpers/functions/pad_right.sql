create function $(SchemaName).pad_right(@x nvarchar(1000), @ch char(1), @size int)
returns nvarchar(2000)
as
begin
	declare @result nvarchar(2000)
	
	if @x is not null
	begin
		set @size = isnull(@size, 0)

		if @size > 0
		begin
			if (datalength(@x) / 2) < @size
				set @result = @x + replicate(@ch, @size - (datalength(@x) / 2))
			else
				set @result = @x
		end
		else
			set @result = @x
	end

	return @result
end

GO