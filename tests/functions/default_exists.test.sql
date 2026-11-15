-- =============================================
-- Tests for $(SchemaName).default_exists
-- =============================================

CREATE OR ALTER PROCEDURE dbo.default_exists_setup
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_def_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_def_tbl;
    CREATE TABLE dbo.__sstr_def_tbl
    (
        Id int NOT NULL,
        WithDefault int NOT NULL DEFAULT (0),
        WithStringDefault nvarchar(50) NOT NULL DEFAULT (N'hello'),
        NoDefault int NULL
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.default_exists_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_def_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_def_tbl;
END
GO

-- 1. Column with default exists (presence only).
CREATE OR ALTER PROCEDURE sstr.default_exists_should_return_1_for_column_with_default
AS
BEGIN
    EXEC dbo.default_exists_setup;

    DECLARE @result bit = $(SchemaName).default_exists(N'dbo.__sstr_def_tbl.WithDefault', NULL);
    EXEC Assert.Equals @result, 1;

    EXEC dbo.default_exists_teardown;
END
GO

-- 2. Column without default.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_return_0_for_column_without_default
AS
BEGIN
    EXEC dbo.default_exists_setup;

    DECLARE @result bit = $(SchemaName).default_exists(N'dbo.__sstr_def_tbl.NoDefault', NULL);
    EXEC Assert.Equals @result, 0;

    EXEC dbo.default_exists_teardown;
END
GO

-- 3. Missing table.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_return_0_for_missing_table
AS
BEGIN
    DECLARE @result bit = $(SchemaName).default_exists(N'dbo.__sstr_no_such_table.Col', NULL);
    EXEC Assert.Equals @result, 0;
END
GO

-- 4. NULL input.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_return_0_for_null_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).default_exists(NULL, NULL);
    EXEC Assert.Equals @result, 0;
END
GO

-- 5. Empty input.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_return_0_for_empty_input
AS
BEGIN
    DECLARE @result bit = $(SchemaName).default_exists(N'', NULL);
    EXEC Assert.Equals @result, 0;
END
GO

-- 6. Value matches (normalized).
CREATE OR ALTER PROCEDURE sstr.default_exists_should_return_1_for_matching_value
AS
BEGIN
    EXEC dbo.default_exists_setup;

    DECLARE @result bit = $(SchemaName).default_exists(N'dbo.__sstr_def_tbl.WithDefault', N'0');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.default_exists_teardown;
END
GO

-- 7. Value matches with extra parens in expected.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_normalize_expected_value
AS
BEGIN
    EXEC dbo.default_exists_setup;

    DECLARE @result bit = $(SchemaName).default_exists(N'dbo.__sstr_def_tbl.WithDefault', N'((0))');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.default_exists_teardown;
END
GO

-- 8. Value does not match.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_return_0_for_non_matching_value
AS
BEGIN
    EXEC dbo.default_exists_setup;

    DECLARE @result bit = $(SchemaName).default_exists(N'dbo.__sstr_def_tbl.WithDefault', N'1');
    EXEC Assert.Equals @result, 0;

    EXEC dbo.default_exists_teardown;
END
GO

-- 9. String default matches.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_handle_string_default
AS
BEGIN
    EXEC dbo.default_exists_setup;

    DECLARE @result bit = $(SchemaName).default_exists(
        N'dbo.__sstr_def_tbl.WithStringDefault', N'N''hello''');
    EXEC Assert.Equals @result, 1;

    EXEC dbo.default_exists_teardown;
END
GO

-- 10. Unqualified table name.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_resolve_unqualified_table
AS
BEGIN
    EXEC dbo.default_exists_setup;

    DECLARE @result bit = $(SchemaName).default_exists(N'__sstr_def_tbl.WithDefault', NULL);
    EXEC Assert.Equals @result, 1;

    EXEC dbo.default_exists_teardown;
END
GO

-- 11. No dot in name.
CREATE OR ALTER PROCEDURE sstr.default_exists_should_return_0_for_name_without_dot
AS
BEGIN
    DECLARE @result bit = $(SchemaName).default_exists(N'__sstr_def_tbl', NULL);
    EXEC Assert.Equals @result, 0;
END
GO