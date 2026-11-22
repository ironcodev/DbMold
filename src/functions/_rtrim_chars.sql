-- =============================================
-- $(SchemaName)._rtrim_chars
-- =============================================
-- Removes any trailing characters in @chars from @s. Portable replacement for
-- RTRIM(@s, @chars), which requires SQL Server 2022 / compat level 160+.
--
-- Examples:
--   _rtrim_chars(N'Users.',   N'.')   -> N'Users'
--   _rtrim_chars(N'Users..',  N'.')   -> N'Users'
--   _rtrim_chars(N'Users.  ', N'. ')  -> N'Users'
--   _rtrim_chars(NULL,        N'.')   -> NULL
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName)._rtrim_chars
(
    @s     nvarchar(max),
    @chars nvarchar(100)
)
RETURNS nvarchar(max)
AS
BEGIN
    IF @s IS NULL OR @chars IS NULL OR @chars = N''
        RETURN @s;

    DECLARE @i int = LEN(@s);
    WHILE @i > 0 AND CHARINDEX(SUBSTRING(@s, @i, 1), @chars) > 0
        SET @i -= 1;

    RETURN LEFT(@s, @i);
END
GO