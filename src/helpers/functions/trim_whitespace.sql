CREATE OR ALTER FUNCTION $(SchemaName).trim_whitespace
(
    @value nvarchar(max)
)
RETURNS nvarchar(max)
AS
BEGIN
    RETURN $(SchemaName).ltrim_whitespace(
        $(SchemaName).rtrim_whitespace(@value)
    );
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).rtrim_whitespace
(
    @value nvarchar(max)
)
RETURNS nvarchar(max)
AS
BEGIN
    RETURN REVERSE(
        $(SchemaName).ltrim_whitespace(
            REVERSE(@value)
        )
    );
END;
GO


CREATE OR ALTER FUNCTION $(SchemaName).ltrim_whitespace
(
    @value nvarchar(max)
)
RETURNS nvarchar(max)
AS
BEGIN
    IF @value IS NULL
        RETURN NULL;

    DECLARE @codepoint int;

    WHILE DATALENGTH(@value) > 0
    BEGIN
        SET @codepoint = UNICODE(LEFT(@value, 1));

        IF NOT
        (
            @codepoint BETWEEN 9 AND 13
            OR @codepoint IN
            (
                32,       -- U+0020 SPACE
                133,      -- U+0085 NEXT LINE
                160,      -- U+00A0 NO-BREAK SPACE
                5760,     -- U+1680 OGHAM SPACE MARK
                8232,     -- U+2028 LINE SEPARATOR
                8233,     -- U+2029 PARAGRAPH SEPARATOR
                8239,     -- U+202F NARROW NO-BREAK SPACE
                8287,     -- U+205F MEDIUM MATHEMATICAL SPACE
                12288     -- U+3000 IDEOGRAPHIC SPACE
            )
            OR @codepoint BETWEEN 8192 AND 8202
        )
            BREAK;

        SET @value = SUBSTRING(
            @value,
            2,
            DATALENGTH(@value) / 2
        );
    END;

    RETURN @value;
END;
GO
