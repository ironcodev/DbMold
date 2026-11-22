create or alter function $(SchemaName).pad_right
(
    @x    nvarchar(max),
    @ch   nchar(1),
    @size int
)
returns nvarchar(max)
as
begin
    if @x is null return null;
    if @size is null or @size <= 0 return @x;
    if (datalength(@x) / 2) >= @size return @x;

    return @x + replicate(@ch, @size - (datalength(@x) / 2));
end
go