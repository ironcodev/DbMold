-- =============================================
-- Tests for $(SchemaName).table_info
-- =============================================

CREATE OR ALTER PROCEDURE dbo.table_info_setup
AS
BEGIN
    -- Drop tables from previous runs.
    IF OBJECT_ID('dbo.__sstr_ti_tbl1', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_ti_tbl1;

    CREATE TABLE dbo.__sstr_ti_tbl1
    (
        Id int NOT NULL PRIMARY KEY,
        Name nvarchar(50) NULL
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.table_info_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_ti_tbl1', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_ti_tbl1;
END
GO

-- 1. A superset of a composite primary key does not match.
CREATE OR ALTER PROCEDURE sstr.table_info_should_return_2_for_two_column_tbl
AS
BEGIN
    EXEC dbo.table_info_setup;

    DECLARE @count INT;

    SET @count = (SELECT count(*) FROM $(SchemaName).table_info('dbo.__sstr_ti_tbl1'));

    EXEC Assert.Equals @count, 2;

    EXEC dbo.table_info_teardown;
END
GO
