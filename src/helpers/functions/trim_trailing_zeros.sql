create or alter function $(SchemaName).trim_trailing_zeros (@s nvarchar(max))
returns nvarchar(max)
as
begin
    while len(@s) > 0 and right(@s, 1) = '0'
        set @s = left(@s, len(@s) - 1);
    if right(@s, 1) = '.'
        set @s = left(@s, len(@s) - 1);
    return @s;
end
go