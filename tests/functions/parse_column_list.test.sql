-- =============================================
-- Tests for $(SchemaName).parse_column_list
-- =============================================

CREATE OR ALTER PROCEDURE dbo.parse_column_list_setup
AS
BEGIN
    -- Drop tables from previous runs.
    IF OBJECT_ID('dbo.__sstr_pcl_tbl1', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_pcl_tbl1;

    CREATE TABLE dbo.__sstr_pcl_tbl1
    (
        Id int NOT NULL PRIMARY KEY,
        Name nvarchar(50) NULL
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.parse_column_list_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_pcl_tbl1', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_pcl_tbl1;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_parse_single_column
AS
BEGIN
    DECLARE @schema sysname, @table sysname, @column sysname, @ord int;

    SELECT @schema = [schema], @table = [table],
           @column = [column], @ord = ord
    FROM $(SchemaName).parse_column_list(N'dbo.Child.Col1');

    EXEC Assert.Equals @schema, 'dbo';
    EXEC Assert.Equals @table,  'Child';
    EXEC Assert.Equals @column, 'Col1';
    EXEC Assert.Equals @ord,    1;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_parse_composite_key
AS
BEGIN
    DECLARE @count int = (SELECT COUNT(*) FROM $(SchemaName).parse_column_list(N'dbo.Child.(Col1,Col2,Col3)'));
    EXEC Assert.Equals @count, 3;

    DECLARE @col1 sysname = (SELECT [column] FROM $(SchemaName).parse_column_list(N'dbo.Child.(Col1,Col2,Col3)') WHERE ord = 1);
    DECLARE @col2 sysname = (SELECT [column] FROM $(SchemaName).parse_column_list(N'dbo.Child.(Col1,Col2,Col3)') WHERE ord = 2);
    DECLARE @col3 sysname = (SELECT [column] FROM $(SchemaName).parse_column_list(N'dbo.Child.(Col1,Col2,Col3)') WHERE ord = 3);

    EXEC Assert.Equals @col1, 'Col1';
    EXEC Assert.Equals @col2, 'Col2';
    EXEC Assert.Equals @col3, 'Col3';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_default_schema_to_dbo
AS
BEGIN
    DECLARE @schema sysname = (SELECT [schema] FROM $(SchemaName).parse_column_list(N'Child.Col1'));
    EXEC Assert.Equals @schema, 'dbo';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_handle_quoted_table
AS
BEGIN
    DECLARE @schema sysname, @table sysname, @column sysname;

    SELECT @schema = [schema], @table = [table], @column = [column]
    FROM $(SchemaName).parse_column_list(N'[sales].[My.Table].(Col1,Col2)')
    WHERE ord = 1;

    EXEC Assert.Equals @schema, 'sales';
    EXEC Assert.Equals @table,  'My.Table';
    EXEC Assert.Equals @column, 'Col1';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_return_correct_object_id
AS
BEGIN
    DECLARE @object_id int, @real_object_id int, @column sysname;

    SELECT @object_id = [object_id], @column = [column]
    FROM $(SchemaName).parse_column_list(N'[sales].[My.Table].Col1')

    EXEC Assert.Equals @column, 'Col1', 'dummy table column';
    EXEC Assert.IsNull @object_id, 'dummy table object_idcol';

    EXEC dbo.parse_column_list_setup

    SET @real_object_id = object_id('dbo.__sstr_pcl_tbl1')

    SELECT @object_id = [object_id], @column = [column]
    FROM $(SchemaName).parse_column_list(N'__sstr_pcl_tbl1.Col1')

    EXEC Assert.Equals @column, 'Col1', 'real table column';
    EXEC Assert.IsNotNull @object_id, 'real table object_id not null';
    EXEC Assert.Equals @object_id, @real_object_id, 'real table object_id';

    EXEC dbo.parse_column_list_teardown
END
GO