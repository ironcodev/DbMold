-- =============================================
-- Tests for $(SchemaName).foreign_key_exists
-- =============================================

CREATE OR ALTER PROCEDURE dbo.foreign_key_exists_setup
AS
BEGIN
    -- Drop in dependency order.
    IF OBJECT_ID('dbo.__sstr_fk_child', 'U') IS NOT NULL DROP TABLE dbo.__sstr_fk_child;
    IF OBJECT_ID('dbo.__sstr_fk_parent', 'U') IS NOT NULL DROP TABLE dbo.__sstr_fk_parent;
    IF OBJECT_ID('dbo.__sstr_fk_child2', 'U') IS NOT NULL DROP TABLE dbo.__sstr_fk_child2;
    IF OBJECT_ID('dbo.__sstr_fk_parent2', 'U') IS NOT NULL DROP TABLE dbo.__sstr_fk_parent2;

    CREATE TABLE dbo.__sstr_fk_parent
    (
        Id int NOT NULL PRIMARY KEY,
        Code nvarchar(50) NOT NULL
    );

    CREATE TABLE dbo.__sstr_fk_child
    (
        Id int NOT NULL PRIMARY KEY,
        ParentId int NULL,
        CONSTRAINT FK___sstr_fk_child_parent
            FOREIGN KEY (ParentId) REFERENCES dbo.__sstr_fk_parent (Id)
    );

    -- Composite parent.
    CREATE TABLE dbo.__sstr_fk_parent2
    (
        Col1 int NOT NULL,
        Col2 int NOT NULL,
        CONSTRAINT PK___sstr_fk_parent2 PRIMARY KEY (Col1, Col2)
    );

    CREATE TABLE dbo.__sstr_fk_child2
    (
        Id int NOT NULL PRIMARY KEY,
        Col1 int NULL,
        Col2 int NULL,
        CONSTRAINT FK___sstr_fk_child2_parent2
            FOREIGN KEY (Col1, Col2) REFERENCES dbo.__sstr_fk_parent2 (Col1, Col2)
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.foreign_key_exists_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_fk_child', 'U') IS NOT NULL DROP TABLE dbo.__sstr_fk_child;
    IF OBJECT_ID('dbo.__sstr_fk_parent', 'U') IS NOT NULL DROP TABLE dbo.__sstr_fk_parent;
    IF OBJECT_ID('dbo.__sstr_fk_child2', 'U') IS NOT NULL DROP TABLE dbo.__sstr_fk_child2;
    IF OBJECT_ID('dbo.__sstr_fk_parent2', 'U') IS NOT NULL DROP TABLE dbo.__sstr_fk_parent2;
END
GO

-- 1. Single-column FK exists.
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_1_for_single_column_fk
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_fk_child.ParentId',
        N'dbo.__sstr_fk_parent.Id');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.foreign_key_exists_teardown;
END
GO

-- 2. Single-column FK does not exist (wrong child column).
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_0_for_wrong_child_column
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_fk_child.Id',
        N'dbo.__sstr_fk_parent.Id');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.foreign_key_exists_teardown;
END
GO

-- 3. Single-column FK does not exist (wrong parent column).
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_0_for_wrong_parent_column
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_fk_child.ParentId',
        N'dbo.__sstr_fk_parent.Code');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.foreign_key_exists_teardown;
END
GO

-- 4. Missing child table.
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_0_for_missing_child_table
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_no_such_table.Col',
        N'dbo.__sstr_fk_parent.Id');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.foreign_key_exists_teardown;
END
GO

-- 5. Missing parent table.
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_0_for_missing_parent_table
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_fk_child.ParentId',
        N'dbo.__sstr_no_such_table.Id');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.foreign_key_exists_teardown;
END
GO

-- 6. NULL input.
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_0_for_null_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).foreign_key_exists(NULL, NULL);
    EXEC Assert.Equals @result, 0;
END
GO

-- 7. Empty input.
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_0_for_empty_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).foreign_key_exists(N'', N'');
    EXEC Assert.Equals @result, 0;
END
GO

-- 8. Composite FK exists.
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_1_for_composite_fk
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_fk_child2.(Col1,Col2)',
        N'dbo.__sstr_fk_parent2.(Col1,Col2)');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.foreign_key_exists_teardown;
END
GO

-- 9. Composite FK with reversed column order does not exist.
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_0_for_reversed_composite
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_fk_child2.(Col2,Col1)',
        N'dbo.__sstr_fk_parent2.(Col2,Col1)');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.foreign_key_exists_teardown;
END
GO

-- 10. Column count mismatch.
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_return_0_for_count_mismatch
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_fk_child2.(Col1)',
        N'dbo.__sstr_fk_parent2.(Col1,Col2)');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.foreign_key_exists_teardown;
END
GO

-- 11. Single-column form for composite parent (no parens).
CREATE OR ALTER PROCEDURE sstr.foreign_key_exists_should_handle_single_column_form
AS
BEGIN
    EXEC dbo.foreign_key_exists_setup;

    DECLARE @result bit = $(SchemaName).foreign_key_exists(
        N'dbo.__sstr_fk_child.ParentId',
        N'dbo.__sstr_fk_parent.Id');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.foreign_key_exists_teardown;
END
GO