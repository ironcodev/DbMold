-- =============================================
-- Tests for mold.table_exists
-- =============================================
SET NOCOUNT ON;

DECLARE @failures int = 0;

-- Helper: assert @actual = @expected
-- (inline, to keep the test file self-contained)

-- ---------- Setup ----------
IF OBJECT_ID(N'dbo.__mold_test_tbl', N'U') IS NOT NULL
    DROP TABLE dbo.__mold_test_tbl;
CREATE TABLE dbo.__mold_test_tbl (Id int);

IF SCHEMA_ID(N'__mold_test_schema') IS NULL
    EXEC(N'CREATE SCHEMA __mold_test_schema');
IF OBJECT_ID(N'__mold_test_schema.__mold_test_tbl2', N'U') IS NOT NULL
    DROP TABLE __mold_test_schema.__mold_test_tbl2;
EXEC(N'CREATE TABLE __mold_test_schema.__mold_test_tbl2 (Id int)');

IF OBJECT_ID(N'tempdb..#__mold_test_tmp', N'U') IS NOT NULL
    DROP TABLE #__mold_test_tmp;
CREATE TABLE #__mold_test_tmp (Id int);

IF OBJECT_ID(N'tempdb..##__mold_test_gtmp', N'U') IS NOT NULL
    DROP TABLE ##__mold_test_gtmp;
CREATE TABLE ##__mold_test_gtmp (Id int);

-- ---------- Assertions ----------

-- 1. Non-existent table
IF mold.table_exists(N'dbo.__mold_does_not_exist') <> 0
BEGIN
    PRINT 'FAIL: non-existent table should return 0';
    SET @failures += 1;
END

-- 2. Table with default schema (no dot)
IF mold.table_exists(N'__mold_test_tbl') <> 1
BEGIN
    PRINT 'FAIL: unqualified name should resolve to dbo';
    SET @failures += 1;
END

-- 3. Table with explicit schema
IF mold.table_exists(N'dbo.__mold_test_tbl') <> 1
BEGIN
    PRINT 'FAIL: dbo.__mold_test_tbl should exist';
    SET @failures += 1;
END

-- 4. Table in custom schema
IF mold.table_exists(N'__mold_test_schema.__mold_test_tbl2') <> 1
BEGIN
    PRINT 'FAIL: custom schema table should exist';
    SET @failures += 1;
END

-- 5. Local temp table
IF mold.table_exists(N'#__mold_test_tmp') <> 1
BEGIN
    PRINT 'FAIL: local temp table should exist';
    SET @failures += 1;
END

-- 6. Global temp table
IF mold.table_exists(N'##__mold_test_gtmp') <> 1
BEGIN
    PRINT 'FAIL: global temp table should exist';
    SET @failures += 1;
END

-- 7. Quoted name with dot
IF mold.table_exists(N'[__mold_test_schema].[__mold_test_tbl2]') <> 1
BEGIN
    PRINT 'FAIL: quoted name should resolve';
    SET @failures += 1;
END

-- 8. NULL input
IF mold.table_exists(NULL) <> 0
BEGIN
    PRINT 'FAIL: NULL should return 0';
    SET @failures += 1;
END

-- 9. Empty input
IF mold.table_exists(N'') <> 0
BEGIN
    PRINT 'FAIL: empty string should return 0';
    SET @failures += 1;
END

-- 10. Name with spaces around it
IF mold.table_exists(N'  dbo.__mold_test_tbl  ') <> 1
BEGIN
    PRINT 'FAIL: trimmed name should resolve';
    SET @failures += 1;
END

-- ---------- Teardown ----------
DROP TABLE IF EXISTS dbo.__mold_test_tbl;
DROP TABLE IF EXISTS __mold_test_schema.__mold_test_tbl2;
DROP TABLE IF EXISTS #__mold_test_tmp;
DROP TABLE IF EXISTS ##__mold_test_gtmp;
DROP SCHEMA IF EXISTS __mold_test_schema;

-- ---------- Report ----------
IF @failures = 0
    PRINT 'All table_exists tests passed.';
ELSE
    PRINT CONCAT(@failures, ' table_exists test(s) FAILED.');