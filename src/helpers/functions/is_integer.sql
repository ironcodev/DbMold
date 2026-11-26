CREATE OR ALTER FUNCTION $(SchemaName).[is_integer]
(
    @x VARCHAR(30)
)
RETURNS BIT
AS
BEGIN
    DECLARE @digits VARCHAR(30) =
        CASE
            WHEN @x LIKE '[+-]%' THEN SUBSTRING(@x, 2, 30)
            ELSE @x
        END;

    RETURN
    (
        SELECT ISNULL(
            (SELECT 0
             WHERE @digits LIKE '%[^0-9]%'
                OR @digits = ''
            ), 1)
    )
END
GO