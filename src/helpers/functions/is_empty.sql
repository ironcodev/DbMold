create or alter function $(SchemaName).is_empty(@value nvarchar(max))
returns bit
as
begin
    return case
		when len(isnull(TRIM(NCHAR(0x09) + NCHAR(0x0A) + NCHAR(0x0B) + NCHAR(0x0C) + NCHAR(0x0D) + NCHAR(0x20) FROM @x), '')) = 0
		then 1 else 0
	end
end
go