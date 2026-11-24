
CREATE OR ALTER FUNCTION $(SchemaName).trim_invisible_characters
(
    @value nvarchar(max)
)
RETURNS nvarchar(max)
AS
BEGIN
    IF @value IS NULL
        RETURN NULL;

    DECLARE @length int = DATALENGTH(@value) / 2;
    DECLARE @codepoint int;

    -- Trim from the beginning.
    WHILE @length > 0
    BEGIN
        SET @codepoint = UNICODE(LEFT(@value, 1));

        IF NOT
        (
            @codepoint IN (173, 847, 1564, 6158, 65279)
            OR @codepoint BETWEEN 8203 AND 8207
            OR @codepoint BETWEEN 8234 AND 8238
            OR @codepoint BETWEEN 8288 AND 8303
        )
            BREAK;

        SET @value = SUBSTRING(@value, 2, @length - 1);
        SET @length = @length - 1;
    END;

    -- Trim from the end.
    WHILE @length > 0
    BEGIN
        SET @codepoint = UNICODE(RIGHT(@value, 1));

        IF NOT
        (
            @codepoint IN (173, 847, 1564, 6158, 65279)
            OR @codepoint BETWEEN 8203 AND 8207
            OR @codepoint BETWEEN 8234 AND 8238
            OR @codepoint BETWEEN 8288 AND 8303
        )
            BREAK;

        SET @value = SUBSTRING(@value, 1, @length - 1);
        SET @length = @length - 1;
    END;

    RETURN @value;
END;
GO
