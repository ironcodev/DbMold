create or alter function $(SchemaName).is_whitespace(@value nvarchar(max))
returns bit
as
begin
    return case when len(trim(replace(replace(replace(isnull(@value, ''), ' ', ''), char(13), ''), ' ', ''))) = 0 then 1 else 0 end
end
go