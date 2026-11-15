-- =============================================
-- Tests for $(SchemaName)._parse_column_list
-- =============================================

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_parse_single_column
AS
BEGIN
    DECLARE @schema sysname, @table sysname, @column sysname, @ord int;

    SELECT @schema = schema_name, @table = table_name,
           @column = column_name, @ord = ord
    FROM $(SchemaName)._parse_column_list(N'dbo.Child.Col1');

    EXEC Assert.Equals @schema, 'dbo';
    EXEC Assert.Equals @table,  'Child';
    EXEC Assert.Equals @column, 'Col1';
    EXEC Assert.Equals @ord,    1;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_parse_composite_key
AS
BEGIN
    DECLARE @count int = (SELECT COUNT(*) FROM $(SchemaName)._parse_column_list(N'dbo.Child.(Col1,Col2,Col3)'));
    EXEC Assert.Equals @count, 3;

    DECLARE @col1 sysname = (SELECT column_name FROM $(SchemaName)._parse_column_list(N'dbo.Child.(Col1,Col2,Col3)') WHERE ord = 1);
    DECLARE @col2 sysname = (SELECT column_name FROM $(SchemaName)._parse_column_list(N'dbo.Child.(Col1,Col2,Col3)') WHERE ord = 2);
    DECLARE @col3 sysname = (SELECT column_name FROM $(SchemaName)._parse_column_list(N'dbo.Child.(Col1,Col2,Col3)') WHERE ord = 3);

    EXEC Assert.Equals @col1, 'Col1';
    EXEC Assert.Equals @col2, 'Col2';
    EXEC Assert.Equals @col3, 'Col3';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_default_schema_to_dbo
AS
BEGIN
    DECLARE @schema sysname = (SELECT schema_name FROM $(SchemaName)._parse_column_list(N'Child.Col1'));
    EXEC Assert.Equals @schema, 'dbo';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_list_should_handle_quoted_table
AS
BEGIN
    DECLARE @schema sysname, @table sysname, @column sysname;

    SELECT @schema = schema_name, @table = table_name, @column = column_name
    FROM $(SchemaName)._parse_column_list(N'[sales].[My.Table].(Col1,Col2)')
    WHERE ord = 1;

    EXEC Assert.Equals @schema, 'sales';
    EXEC Assert.Equals @table,  'My.Table';
    EXEC Assert.Equals @column, 'Col1';
END
GO