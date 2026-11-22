create or alter function $(SchemaName).quote(@value nvarchar(max))
returns nvarchar(max)
as
begin
    return isnull(N'''' + @value + N'''', N'NULL');
end
go