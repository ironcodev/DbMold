-- =============================================
-- Tests for $(SchemaName).create_default
-- =============================================

CREATE OR ALTER PROCEDURE dbo.create_default_setup
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cd_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cd_tbl;
    CREATE TABLE dbo.__sstr_cd_tbl
    (
        Id int NOT NULL,
        NoDefault int NULL,
        WithDefault int NOT NULL DEFAULT (0)
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.create_default_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cd_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cd_tbl;
END
GO

-- 1. Create a default on a column that has none.
CREATE OR ALTER PROCEDURE sstr.create_default_should_add_default_when_none
AS
BEGIN
    EXEC dbo.create_default_setup;

    EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoDefault', '42';

    DECLARE @result bit = $(SchemaName).default_exists(N'dbo.__sstr_cd_tbl.NoDefault', N'42');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.create_default_teardown;
END
GO

-- 2. Idempotent.
CREATE OR ALTER PROCEDURE sstr.create_default_should_be_idempotent
AS
BEGIN
    EXEC dbo.create_default_setup;

    EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoDefault', '42';
    EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoDefault', '42';

    DECLARE @count int =
        (SELECT COUNT(*) FROM sys.default_constraints dc
         JOIN sys.columns c
           ON c.object_id = dc.parent_object_id
          AND c.column_id = dc.parent_column_id
         WHERE dc.parent_object_id = OBJECT_ID('dbo.__sstr_cd_tbl')
           AND c.name = N'NoDefault');

    EXEC Assert.Equals @count, 1;

    EXEC dbo.create_default_teardown;
END
GO

-- 3. Sync to new value.
CREATE OR ALTER PROCEDURE sstr.create_default_should_sync_to_new_value
AS
BEGIN
    EXEC dbo.create_default_setup;

    EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoDefault', '42';
    EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoDefault', '43';

    DECLARE @new_val bit = $(SchemaName).default_exists(N'dbo.__sstr_cd_tbl.NoDefault', N'43');
    EXEC Assert.Equals @new_val, 1;

    DECLARE @old_gone bit = $(SchemaName).default_exists(N'dbo.__sstr_cd_tbl.NoDefault', N'42');
    EXEC Assert.Equals @old_gone, 0;

    EXEC dbo.create_default_teardown;
END
GO

-- 4. Replace an existing default.
CREATE OR ALTER PROCEDURE sstr.create_default_should_replace_existing_default
AS
BEGIN
    EXEC dbo.create_default_setup;

    EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.WithDefault', '99';

    DECLARE @new_val bit = $(SchemaName).default_exists(N'dbo.__sstr_cd_tbl.WithDefault', N'99');
    EXEC Assert.Equals @new_val, 1;

    DECLARE @old_gone bit = $(SchemaName).default_exists(N'dbo.__sstr_cd_tbl.WithDefault', N'0');
    EXEC Assert.Equals @old_gone, 0;

    EXEC dbo.create_default_teardown;
END
GO

-- 5. Custom constraint name.
CREATE OR ALTER PROCEDURE sstr.create_default_should_honor_custom_name
AS
BEGIN
    EXEC dbo.create_default_setup;

    EXEC $(SchemaName).create_default
        N'dbo.__sstr_cd_tbl.NoDefault', '42', N'DF_Custom_NoDefault';

    DECLARE @count int =
        (SELECT COUNT(*) FROM sys.default_constraints
         WHERE name = N'DF_Custom_NoDefault'
           AND parent_object_id = OBJECT_ID('dbo.__sstr_cd_tbl'));

    EXEC Assert.Equals @count, 1;

    EXEC dbo.create_default_teardown;
END
GO

-- 6. Default constraint name is DF_<table>_<column> when @name is NULL.
CREATE OR ALTER PROCEDURE sstr.create_default_should_use_default_name
AS
BEGIN
    EXEC dbo.create_default_setup;

    EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoDefault', '42';

    DECLARE @count int =
        (SELECT COUNT(*) FROM sys.default_constraints
         WHERE name = N'DF___sstr_cd_tbl_NoDefault'
           AND parent_object_id = OBJECT_ID('dbo.__sstr_cd_tbl'));

    EXEC Assert.Equals @count, 1;

    EXEC dbo.create_default_teardown;
END
GO

-- 7. Missing table -> error.
CREATE OR ALTER PROCEDURE sstr.create_default_should_error_for_missing_table
AS
BEGIN
    DECLARE @caught bit = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_default N'dbo.__sstr_no_such_table.Col', '0';
    END TRY
    BEGIN CATCH
        SET @caught = 1;
    END CATCH
    EXEC Assert.Equals @caught, 1;
END
GO

-- 8. Missing column -> error.
CREATE OR ALTER PROCEDURE sstr.create_default_should_error_for_missing_column
AS
BEGIN
    EXEC dbo.create_default_setup;

    DECLARE @caught bit = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoSuchColumn', '0';
    END TRY
    BEGIN CATCH
        SET @caught = 1;
    END CATCH
    EXEC Assert.Equals @caught, 1;

    EXEC dbo.create_default_teardown;
END
GO

-- 9. NULL column -> error.
CREATE OR ALTER PROCEDURE sstr.create_default_should_error_for_null_column
AS
BEGIN
    DECLARE @caught bit = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_default NULL, '0';
    END TRY
    BEGIN CATCH
        SET @caught = 1;
    END CATCH
    EXEC Assert.Equals @caught, 1;
END
GO

-- 10. NULL value -> error.
CREATE OR ALTER PROCEDURE sstr.create_default_should_error_for_null_value
AS
BEGIN
    EXEC dbo.create_default_setup;

    DECLARE @caught bit = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoDefault', NULL;
    END TRY
    BEGIN CATCH
        SET @caught = 1;
    END CATCH
    EXEC Assert.Equals @caught, 1;

    EXEC dbo.create_default_teardown;
END
GO

-- 11. String default.
CREATE OR ALTER PROCEDURE sstr.create_default_should_handle_string_default
AS
BEGIN
    EXEC dbo.create_default_setup;

    EXEC $(SchemaName).create_default N'dbo.__sstr_cd_tbl.NoDefault', N'N''hello''';

    DECLARE @result bit = $(SchemaName).default_exists(N'dbo.__sstr_cd_tbl.NoDefault', N'N''hello''');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.create_default_teardown;
END
GO