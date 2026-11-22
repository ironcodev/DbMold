create or alter function $(SchemaName).is_decimal0
(
	@x varchar(50)
)
returns bit
as
begin
	return $(SchemaName).is_decimal(@x) & (case when trim(replace(replace(@x, '.', ''), '0', '')) = '' then 1 else 0 end)
end
go