create or alter function $(SchemaName).json_equals
(
    @Json1 NVARCHAR(MAX),
    @Json2 NVARCHAR(MAX)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0
    
    -- Handle NULL cases
    IF (@Json1 IS NULL AND @Json2 IS NULL)
        RETURN 1
    
    IF (@Json1 IS NULL OR @Json2 IS NULL)
        RETURN 0
    
    -- Handle empty strings
    DECLARE @TrimmedJson1 NVARCHAR(MAX) = LTRIM(RTRIM(@Json1))
    DECLARE @TrimmedJson2 NVARCHAR(MAX) = LTRIM(RTRIM(@Json2))
    
    IF (@TrimmedJson1 = '' AND @TrimmedJson2 = '')
        RETURN 1
        
    IF (@TrimmedJson1 = '' OR @TrimmedJson2 = '')
        RETURN 0
    
    -- Validate JSON format
    IF (ISJSON(@Json1) = 0 OR ISJSON(@Json2) = 0)
        RETURN 0
    
    -- Fast path: identical strings
    IF (@TrimmedJson1 = @TrimmedJson2)
        RETURN 1
    
    -- Check JSON types
    DECLARE @FirstChar1 CHAR(1) = LEFT(@TrimmedJson1, 1)
    DECLARE @FirstChar2 CHAR(1) = LEFT(@TrimmedJson2, 1)
    
    -- Different JSON types
    IF (@FirstChar1 != @FirstChar2)
        RETURN 0
    
    -- Arrays
    IF (@FirstChar1 = '[')
        RETURN $(SchemaName).json_array_equals(@Json1, @Json2)
    
    -- Objects
    IF (@FirstChar1 = '{')
        RETURN $(SchemaName).json_object_equals(@Json1, @Json2)
    
    -- Scalars
    RETURN CASE WHEN @TrimmedJson1 = @TrimmedJson2 THEN 1 ELSE 0 END
END
GO