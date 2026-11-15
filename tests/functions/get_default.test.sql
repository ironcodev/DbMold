-- =============================================
-- Tests for $(SchemaName).get_default
-- =============================================

CREATE OR ALTER PROCEDURE dbo.get_default_setup
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_gd_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gd_tbl;
    CREATE TABLE dbo.__sstr_gd_tbl
    (
        Id int NOT NULL,
        WithDefault int NOT NULL DEFAULT (0),
        WithStringDefault nvarchar(50) NOT NULL DEFAULT (N'hello'),
        NoDefault int NULL
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.get_default_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_gd_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gd_tbl;
END
GO

-- 1. Numeric default.
CREATE OR ALTER PROCEDURE sstr.get_default_should_return_numeric_default
AS
BEGIN
    EXEC dbo.get_default_setup;

    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(N'dbo.__sstr_gd_tbl.WithDefault') AS nvarchar(4000));
    EXEC Assert.IsNotNull @result;

    DECLARE @normalized nvarchar(4000) =
        $(SchemaName)._normalize_default(@result);
    EXEC Assert.Equals @normalized, '0';

    EXEC dbo.get_default_teardown;
END
GO

-- 2. String default.
CREATE OR ALTER PROCEDURE sstr.get_default_should_return_string_default
AS
BEGIN
    EXEC dbo.get_default_setup;

    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(N'dbo.__sstr_gd_tbl.WithStringDefault') AS nvarchar(4000));
    EXEC Assert.IsNotNull @result;

    DECLARE @normalized nvarchar(4000) =
        $(SchemaName)._normalize_default(@result);
    EXEC Assert.Equals @normalized, 'N''hello''';

    EXEC dbo.get_default_teardown;
END
GO

-- 3. No default.
CREATE OR ALTER PROCEDURE sstr.get_default_should_return_null_for_no_default
AS
BEGIN
    EXEC dbo.get_default_setup;

    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(N'dbo.__sstr_gd_tbl.NoDefault') AS nvarchar(4000));
    EXEC Assert.IsNull @result;

    EXEC dbo.get_default_teardown;
END
GO

-- 4. Missing table.
CREATE OR ALTER PROCEDURE sstr.get_default_should_return_null_for_missing_table
AS
BEGIN
    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(N'dbo.__sstr_no_such_table.Col') AS nvarchar(4000));
    EXEC Assert.IsNull @result;
END
GO

-- 5. Missing column.
CREATE OR ALTER PROCEDURE sstr.get_default_should_return_null_for_missing_column
AS
BEGIN
    EXEC dbo.get_default_setup;

    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(N'dbo.__sstr_gd_tbl.NoSuchColumn') AS nvarchar(4000));
    EXEC Assert.IsNull @result;

    EXEC dbo.get_default_teardown;
END
GO

-- 6. NULL input.
CREATE OR ALTER PROCEDURE sstr.get_default_should_return_null_for_null_input
AS
BEGIN
    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(NULL) AS nvarchar(4000));
    EXEC Assert.IsNull @result;
END
GO

-- 7. Empty input.
CREATE OR ALTER PROCEDURE sstr.get_default_should_return_null_for_empty_input
AS
BEGIN
    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(N'') AS nvarchar(4000));
    EXEC Assert.IsNull @result;
END
GO

-- 8. Unqualified table name.
CREATE OR ALTER PROCEDURE sstr.get_default_should_resolve_unqualified_table
AS
BEGIN
    EXEC dbo.get_default_setup;

    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(N'__sstr_gd_tbl.WithDefault') AS nvarchar(4000));
    EXEC Assert.IsNotNull @result;

    EXEC dbo.get_default_teardown;
END
GO

-- 9. Name without dot.
CREATE OR ALTER PROCEDURE sstr.get_default_should_return_null_for_name_without_dot
AS
BEGIN
    DECLARE @result nvarchar(4000) =
        CAST($(SchemaName).get_default(N'__sstr_gd_tbl') AS nvarchar(4000));
    EXEC Assert.IsNull @result;
END
GO