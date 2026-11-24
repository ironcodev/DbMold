-- =============================================
-- $(SchemaName).trim_right
-- =============================================
-- Removes every trailing character in @chars from @s.
-- Portable replacement for the SQL Server 2022 TRAILING form of TRIM.
--
-- Examples:
--   trim_right(N'124.23000', N'0', 0)  -> N'124.23'
--   trim_right(N'hello   ',  N' ', 0)  -> N'hello'
--   trim_right(N'abcxx',     N'x', 1)  -> N'abc'
--   trim_right(N'abcXX',     N'x', 0)  -> N'abcXX'
--   trim_right(NULL,         N'0', 0)  -> NULL
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).trim_right
(
    @s                nvarchar(max),
    @chars            nvarchar(100),
    @case_insensitive bit
)
RETURNS nvarchar(max)
AS
BEGIN
    IF @s IS NULL OR @chars IS NULL OR DATALENGTH(@chars) = 0
        RETURN @s;

    DECLARE @i int = DATALENGTH(@s) / 2;

    WHILE @i > 0
    BEGIN
        IF ISNULL(@case_insensitive, 0) = 1
        BEGIN
            IF CHARINDEX(SUBSTRING(@s, @i, 1), @chars) = 0
                BREAK;
        END
        ELSE
        BEGIN
            IF CHARINDEX(
                SUBSTRING(@s, @i, 1) COLLATE Latin1_General_100_BIN2,
                @chars COLLATE Latin1_General_100_BIN2
            ) = 0
                BREAK;
        END;

        SET @i -= 1;
    END;

    RETURN LEFT(@s, @i);
END;
GO