-- =============================================
-- $(SchemaName).trim_right
-- =============================================
-- Removes every trailing character in @chars from @s.
-- Portable replacement for the SQL Server 2022 TRAILING form of TRIM.
--
-- Examples:
--   trim_right(N'124.23000', N'0')  -> N'124.23'
--   trim_right(N'hello   ',  N' ')  -> N'hello'
--   trim_right(N'abcxx',     N'x')  -> N'abc'
--   trim_right(NULL,         N'0')  -> NULL
-- =============================================
create or alter function $(SchemaName).trim_right
(
    @s     nvarchar(max),
    @chars nvarchar(100)
)
returns nvarchar(max)
as
begin
    if @s is null or @chars is null or @chars = N''
        return @s;

    declare @i int = len(@s);

    while @i > 0 and charindex(substring(@s, @i, 1), @chars) > 0
        set @i -= 1;

    return left(@s, @i);
end