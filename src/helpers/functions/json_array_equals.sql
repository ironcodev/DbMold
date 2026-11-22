create or alter function $(SchemaName).json_array_equals
(
    @JsonArray1 NVARCHAR(MAX),
    @JsonArray2 NVARCHAR(MAX)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0
    
    -- Handle NULL cases
    IF (@JsonArray1 IS NULL AND @JsonArray2 IS NULL)
        RETURN 1
    
    IF (@JsonArray1 IS NULL OR @JsonArray2 IS NULL)
        RETURN 0
    
    -- Handle empty strings
    DECLARE @Trimmed1 NVARCHAR(MAX) = LTRIM(RTRIM(@JsonArray1))
    DECLARE @Trimmed2 NVARCHAR(MAX) = LTRIM(RTRIM(@JsonArray2))
    
    IF (@Trimmed1 = '[]' AND @Trimmed2 = '[]')
        RETURN 1
        
    IF (@Trimmed1 = '[]' OR @Trimmed2 = '[]')
        RETURN 0
    
    -- Validate JSON format
    IF (ISJSON(@JsonArray1) = 0 OR ISJSON(@JsonArray2) = 0)
        RETURN 0
    
    -- Create table variables for array items
    DECLARE @Array1 TABLE
	(
        [position] INT,
        [type] INT,
        [value] NVARCHAR(MAX)
    )
    
    DECLARE @Array2 TABLE
	(
        [position] INT,
        [type] INT,
        [value] NVARCHAR(MAX)
    )
    
    -- Parse arrays
    INSERT INTO @Array1 ([position], [value], [type])
    SELECT 
        [key],
        [value],
        [type]
    FROM OPENJSON(@JsonArray1)
    
    INSERT INTO @Array2 ([position], [value], [type])
    SELECT 
        [key],
        [value],
        [type]
    FROM OPENJSON(@JsonArray2)
    
    -- Check counts
    DECLARE @Count1 INT, @Count2 INT

    SELECT @Count1 = COUNT(*) FROM @Array1
    SELECT @Count2 = COUNT(*) FROM @Array2
    
    IF (@Count1 != @Count2)
        RETURN 0;
    
	-- Check count of items based on their type
    WITH
		Counts1 AS
		(
			SELECT [type], COUNT(*) AS [count] FROM @Array1 GROUP BY [type]
		),
		Counts2 AS
		(
			SELECT [type], COUNT(*) AS [count] FROM @Array2 GROUP BY [type]
		),
		AllItems AS
		(
			SELECT * FROM Counts1
			UNION
			SELECT * FROM Counts2
		),
		Comparison AS
		(
			SELECT 
				AI.[type],
				ISNULL(C1.[count], 0) AS Count1,
				ISNULL(C2.[count], 0) AS Count2
			FROM AllItems AI
				LEFT JOIN Counts1 C1 ON AI.[type] = C1.[type]
				LEFT JOIN Counts2 C2 ON AI.[type] = C2.[type]
		)
    SELECT @Result = CASE 
        WHEN EXISTS (SELECT 1 FROM Comparison WHERE Count1 != Count2) THEN 0 
        ELSE 1 
    END;

	IF @Result = 1
	WITH
		Sorted1 AS (SELECT * FROM @Array1),
		Sorted2 AS (SELECT * FROM @Array2)
	SELECT @Result = CASE 
		WHEN EXISTS
		(
			SELECT 1
			FROM Sorted1 s1
				INNER JOIN Sorted2 s2 ON s1.[position] = s2.[position]
			WHERE s1.[type] != s2.[type]
				OR (s1.[type] in (0,1,2,3) and s1.[value] != s2.[value])	-- null, number, boolean, string
				OR (s1.[type] = 4 and $(SchemaName).json_array_equals(s1.[value], s2.[value]) = 0)	-- array
				OR (s1.[type] = 5 and $(SchemaName).json_object_equals(s1.[value], s2.[value]) = 0)	-- object
		) THEN 0 
		ELSE 1 
	END
    
    
    RETURN @Result
END
GO