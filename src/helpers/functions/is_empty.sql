CREATE OR ALTER FUNCTION $(SchemaName).is_empty
(
    @x nvarchar(max)
)
RETURNS bit
AS
BEGIN
    RETURN CASE
        WHEN @x IS NULL
          OR DATALENGTH($(SchemaName).trim_whitespace(@x)) = 0
        THEN 1
        ELSE 0
    END;
END;
GO