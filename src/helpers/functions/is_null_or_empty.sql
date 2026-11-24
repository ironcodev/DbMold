create or alter function $(SchemaName).is_null_or_empty(@x nvarchar(max))
returns bit
as
begin
    return case
		when @x is null or DATALENGTH(@x) = 0 then 1
		else 0
	end
end
go