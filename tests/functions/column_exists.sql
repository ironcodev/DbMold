-- =============================================
-- Tests for $(SchemaName).column_exists
-- =============================================

-- 1. Existing column, fully qualified
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_1_for_existing_column
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE dbo.__sstr_test_tbl;
    CREATE TABLE dbo.__sstr_test_tbl (Id int, Name nvarchar(100));

    DECLARE @result bit = $(SchemaName).column_exists('dbo.__sstr_test_tbl.Id');
    EXEC Assert.Equals @result, 1;

    DROP TABLE dbo.__sstr_test_tbl;
END
GO

-- 2. Unqualified table name resolves to dbo
CREATE OR ALTER PROCEDURE sstr.column_exists_should_resolve_unqualified_table_to_dbo
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE dbo.__sstr_test_tbl;
    CREATE TABLE dbo.__sstr_test_tbl (Id int);

    DECLARE @result bit = $(SchemaName).column_exists('__sstr_test_tbl.Id');
    EXEC Assert.Equals @result, 1;

    DROP TABLE dbo.__sstr_test_tbl;
END
GO

-- 3. Second column of the same table
CREATE OR ALTER PROCEDURE sstr.column_exists_should_find_second_column
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE dbo.__sstr_test_tbl;
    CREATE TABLE dbo.__sstr_test_tbl (Id int, Name nvarchar(100));

    DECLARE @result bit = $(SchemaName).column_exists('dbo.__sstr_test_tbl.Name');
    EXEC Assert.Equals @result, 1;

    DROP TABLE dbo.__sstr_test_tbl;
END
GO

-- 4. Missing column
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_missing_column
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE dbo.__sstr_test_tbl;
    CREATE TABLE dbo.__sstr_test_tbl (Id int);

    DECLARE @result bit = $(SchemaName).column_exists('dbo.__sstr_test_tbl.Missing');
    EXEC Assert.Equals @result, 0;

    DROP TABLE dbo.__sstr_test_tbl;
END
GO

-- 5. Custom schema
CREATE OR ALTER PROCEDURE sstr.column_exists_should_find_column_in_custom_schema
AS
BEGIN
    IF SCHEMA_ID('__sstr_schema') IS NULL EXEC('CREATE SCHEMA __sstr_schema');
    IF OBJECT_ID('__sstr_schema.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE __sstr_schema.__sstr_test_tbl;
    EXEC('CREATE TABLE __sstr_schema.__sstr_test_tbl (Id int, Code nvarchar(50))');

    DECLARE @result bit = $(SchemaName).column_exists('__sstr_schema.__sstr_test_tbl.Code');
    EXEC Assert.Equals @result, 1;

    DROP TABLE __sstr_schema.__sstr_test_tbl;
END
GO

-- 6. Custom schema, missing column
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_missing_column_in_custom_schema
AS
BEGIN
    IF SCHEMA_ID('__sstr_schema') IS NULL EXEC('CREATE SCHEMA __sstr_schema');
    IF OBJECT_ID('__sstr_schema.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE __sstr_schema.__sstr_test_tbl;
    EXEC('CREATE TABLE __sstr_schema.__sstr_test_tbl (Id int)');

    DECLARE @result bit = $(SchemaName).column_exists('__sstr_schema.__sstr_test_tbl.Missing');
    EXEC Assert.Equals @result, 0;

    DROP TABLE __sstr_schema.__sstr_test_tbl;
END
GO

-- 7. Local temp table is NOT supported by the UDF
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_local_temp_table
AS
BEGIN
    IF OBJECT_ID('tempdb..#__sstr_tmp', 'U') IS NOT NULL DROP TABLE #__sstr_tmp;
    CREATE TABLE #__sstr_tmp (Id int);

    DECLARE @result bit = $(SchemaName).column_exists('#__sstr_tmp.Id');
    EXEC Assert.Equals @result, 0;

    DROP TABLE #__sstr_tmp;
END
GO

-- 8. Global temp table is NOT supported by the UDF
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_global_temp_table
AS
BEGIN
    IF OBJECT_ID('tempdb..##__sstr_gtmp', 'U') IS NOT NULL DROP TABLE ##__sstr_gtmp;
    CREATE TABLE ##__sstr_gtmp (Id int);

    DECLARE @result bit = $(SchemaName).column_exists('##__sstr_gtmp.Id');
    EXEC Assert.Equals @result, 0;

    DROP TABLE ##__sstr_gtmp;
END
GO

-- 9. Quoted names
CREATE OR ALTER PROCEDURE sstr.column_exists_should_handle_quote_names
AS
BEGIN
    IF SCHEMA_ID('__sstr_schema') IS NULL EXEC('CREATE SCHEMA __sstr_schema');
    IF OBJECT_ID('__sstr_schema.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE __sstr_schema.__sstr_test_tbl;
    EXEC('CREATE TABLE __sstr_schema.__sstr_test_tbl (Id int, Code nvarchar(50))');

    DECLARE @result bit = $(SchemaName).column_exists('[__sstr_schema].[__sstr_test_tbl].[Code]');
    EXEC Assert.Equals @result, 1;

    DROP TABLE __sstr_schema.__sstr_test_tbl;
END
GO

-- 10. NULL input
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_null_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).column_exists(NULL);
    EXEC Assert.Equals @result, 0;
END
GO

-- 11. Empty input
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_empty_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).column_exists('');
    EXEC Assert.Equals @result, 0;
END
GO

-- 12. Whitespace-only input
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_whitespace_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).column_exists('   ');
    EXEC Assert.Equals @result, 0;
