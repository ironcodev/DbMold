CREATE OR ALTER FUNCTION $(SchemaName).is_null_or_whitespace
(
    @value nvarchar(max)
)
RETURNS bit
AS
BEGIN
    RETURN CASE
        WHEN @value IS NULL
          OR DATALENGTH(
                $(SchemaName).trim_whitespace(@value)
             ) = 0
        THEN 1
        ELSE 0
    END;
END;
GO