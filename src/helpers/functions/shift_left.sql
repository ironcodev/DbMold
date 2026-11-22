create or alter function $(SchemaName).shift_left(@a bigint, @n tinyint)
returns bigint
as
begin
	return
	(
		case
			when isnull(@n, 0) <= 0 then @a
			when isnull(@n, 0) = 63 then -9223372036854775808
			when isnull(@n, 0) > 63 then cast(0 as bigint)
			else
				@a * power(cast(2 as bigint), @n)
		end
	)
end

GO