-- =============================================
-- Tests for $(SchemaName).table_exists
-- =============================================

-- 1. Table with full name (dbo.)
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_1_for_dbo_table
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE dbo.__sstr_test_tbl;
    CREATE TABLE dbo.__sstr_test_tbl (Id int);

    DECLARE @result bit = $(SchemaName).table_exists('dbo.__sstr_test_tbl');
    EXEC Assert.Equals @result, 1;

    DROP TABLE dbo.__sstr_test_tbl;
END
GO

-- 2. Table with unqualified name (defaults to dbo)
CREATE OR ALTER PROCEDURE sstr.table_exists_should_resolve_unqualified_name_to_dbo
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE dbo.__sstr_test_tbl;
    CREATE TABLE dbo.__sstr_test_tbl (Id int);

    DECLARE @result bit = $(SchemaName).table_exists('__sstr_test_tbl');
    EXEC Assert.Equals @result, 1;

    DROP TABLE dbo.__sstr_test_tbl;
END
GO

-- 3. Missing table
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_0_for_missing_table
AS
BEGIN
    DECLARE @result bit = $(SchemaName).table_exists('dbo.__sstr_no_such_table_xyz');
    EXEC Assert.Equals @result, 0;
END
GO

-- 4. Table in a custom schema
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_1_for_custom_schema_table
AS
BEGIN
    IF SCHEMA_ID('__sstr_schema') IS NULL EXEC('CREATE SCHEMA __sstr_schema');
    IF OBJECT_ID('__sstr_schema.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE __sstr_schema.__sstr_test_tbl;
    EXEC('CREATE TABLE __sstr_schema.__sstr_test_tbl (Id int)');

    DECLARE @result bit = $(SchemaName).table_exists('__sstr_schema.__sstr_test_tbl');
    EXEC Assert.Equals @result, 1;

    DROP TABLE __sstr_schema.__sstr_test_tbl;
END
GO

-- 5. Local temp table
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_1_for_local_temp_table
AS
BEGIN
    IF OBJECT_ID('tempdb..#__sstr_tmp', 'U') IS NOT NULL DROP TABLE #__sstr_tmp;
    CREATE TABLE #__sstr_tmp (Id int);

    DECLARE @result bit = $(SchemaName).table_exists('#__sstr_tmp');
    EXEC Assert.Equals @result, 1;

    DROP TABLE #__sstr_tmp;
END
GO

-- 6. Global temp table
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_1_for_global_temp_table
AS
BEGIN
    IF OBJECT_ID('tempdb..##__sstr_gtmp', 'U') IS NOT NULL DROP TABLE ##__sstr_gtmp;
    CREATE TABLE ##__sstr_gtmp (Id int);

    DECLARE @result bit = $(SchemaName).table_exists('##__sstr_gtmp');
    EXEC Assert.Equals @result, 1;

    DROP TABLE ##__sstr_gtmp;
END
GO

-- 7. Quoted name with dot inside
CREATE OR ALTER PROCEDURE sstr.table_exists_should_handle_quote_name_with_dot
AS
BEGIN
    IF SCHEMA_ID('__sstr_schema') IS NULL EXEC('CREATE SCHEMA __sstr_schema');
    IF OBJECT_ID('__sstr_schema.[__sstr.dotted.tbl]', 'U') IS NOT NULL
        DROP TABLE __sstr_schema.[__sstr.dotted.tbl];
    EXEC('CREATE TABLE __sstr_schema.[__sstr.dotted.tbl] (Id int)');

    DECLARE @result bit = $(SchemaName).table_exists('[__sstr_schema].[__sstr.dotted.tbl]');
    EXEC Assert.Equals @result, 1;

    DROP TABLE __sstr_schema.[__sstr.dotted.tbl];
END
GO

-- 8. NULL input
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_0_for_null_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).table_exists(NULL);
    EXEC Assert.Equals @result, 0;
END
GO

-- 9. Empty input
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_0_for_empty_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).table_exists('');
    EXEC Assert.Equals @result, 0;
END
GO

-- 10. Whitespace-only input
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_0_for_whitespace_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).table_exists('   ');
    EXEC Assert.Equals @result, 0;
END
GO

-- 11. Leading/trailing whitespace is trimmed
CREATE OR ALTER PROCEDURE sstr.table_exists_should_trim_whitespace
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE dbo.__sstr_test_tbl;
    CREATE TABLE dbo.__sstr_test_tbl (Id int);

    DECLARE @result bit = $(SchemaName).table_exists('  dbo.__sstr_test_tbl  ');
    EXEC Assert.Equals @result, 1;

    DROP TABLE dbo.__sstr_test_tbl;
END
GO

-- 12. A view is not a table
CREATE OR ALTER PROCEDURE sstr.table_exists_should_return_0_for_view
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_view', 'V') IS NOT NULL DROP VIEW dbo.__sstr_test_view;
    EXEC('CREATE VIEW dbo.__sstr_test_view AS SELECT 1 AS Id');

    DECLARE @result bit = $(SchemaName).table_exists('dbo.__sstr_test_view');
    EXEC Assert.Equals @result, 0;

    DROP VIEW dbo.__sstr_test_view;
END
GO