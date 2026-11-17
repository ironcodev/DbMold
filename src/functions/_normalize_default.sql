-- =============================================
-- $(SchemaName)._normalize_default
-- =============================================
-- Normalizes a default-constraint definition for comparison.
--
--   - trims whitespace
--   - strips wrapping parentheses (repeatedly, up to 10 levels)
--
-- Examples:
--   '((10))'      -> '10'
--   '(getdate())' -> 'getdate()'
--   'N''x'''      -> 'N''x'''
--   NULL          -> NULL
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName)._normalize_default
(
    @value nvarchar(max)
)
RETURNS nvarchar(max)
AS
BEGIN
    IF @value IS NULL
        RETURN NULL;

    DECLARE @v nvarchar(max) = LTRIM(RTRIM(@value));
    DECLARE @i int = 0;

    -- Strip wrapping parentheses up to 20 levels deep.
    WHILE @i < 20
      AND LEN(@v) >= 2
      AND LEFT(@v, 1) = N'('
      AND RIGHT(@v, 1) = N')'
    BEGIN
        SET @v = LTRIM(RTRIM(SUBSTRING(@v, 2, LEN(@v) - 2)));
        SET @i += 1;
    END

    RETURN @v;
END;
GO