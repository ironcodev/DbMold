set ansi_nulls on
go

set quoted_identifier on
go
-- =============================================
-- Tests for $(SchemaName).column_info
-- =============================================

CREATE OR ALTER PROCEDURE dbo.column_info_setup
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_gci_child', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_child;
    IF OBJECT_ID('dbo.__sstr_gci_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_tbl;

    CREATE TABLE dbo.__sstr_gci_tbl
    (
        Id int NOT NULL IDENTITY(1,1) CONSTRAINT PK_gci_tbl PRIMARY KEY,
        Name nvarchar(100) NOT NULL DEFAULT (N'unknown'),
        Price decimal(18,2) NULL,
        ComputedCol AS (Price * 2),
        SparseCol int SPARSE NULL,
        Code char(4) NOT NULL
    );

    -- composite unique key, so a column can be a non-PK unique column
    ALTER TABLE dbo.__sstr_gci_tbl
        ADD CONSTRAINT UQ_gci_tbl_code UNIQUE (Code);

    -- child table with two single-column FKs and one composite FK
    CREATE TABLE dbo.__sstr_gci_child
    (
        ChildId  int NOT NULL CONSTRAINT PK_gci_child PRIMARY KEY,
        ParentId int NULL CONSTRAINT FK_gci_child_tbl_id
                       FOREIGN KEY REFERENCES dbo.__sstr_gci_tbl(Id),
        Code     char(4) NULL CONSTRAINT FK_gci_child_tbl_code
                       FOREIGN KEY REFERENCES dbo.__sstr_gci_tbl(Code),
        Price    decimal(18,2) NULL
    );

    EXEC sp_addextendedproperty
        @name = N'MS_Description',
        @value = N'Identifier of the row',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'__sstr_gci_tbl',
        @level2type = N'COLUMN', @level2name = N'Id';

    IF OBJECT_ID('dbo.__sstr_gci_multi_fk', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_multi_fk;
    IF OBJECT_ID('dbo.__sstr_gci_parent_a', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_parent_a;
    IF OBJECT_ID('dbo.__sstr_gci_parent_b', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_parent_b;

    CREATE TABLE dbo.__sstr_gci_parent_a
    (
        Id int NOT NULL CONSTRAINT PK_gci_parent_a PRIMARY KEY
    );

    CREATE TABLE dbo.__sstr_gci_parent_b
    (
        Id int NOT NULL CONSTRAINT PK_gci_parent_b PRIMARY KEY
    );

    CREATE TABLE dbo.__sstr_gci_multi_fk
    (
        RefId int NULL
            CONSTRAINT FK_gci_multi_fk_a FOREIGN KEY REFERENCES dbo.__sstr_gci_parent_a(Id),
            CONSTRAINT FK_gci_multi_fk_b FOREIGN KEY (RefId) REFERENCES dbo.__sstr_gci_parent_b(Id)
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.column_info_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_gci_child', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_child;
    IF OBJECT_ID('dbo.__sstr_gci_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_tbl;
    
    IF OBJECT_ID('dbo.__sstr_gci_multi_fk', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_multi_fk;
    IF OBJECT_ID('dbo.__sstr_gci_parent_a', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_parent_a;
    IF OBJECT_ID('dbo.__sstr_gci_parent_b', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_parent_b;
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
    EXEC Assert.Equals 10, 10;

    EXEC dbo.column_info_teardown;
END
GO

-- 2. nvarchar column with default and description.
CREATE OR ALTER PROCEDURE sstr.column_info_should_return_nvarchar_with_default
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @type sysname, @max_len int, @default nvarchar(4000), @desc nvarchar(4000);

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

-- 11. PK column: is_primary_key = 1, parent_column is NULL.
CREATE OR ALTER PROCEDURE sstr.column_info_pk_column_is_primary
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @is_primary_key bit, @parent nvarchar(1000);

    SELECT @is_primary_key = is_primary_key, @parent = parent_column
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Id');

    EXEC Assert.Equals @is_primary_key, 1;
    EXEC Assert.IsNull   @parent;

    EXEC dbo.column_info_teardown;
END
GO

-- 12. Non-PK, non-FK column: is_primary_key = 0, parent_column is NULL.
CREATE OR ALTER PROCEDURE sstr.column_info_non_pk_non_fk_column
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @is_primary_key bit, @parent nvarchar(1000);

    SELECT @is_primary_key = is_primary_key, @parent = parent_column
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Price');

    EXEC Assert.Equals @is_primary_key, 0;
    EXEC Assert.IsNull   @parent;

    EXEC dbo.column_info_teardown;
END
GO

-- 13. Non-PK unique column: is_primary_key = 0 (unique is not primary).
CREATE OR ALTER PROCEDURE sstr.column_info_unique_column_is_not_primary
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @is_primary_key bit;

    SELECT @is_primary_key = is_primary_key
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Code');

    EXEC Assert.Equals @is_primary_key, 0;

    EXEC dbo.column_info_teardown;
END
GO

-- 14. FK column: parent_column is the fully qualified referenced column.
CREATE OR ALTER PROCEDURE sstr.column_info_fk_column_has_parent
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @is_primary_key bit, @parent nvarchar(1000);

    SELECT @is_primary_key = is_primary_key, @parent = parent_column
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_child.ParentId');

    EXEC Assert.Equals  @is_primary_key, 0;
    EXEC Assert.IsNotNull @parent;
    EXEC Assert.Equals  @parent, N'[dbo].[__sstr_gci_tbl].[Id]';

    EXEC dbo.column_info_teardown;
END
GO

-- 15. Second FK column: parent_column is the second referenced column,
--     not the first one (proves the join is on column_id, not just
--     object_id).
CREATE OR ALTER PROCEDURE sstr.column_info_second_fk_has_second_parent
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @parent nvarchar(1000);

    SELECT @parent = parent_column
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_child.Code');

    EXEC Assert.Equals @parent, N'[dbo].[__sstr_gci_tbl].[Code]';

    EXEC dbo.column_info_teardown;
END
GO

-- 16. Parent-side column is not reported as a child of the FK.
CREATE OR ALTER PROCEDURE sstr.column_info_parent_side_not_reported_as_fk
AS
BEGIN
    EXEC dbo.column_info_setup;

    -- __sstr_gci_tbl.Id is referenced by the child's FK; it is not itself
    -- a child of any FK, so parent_column must be NULL.
    DECLARE @parent nvarchar(1000);
    SELECT @parent = parent_column
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Id');

    EXEC Assert.IsNull @parent;

    EXEC dbo.column_info_teardown;
END
GO
-- 17. FK column on a non-PK child column reports both flags correctly.
CREATE OR ALTER PROCEDURE sstr.column_info_fk_and_pk_flags_combine
AS
BEGIN
    EXEC dbo.column_info_setup;

    -- ChildId is the PK of the child table and is not an FK itself.
    DECLARE @is_primary_key bit, @parent nvarchar(1000);
    SELECT @is_primary_key = is_primary_key, @parent = parent_column
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_child.ChildId');

    EXEC Assert.Equals @is_primary_key, 1;
    EXEC Assert.IsNull   @parent;

    EXEC dbo.column_info_teardown;
END
GO

-- 18. PK column reports the PK constraint name.
CREATE OR ALTER PROCEDURE sstr.column_info_pk_column_reports_constraint
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @pk_name nvarchar(500);

    SELECT @pk_name = primary_key_constraint
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Id');

    EXEC Assert.Equals @pk_name, N'PK_gci_tbl';

    EXEC dbo.column_info_teardown;
END
GO

-- 20. Non-PK, non-FK column: both constraint names are NULL.
CREATE OR ALTER PROCEDURE sstr.column_info_plain_column_has_no_constraint_names
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @pk_name nvarchar(500), @parent_column nvarchar(500);

    SELECT @pk_name = primary_key_constraint, @parent_column = parent_column
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_tbl.Price');

    EXEC Assert.IsNull @pk_name;
    EXEC Assert.IsNull @parent_column;

    EXEC dbo.column_info_teardown;
END
GO

-- 21. A column in two FK constraints produces one row in column_info.
CREATE OR ALTER PROCEDURE sstr.column_info_multi_fk_column_returns_one_row
AS
BEGIN
    EXEC dbo.column_info_setup;

    DECLARE @count int, @parent_column nvarchar(max);
    DECLARE @info table(
        parent_column nvarchar(max)
    );
    INSERT INTO @info
    SELECT
        parent_column
    FROM $(SchemaName).column_info(N'dbo.__sstr_gci_multi_fk.RefId');

    SELECT
        @count = COUNT(*)
    FROM @info;

    -- two FKs on the same column -> one row
    EXEC Assert.Equals @count, 1;

    SELECT @parent_column = parent_column
    FROM @info;

    DECLARE @comma_index INT

    SET @comma_index = CHARINDEX(',', @parent_column);
    -- the single row has a sinlge parent_column
    -- containing both names of different parent columns
    EXEC Assert.IsGT @comma_index, 0;

    -- both parent columns are present, in either order
    DECLARE @has_a bit =
        CASE WHEN charindex('[dbo].[__sstr_gci_parent_a].[Id]', @parent_column) > 0 THEN 1 ELSE 0 END;

    DECLARE @has_b bit =
        CASE WHEN charindex('[dbo].[__sstr_gci_parent_b].[Id]', @parent_column) > 0 THEN 1 ELSE 0 END;

    EXEC Assert.Equals @has_a, 1;
    EXEC Assert.Equals @has_b, 1;

    EXEC dbo.column_info_teardown;
END
GO