END
GO

-- 13. No dot (cannot identify column)
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_name_without_dot
AS
BEGIN
    DECLARE @result bit = $(SchemaName).column_exists('__sstr_test_tbl');
    EXEC Assert.Equals @result, 0;
END
GO

-- 14. Object does not exist
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_missing_table
AS
BEGIN
    DECLARE @result bit = $(SchemaName).column_exists('dbo.__sstr_no_such_table_xyz.Id');
    EXEC Assert.Equals @result, 0;
END
GO

-- 15. A view is not a table
CREATE OR ALTER PROCEDURE sstr.column_exists_should_return_0_for_view
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_view', 'V') IS NOT NULL DROP VIEW dbo.__sstr_test_view;
    EXEC('CREATE VIEW dbo.__sstr_test_view AS SELECT 1 AS Id');

    DECLARE @result bit = $(SchemaName).column_exists('dbo.__sstr_test_view.Id');
    EXEC Assert.Equals @result, 0;

    DROP VIEW dbo.__sstr_test_view;
END
GO

-- 16. Leading/trailing whitespace is trimmed
CREATE OR ALTER PROCEDURE sstr.column_exists_should_trim_whitespace
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_test_tbl', 'U') IS NOT NULL DROP TABLE dbo.__sstr_test_tbl;
    CREATE TABLE dbo.__sstr_test_tbl (Id int);

    DECLARE @result bit = $(SchemaName).column_exists('  dbo.__sstr_test_tbl.Id  ');
    EXEC Assert.Equals @result, 1;

    DROP TABLE dbo.__sstr_test_tbl;
END
GO

-- 17. Table name contains a quoted dot (split by LAST dot)
CREATE OR ALTER PROCEDURE sstr.column_exists_should_split_by_last_dot
AS
BEGIN
    IF SCHEMA_ID('__sstr_schema') IS NULL EXEC('CREATE SCHEMA __sstr_schema');
    IF OBJECT_ID('__sstr_schema.[__sstr.dotted.tbl]', 'U') IS NOT NULL
        DROP TABLE __sstr_schema.[__sstr.dotted.tbl];
    EXEC('CREATE TABLE __sstr_schema.[__sstr.dotted.tbl] (Id int)');

    DECLARE @result bit = $(SchemaName).column_exists('[__sstr_schema].[__sstr.dotted.tbl].[Id]');
    EXEC Assert.Equals @result, 1;

    DROP TABLE __sstr_schema.[__sstr.dotted.tbl];
END
GO