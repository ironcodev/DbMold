-- =============================================
-- $(SchemaName).trim_left
-- =============================================
-- Removes every leading character in @chars from @s.
-- Portable replacement for the SQL Server 2022 LEADING form of TRIM.
--
-- Examples:
--   trim_left(N'000124',   N'0')  -> N'124'
--   trim_left(N'   hello', N' ')  -> N'hello'
--   trim_left(N'xxabc',    N'x')  -> N'abc'
--   trim_left(NULL,        N'0')  -> NULL
-- =============================================
create or alter function $(SchemaName).trim_left
(
    @s     nvarchar(max),
    @chars nvarchar(100)
)
returns nvarchar(max)
as
begin
    if @s is null or @chars is null or @chars = N''
        return @s;

    declare @i int = 1;
    declare @n int = len(@s);

    while @i <= @n and charindex(substring(@s, @i, 1), @chars) > 0
        set @i += 1;

    return substring(@s, @i, @n - @i + 1);
end