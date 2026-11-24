-- =============================================
-- $(SchemaName).trim_left
-- =============================================
-- Removes every leading character in @chars from @s.
-- Portable replacement for the SQL Server 2022 LEADING form of TRIM.
--
-- Examples:
--   trim_left(N'000124',   N'0', 1)  -> N'124'
--   trim_left(N'   hello', N' ', 1)  -> N'hello'
--   trim_left(N'xxabc',    N'x', 1)  -> N'abc'
--   trim_left(N'XXabc',    N'x', 0)  -> N'XXabc'
--   trim_left(NULL,        N'0', 1)  -> NULL
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).trim_left
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

    DECLARE @i int = 1;
    DECLARE @n int = DATALENGTH(@s) / 2;

    WHILE @i <= @n
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

        SET @i += 1;
    END;

    RETURN SUBSTRING(@s, @i, @n - @i + 1);
END;
GO