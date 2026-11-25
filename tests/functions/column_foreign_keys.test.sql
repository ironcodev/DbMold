set ansi_nulls on
go

set quoted_identifier on
go
-- =============================================
-- Tests for $(SchemaName).column_foreign_keys
-- =============================================

CREATE OR ALTER PROCEDURE dbo.column_foreign_keys_setup
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cfk_child', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_child;
    IF OBJECT_ID('dbo.__sstr_cfk_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_tbl;

    CREATE TABLE dbo.__sstr_cfk_tbl
    (
        Id int NOT NULL IDENTITY(1,1) CONSTRAINT PK_gci_tbl PRIMARY KEY,
        Name nvarchar(100) NOT NULL DEFAULT (N'unknown'),
        Price decimal(18,2) NULL,
        ComputedCol AS (Price * 2),
        SparseCol int SPARSE NULL,
        Code char(4) NOT NULL
    );

    -- composite unique key, so a column can be a non-PK unique column
    ALTER TABLE dbo.__sstr_cfk_tbl
        ADD CONSTRAINT UQ_gci_tbl_code UNIQUE (Code);

    -- child table with two single-column FKs and one composite FK
    CREATE TABLE dbo.__sstr_cfk_child
    (
        ChildId  int NOT NULL CONSTRAINT PK_gci_child PRIMARY KEY,
        ParentId int NULL CONSTRAINT FK_gci_child_tbl_id
                       FOREIGN KEY REFERENCES dbo.__sstr_cfk_tbl(Id) ON DELETE CASCADE,
        Code     char(4) NULL CONSTRAINT FK_gci_child_tbl_code
                       FOREIGN KEY REFERENCES dbo.__sstr_cfk_tbl(Code) ON DELETE NO ACTION ON UPDATE SET NULL,
        Price    decimal(18,2) NULL
    );

    EXEC sp_addextendedproperty
        @name = N'MS_Description',
        @value = N'Identifier of the row',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'__sstr_cfk_tbl',
        @level2type = N'COLUMN', @level2name = N'Id';

    IF OBJECT_ID('dbo.__sstr_cfk_multi_fk', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_multi_fk;
    IF OBJECT_ID('dbo.__sstr_cfk_parent_a', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_parent_a;
    IF OBJECT_ID('dbo.__sstr_cfk_parent_b', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_parent_b;

    CREATE TABLE dbo.__sstr_cfk_parent_a
    (
        Id int NOT NULL CONSTRAINT PK_gci_parent_a PRIMARY KEY
    );

    CREATE TABLE dbo.__sstr_cfk_parent_b
    (
        Id int NOT NULL CONSTRAINT PK_gci_parent_b PRIMARY KEY
    );

    CREATE TABLE dbo.__sstr_cfk_multi_fk
    (
        RefId int NULL
            CONSTRAINT FK_gci_multi_fk_a FOREIGN KEY REFERENCES dbo.__sstr_cfk_parent_a(Id),
            CONSTRAINT FK_gci_multi_fk_b FOREIGN KEY (RefId) REFERENCES dbo.__sstr_cfk_parent_b(Id)
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.column_foreign_keys_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cfk_child', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_child;
    IF OBJECT_ID('dbo.__sstr_cfk_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_tbl;
    
    IF OBJECT_ID('dbo.__sstr_cfk_multi_fk', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_multi_fk;
    IF OBJECT_ID('dbo.__sstr_cfk_parent_a', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_parent_a;
    IF OBJECT_ID('dbo.__sstr_cfk_parent_b', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_parent_b;
END
GO

-- 19. FK column reports the FK constraint name.
CREATE OR ALTER PROCEDURE sstr.column_foreign_keys_fk_column_reports_constraint
AS
BEGIN
    EXEC dbo.column_foreign_keys_setup;

    DECLARE @info table
    (
        direction varchar(8),
        constraint_name nvarchar(500),
        child_schema sysname,
        child_table sysname,
        child_column sysname,
        parent_schema sysname,
        parent_table sysname,
        parent_column sysname,
        constraint_column_id int,
        is_disabled bit,
        is_not_trusted bit,
        delete_rule nvarchar(60),
        update_rule nvarchar(60)
    )
    
    INSERT INTO @info
    SELECT
        direction,
        constraint_name,
        child_schema,
        child_table,
        child_column,
        parent_schema,
        parent_table,
        parent_column,
        constraint_column_id,
        is_disabled,
        is_not_trusted,
        delete_rule,
        update_rule
    FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_cfk_child.ParentId');

    EXEC Assert.Equals @fk_name, N'FK_gci_child_tbl_id';

    EXEC dbo.column_foreign_keys_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_foreign_keys_multi_fk_column_returns_two_rows
AS
BEGIN
    EXEC dbo.column_foreign_keys_setup;

    DECLARE @count int, @distinct_parents int, @distinct_fks int;

    SELECT
        @count             = COUNT(*),
        @distinct_parents  = COUNT(DISTINCT parent_column),
        @distinct_fks      = COUNT(DISTINCT foreign_key_constraint)
    FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_cfk_multi_fk.RefId');

    -- two FKs on the same column -> two rows
    EXEC Assert.Equals @count,            2;
    -- each row names a different parent column
    EXEC Assert.Equals @distinct_parents, 2;
    -- each row names a different FK constraint
    EXEC Assert.Equals @distinct_fks,     2;

    -- both parent columns are present, in either order
    DECLARE @has_a bit = CASE WHEN EXISTS (
        SELECT 1 FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_cfk_multi_fk.RefId')
        WHERE parent_column = N'[dbo].[__sstr_cfk_parent_a].[Id]'
          AND foreign_key_constraint = N'FK_gci_multi_fk_a'
    ) THEN 1 ELSE 0 END;

    DECLARE @has_b bit = CASE WHEN EXISTS (
        SELECT 1 FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_cfk_multi_fk.RefId')
        WHERE parent_column = N'[dbo].[__sstr_cfk_parent_b].[Id]'
          AND foreign_key_constraint = N'FK_gci_multi_fk_b'
    ) THEN 1 ELSE 0 END;

    EXEC Assert.Equals @has_a, 1;
    EXEC Assert.Equals @has_b, 1;

    EXEC dbo.column_foreign_keys_teardown;
END
GO
