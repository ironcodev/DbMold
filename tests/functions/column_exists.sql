-- =============================================
-- Tests for mold.column_exists
-- =============================================
SET NOCOUNT ON;

DECLARE @failures int = 0;

-- ---------- Setup ----------
IF OBJECT_ID(N'dbo.__mold_test_tbl', N'U') IS NOT NULL
    DROP TABLE dbo.__mold_test_tbl;
CREATE TABLE dbo.__mold_test_tbl
(
    Id int NOT NULL,
    Name nvarchar(100) NULL
);

IF SCHEMA_ID(N'__mold_test_schema') IS NULL
    EXEC(N'CREATE SCHEMA __mold_test_schema');
IF OBJECT_ID(N'__mold_test_schema.__mold_test_tbl2', N'U') IS NOT NULL
    DROP TABLE __mold_test_schema.__mold_test_tbl2;
EXEC(N'CREATE TABLE __mold_test_schema.__mold_test_tbl2 (Id int, Code nvarchar(50))');

IF OBJECT_ID(N'tempdb..#__mold_test_tmp', N'U') IS NOT NULL
    DROP TABLE #__mold_test_tmp;
CREATE TABLE #__mold_test_tmp (Id int, Value int);

IF OBJECT_ID(N'tempdb..##__mold_test_gtmp', N'U') IS NOT NULL
    DROP TABLE ##__mold_test_gtmp;
CREATE TABLE ##__mold_test_gtmp (Id int, Label nvarchar(20));

IF OBJECT_ID(N'dbo.__mold_test_view', N'V') IS NOT NULL
    DROP VIEW dbo.__mold_test_view;
EXEC(N'CREATE VIEW dbo.__mold_test_view AS SELECT 1 AS Id');

-- ---------- Assertions ----------

-- 1. Non-existent column on existing table
IF mold.column_exists(N'dbo.__mold_test_tbl.Missing') <> 0
BEGIN
    PRINT 'FAIL [1]: non-existent column should return 0';
    SET @failures += 1;
END

-- 2. Existing column, fully qualified
IF mold.column_exists(N'dbo.__mold_test_tbl.Id') <> 1
BEGIN
    PRINT 'FAIL [2]: dbo.__mold_test_tbl.Id should exist';
    SET @failures += 1;
END

-- 3. Existing column, unqualified table (default schema)
IF mold.column_exists(N'__mold_test_tbl.Id') <> 1
BEGIN
    PRINT 'FAIL [3]: unqualified table should resolve to dbo';
    SET @failures += 1;
END

-- 4. Second column of same table
IF mold.column_exists(N'dbo.__mold_test_tbl.Name') <> 1
BEGIN
    PRINT 'FAIL [4]: dbo.__mold_test_tbl.Name should exist';
    SET @failures += 1;
END

-- 5. Custom schema, existing column
IF mold.column_exists(N'__mold_test_schema.__mold_test_tbl2.Code') <> 1
BEGIN
    PRINT 'FAIL [5]: custom schema column should exist';
    SET @failures += 1;
END

-- 6. Custom schema, missing column
IF mold.column_exists(N'__mold_test_schema.__mold_test_tbl2.Missing') <> 0
BEGIN
    PRINT 'FAIL [6]: missing column should return 0';
    SET @failures += 1;
END

-- 7. Local temp table is NOT supported (UDF limitation)
IF mold.column_exists(N'#__mold_test_tmp.Id') <> 0
BEGIN
    PRINT 'FAIL [7]: local temp tables should return 0 (UDF limitation)';
    SET @failures += 1;
END

-- 8. Same for temp tables with a non-existent column
IF mold.column_exists(N'#__mold_test_tmp.Missing') <> 0
BEGIN
    PRINT 'FAIL [8]: local temp table should return 0';
    SET @failures += 1;
END

-- 9. Global temp table is NOT supported either
IF mold.column_exists(N'##__mold_test_gtmp.Label') <> 0
BEGIN
    PRINT 'FAIL [9]: global temp tables should return 0 (UDF limitation)';
    SET @failures += 1;
END

-- 10. Quoted names, existing column
IF mold.column_exists(N'[__mold_test_schema].[__mold_test_tbl2].[Code]') <> 1
BEGIN
    PRINT 'FAIL [10]: quoted names should resolve';
    SET @failures += 1;
END

-- 11. NULL input
IF mold.column_exists(NULL) <> 0
BEGIN
    PRINT 'FAIL [11]: NULL should return 0';
    SET @failures += 1;
END

-- 12. Empty input
IF mold.column_exists(N'') <> 0
BEGIN
    PRINT 'FAIL [12]: empty string should return 0';
    SET @failures += 1;
END

-- 13. Whitespace-only input
IF mold.column_exists(N'   ') <> 0
BEGIN
    PRINT 'FAIL [13]: whitespace-only should return 0';
    SET @failures += 1;
END

-- 14. No dot (cannot identify column)
IF mold.column_exists(N'__mold_test_tbl') <> 0
BEGIN
    PRINT 'FAIL [14]: name without dot should return 0';
    SET @failures += 1;
END

-- 15. Object does not exist
IF mold.column_exists(N'dbo.__mold_no_such_table.Id') <> 0
BEGIN
    PRINT 'FAIL [15]: non-existent table should return 0';
    SET @failures += 1;
END

-- 16. Object is a view, not a table
IF mold.column_exists(N'dbo.__mold_test_view.Id') <> 0
BEGIN
    PRINT 'FAIL [16]: view should not count as a table';
    SET @failures += 1;
END

-- 17. Leading/trailing whitespace around the full name
IF mold.column_exists(N'  dbo.__mold_test_tbl.Id  ') <> 1
BEGIN
    PRINT 'FAIL [17]: trimmed name should resolve';
    SET @failures += 1;
END

-- 18. Table part with quoted dot in name
IF OBJECT_ID(N'__mold_test_schema.[__mold_dotted.tbl]', N'U') IS NULL
    EXEC(N'CREATE TABLE __mold_test_schema.[__mold_dotted.tbl] (Id int)');
IF mold.column_exists(N'[__mold_test_schema].[__mold_dotted.tbl].[Id]') <> 1
BEGIN
    PRINT 'FAIL [18]: quoted dotted table name should resolve';
    SET @failures += 1;
END

-- ---------- Teardown ----------
DROP TABLE dbo.__mold_test_tbl;
DROP TABLE __mold_test_schema.__mold_test_tbl2;
DROP TABLE #__mold_test_tmp;
DROP TABLE ##__mold_test_gtmp;
DROP VIEW  dbo.__mold_test_view;
IF OBJECT_ID(N'__mold_test_schema.[__mold_dotted.tbl]', N'U') IS NOT NULL
    DROP TABLE __mold_test_schema.[__mold_dotted.tbl];
DROP SCHEMA __mold_test_schema;

-- ---------- Report ----------
IF @failures = 0
    PRINT 'All column_exists tests passed.';
ELSE
    PRINT CONCAT(@failures, ' column_exists test(s) FAILED.');