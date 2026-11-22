create or alter function $(SchemaName).json_object_equals
(
    @Json1 NVARCHAR(MAX),
    @Json2 NVARCHAR(MAX)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0
    
    -- Use table variables instead of temp tables
    DECLARE @Object1 TABLE
	(
		[position] INT,
        [name] NVARCHAR(400),
        [type] INT,
        [value] NVARCHAR(MAX)
    )
    
    DECLARE @Object2 TABLE
	(
		[position] INT,
        [name] NVARCHAR(400),
        [type] INT,
        [value] NVARCHAR(MAX)
    )
    
    -- Parse JSON objects
    INSERT INTO @Object1 ([position], [name], [type], [value])
    SELECT
		ROW_NUMBER() OVER (ORDER BY [key]),
		[key],
		[type],
		[value]
    FROM OPENJSON(@Json1)
    ORDER BY [key]
    
    INSERT INTO @Object2 ([position], [name], [type], [value])
    SELECT
		ROW_NUMBER() OVER (ORDER BY [key]),
		[key],
		[type],
		[value]
    FROM OPENJSON(@Json2)
    ORDER BY [key]
    
    -- Check property count
    DECLARE @Count1 INT, @Count2 INT

    SELECT @Count1 = COUNT(*) FROM @Object1
    SELECT @Count2 = COUNT(*) FROM @Object2
    
    IF (@Count1 != @Count2)
        RETURN 0;
    
    WITH
		Sorted1 AS (SELECT * FROM @Object1),
		Sorted2 AS (SELECT * FROM @Object2)
    SELECT @Result = CASE 
        WHEN EXISTS (
            SELECT 1
            FROM Sorted1 s1
            INNER JOIN Sorted2 s2 ON s1.[position] = s2.[position]
            WHERE s1.[name] != s2.[name] 
                OR s1.[type] != s2.[type]
                OR (s1.[type] in (0,1,2,3) and s1.[value] != s2.[value])	-- null, number, boolean, string
				OR (s1.[type] = 4 and $(SchemaName).json_array_equals(s1.[value], s2.[value]) = 0)	-- array
				OR (s1.[type] = 5 and $(SchemaName).json_object_equals(s1.[value], s2.[value]) = 0)	-- object
        ) THEN 0 
        ELSE 1 
    END
    
    RETURN @Result
END
GO