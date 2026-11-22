create or alter function $(SchemaName).shift_right(@a bigint, @n tinyint)
returns bigint
as
begin
	return
	(
		case
			when isnull(@n, 0) <= 0 then @a
			else
				@a / power(2, @n)
		end
	)
end

GO