-- =============================================
-- $(SchemaName).pad_left
-- =============================================
-- Left-pads @x with @ch until it reaches @size characters.
--
-- "Characters" are UTF-16 code units, matching len() and datalength()/2.
-- A character outside the BMP (e.g. an emoji) counts as 2.
--
-- If @x is null, returns null. If @size is null or <= 0, or if @x is
-- already at least @size wide, returns @x unchanged.
--
-- Examples:
--   pad_left(N'7',   N'0', 3)  -> N'007'
--   pad_left(N'123', N'0', 3)  -> N'123'
--   pad_left(N'1',   N'0', 0)  -> N'1'
--   pad_left(NULL,   N'0', 3)  -> NULL
-- =============================================
create or alter function $(SchemaName).pad_left
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

    return replicate(@ch, @size - (datalength(@x) / 2)) + @x;
end
go