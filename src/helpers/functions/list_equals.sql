CREATE OR ALTER FUNCTION $(SchemaName).list_equals
(
    @List1 NVARCHAR(MAX),
    @List2 NVARCHAR(MAX)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Result BIT = 0
    
    IF (trim(isnull(@List1, '')) = '' AND trim(isnull(@List2, '')) = '')
        RETURN 1
        
    IF (trim(isnull(@List1, '')) = '' OR trim(isnull(@List2, '')) = '')
        RETURN 0
    
    -- Split strings into tables and compare
    ;WITH CTE_List1 AS (
        SELECT trim(value) AS Item
        FROM STRING_SPLIT(@List1, ',')
    ),
    CTE_List2 AS (
        SELECT trim(value) AS Item
        FROM STRING_SPLIT(@List2, ',')
    ),
    CTE_List1_Counts AS (
        SELECT Item, COUNT(*) AS Count
        FROM CTE_List1
        GROUP BY Item
    ),
    CTE_List2_Counts AS (
        SELECT Item, COUNT(*) AS Count
        FROM CTE_List2
        GROUP BY Item
    ),
    CTE_AllItems AS (
        SELECT Item FROM CTE_List1
        UNION
        SELECT Item FROM CTE_List2
    ),
    CTE_Comparison AS (
        SELECT 
            AI.Item,
            ISNULL(L1.Count, 0) AS Count1,
            ISNULL(L2.Count, 0) AS Count2
        FROM CTE_AllItems AI
        LEFT JOIN CTE_List1_Counts L1 ON AI.Item = L1.Item
        LEFT JOIN CTE_List2_Counts L2 ON AI.Item = L2.Item
    )
    SELECT @Result = CASE 
        WHEN EXISTS (
            SELECT 1 FROM CTE_Comparison 
            WHERE Count1 != Count2
        ) THEN 0 
        ELSE 1 
    END
    
    RETURN @Result
END

GO