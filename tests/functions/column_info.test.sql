-- =============================================
-- Tests for $(SchemaName).column_info
-- =============================================

CREATE OR ALTER PROCEDURE dbo.column_info_setup
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_gci_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_tbl;

    CREATE TABLE dbo.__sstr_gci_tbl
    (
        Id int NOT NULL IDENTITY(1,1),
        Name nvarchar(100) NOT NULL DEFAULT (N'unknown'),
        Price decimal(18,2) NULL,
        ComputedCol AS (Price * 2),
        SparseCol int SPARSE NULL
    );

    EXEC sp_addextendedproperty
        @name = N'MS_Description',
        @value = N'Identifier of the row',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'__sstr_gci_tbl',
        @level2type = N'COLUMN', @level2name = N'Id';
END
GO

CREATE OR ALTER PROCEDURE dbo.column_info_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_gci_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_tbl;
END
GO

-- 1. Int column with identity.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_int_identity
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @row TABLE
    (
        type_name sysname,
        is_identity bit,
        is_nullable bit,
        [precision] tinyint,
        scale tinyint
    );

    INSERT INTO @row
    SELECT type_name, is_identity, is_nullable, [precision], scale
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Id');

    DECLARE @type sysname = (SELECT type_name FROM @row);
    DECLARE @ident bit = (SELECT is_identity FROM @row);
    DECLARE @null bit = (SELECT is_nullable FROM @row);
    DECLARE @prec int = (SELECT [precision] FROM @row);

    EXEC Assert.Equals @type, 'int';
    EXEC Assert.Equals @ident, 1;
    EXEC Assert.Equals @null, 0;
    EXEC Assert.Equals @prec, 10;

    EXEC dbo.column_info_teardown;
END
GO

-- 2. nvarchar column with default and description.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_nvarchar_with_default
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @type sysname, @max_len smallint, @default nvarchar(4000), @desc nvarchar(4000);

    SELECT
        @type = type_name,
        @max_len = max_length,
        @default = CAST(default_value AS nvarchar(4000)),
        @desc = CAST(column_description AS nvarchar(4000))
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Name');

    EXEC Assert.Equals @type, 'nvarchar';
    EXEC Assert.Equals @max_len, 200;   -- nvarchar(100) => max_length 200
    EXEC Assert.IsNotNull @default;
    EXEC Assert.IsNull @desc;          -- no description on this column

    EXEC dbo.column_info_teardown;
END
GO

-- 3. decimal column with precision/scale.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_decimal_precision_scale
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @type sysname, @prec tinyint, @scale tinyint;

    SELECT @type = type_name, @prec = [precision], @scale = scale
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Price');

    EXEC Assert.Equals @type, 'decimal';
    EXEC Assert.Equals @prec, 18;
    EXEC Assert.Equals @scale, 2;

    EXEC dbo.column_info_teardown;
END
GO

-- 4. Computed column.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_computed_definition
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @is_computed bit, @def nvarchar(4000);

    SELECT
        @is_computed = is_computed,
        @def = CAST(computed_definition AS nvarchar(4000))
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.ComputedCol');

    EXEC Assert.Equals @is_computed, 1;
    EXEC Assert.IsNotNull @def;

    EXEC dbo.column_info_teardown;
END
GO

-- 5. Sparse column.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_sparse
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @is_sparse bit;
    SELECT @is_sparse = is_sparse
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.SparseCol');

    EXEC Assert.Equals @is_sparse, 1;

    EXEC dbo.column_info_teardown;
END
GO

-- 6. Column description (extended property).
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_column_description
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @desc nvarchar(4000) =
        (SELECT CAST(column_description AS nvarchar(4000))
         FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Id'));

    EXEC Assert.Equals @desc, 'Identifier of the row';

    EXEC dbo.column_info_teardown;
END
GO

-- 7. Missing table -> empty result.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_empty_for_missing_table
AS
BEGIN
    DECLARE @count int =
        (SELECT COUNT(*) FROM $(SchemaName).column_info(N'dbo.__sstr_no_such_table.Col'));

    EXEC Assert.Equals @count, 0;
END
GO

-- 8. Missing column -> empty result.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_empty_for_missing_column
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @count int =
        (SELECT COUNT(*) FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.NoSuchColumn'));

    EXEC Assert.Equals @count, 0;

    EXEC dbo.column_info_teardown;
END
GO

-- 9. NULL input -> empty result.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_empty_for_null_input
AS
BEGIN
    DECLARE @count int =
        (SELECT COUNT(*) FROM $(SchemaName).column_info(NULL));

    EXEC Assert.Equals @count, 0;
END
GO

-- 10. Empty input -> empty result.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_empty_for_empty_input
AS
BEGIN
    DECLARE @count int =
        (SELECT COUNT(*) FROM $(SchemaName).column_info(N''));

    EXEC Assert.Equals @count, 0;
END
GO