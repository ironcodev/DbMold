-- =============================================
-- Tests for $(SchemaName).primary_key_exists
-- =============================================

CREATE OR ALTER PROCEDURE dbo.primary_key_exists_setup
AS
BEGIN
    -- Drop tables from previous runs.
    IF OBJECT_ID('dbo.__sstr_pk_single', 'U') IS NOT NULL DROP TABLE dbo.__sstr_pk_single;
    IF OBJECT_ID('dbo.__sstr_pk_composite', 'U') IS NOT NULL DROP TABLE dbo.__sstr_pk_composite;
    IF OBJECT_ID('dbo.__sstr_pk_no_pk', 'U') IS NOT NULL DROP TABLE dbo.__sstr_pk_no_pk;

    CREATE TABLE dbo.__sstr_pk_single
    (
        Id int NOT NULL PRIMARY KEY,
        Name nvarchar(50) NULL
    );

    CREATE TABLE dbo.__sstr_pk_composite
    (
        UserId int NOT NULL,
        RoleId int NOT NULL,
        TenantId int NOT NULL,
        CONSTRAINT PK___sstr_pk_composite
            PRIMARY KEY (UserId, RoleId)
    );

    CREATE TABLE dbo.__sstr_pk_no_pk
    (
        Id int NOT NULL,
        Name nvarchar(50) NULL
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.primary_key_exists_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_pk_single', 'U') IS NOT NULL DROP TABLE dbo.__sstr_pk_single;
    IF OBJECT_ID('dbo.__sstr_pk_composite', 'U') IS NOT NULL DROP TABLE dbo.__sstr_pk_composite;
    IF OBJECT_ID('dbo.__sstr_pk_no_pk', 'U') IS NOT NULL DROP TABLE dbo.__sstr_pk_no_pk;
END
GO

-- 1. Single-column primary key exists.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_1_for_single_column_pk
AS
BEGIN
    EXEC dbo.primary_key_exists_setup;

    DECLARE @result bit = $(SchemaName).primary_key_exists(
        N'dbo.__sstr_pk_single.Id');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.primary_key_exists_teardown;
END
GO

-- 2. Primary key does not exist for a non-key column.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_0_for_wrong_column
AS
BEGIN
    EXEC dbo.primary_key_exists_setup;

    DECLARE @result bit = $(SchemaName).primary_key_exists(
        N'dbo.__sstr_pk_single.Name');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.primary_key_exists_teardown;
END
GO

-- 3. Missing table.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_0_for_missing_table
AS
BEGIN
    EXEC dbo.primary_key_exists_setup;

    DECLARE @result bit = $(SchemaName).primary_key_exists(
        N'dbo.__sstr_no_such_table.Id');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.primary_key_exists_teardown;
END
GO

-- 4. Table exists but has no primary key.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_0_for_table_without_pk
AS
BEGIN
    EXEC dbo.primary_key_exists_setup;

    DECLARE @result bit = $(SchemaName).primary_key_exists(
        N'dbo.__sstr_pk_no_pk.Id');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.primary_key_exists_teardown;
END
GO

-- 5. NULL input.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_0_for_null_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).primary_key_exists(NULL);
    EXEC Assert.Equals @result, 0;
END
GO

-- 6. Empty input.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_0_for_empty_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).primary_key_exists(N'');
    EXEC Assert.Equals @result, 0;
END
GO

-- 7. Composite primary key exists.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_1_for_composite_pk
AS
BEGIN
    EXEC dbo.primary_key_exists_setup;

    DECLARE @result bit = $(SchemaName).primary_key_exists(
        N'dbo.__sstr_pk_composite(UserId,RoleId)');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.primary_key_exists_teardown;
END
GO

-- 8. Composite primary key with reversed column order does not match.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_0_for_reversed_composite
AS
BEGIN
    EXEC dbo.primary_key_exists_setup;

    DECLARE @result bit = $(SchemaName).primary_key_exists(
        N'dbo.__sstr_pk_composite(RoleId,UserId)');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.primary_key_exists_teardown;
END
GO

-- 9. A subset of a composite primary key does not match.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_0_for_partial_composite_pk
AS
BEGIN
    EXEC dbo.primary_key_exists_setup;

    DECLARE @result bit = $(SchemaName).primary_key_exists(
        N'dbo.__sstr_pk_composite(UserId)');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.primary_key_exists_teardown;
END
GO

-- 10. A superset of a composite primary key does not match.
CREATE OR ALTER PROCEDURE sstr.primary_key_exists_should_return_0_for_extra_column
AS
BEGIN
    EXEC dbo.primary_key_exists_setup;

    DECLARE @result bit = $(SchemaName).primary_key_exists(
        N'dbo.__sstr_pk_composite(UserId,RoleId,TenantId)');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.primary_key_exists_teardown;
END
GO
