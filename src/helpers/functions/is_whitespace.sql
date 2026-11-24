-- =============================================
-- $(SchemaName).is_whitespace
-- =============================================
-- Returns 1 if @value consists only of whitespace (space, tab, CR, LF),
-- 0 otherwise. A null value returns 0 (null is not whitespace).
-- An empty string returns 1 (vacuously all-whitespace).
--
-- Examples:
--   is_whitespace(N'   ')      -> 1
--   is_whitespace(N'  a  ')    -> 0
--   is_whitespace(N'')         -> 1
--   is_whitespace(NULL)        -> 0
--   is_whitespace(NCHAR(9))    -> 1
--   is_whitespace(N'a' + NCHAR(10) + N'b') -> 0
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).is_whitespace
(
    @value nvarchar(max)
)
RETURNS bit
AS
BEGIN
    IF @value IS NULL
        RETURN 0;

    RETURN CASE
        WHEN DATALENGTH(
            $(SchemaName).trim_whitespace(@value)
        ) = 0 THEN 1
        ELSE 0
    END;
END;
GO