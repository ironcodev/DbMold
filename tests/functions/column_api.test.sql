set ansi_nulls on
go

set quoted_identifier on
go
-- =============================================
-- Tests for column property functions
-- =============================================

CREATE OR ALTER PROCEDURE dbo.column_api_setup
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cp_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_tbl;
    
    CREATE TABLE dbo.__sstr_cp_tbl
    (
        Id int NOT NULL IDENTITY(1,1),
        Name nvarchar(100) NOT NULL,
        Code varchar(50) NULL,
        Price decimal(18,2) NULL,
        Description nvarchar(max) NULL,
        SparseCol int SPARSE NULL,
        XmlCol xml NULL,
        ComputedCol AS (Price * 2),
        GuidCol uniqueidentifier ROWGUIDCOL NOT NULL UNIQUE,
        Blob varbinary(max) FILESTREAM NULL
    );

    EXEC sp_addextendedproperty
        @name = N'MS_Description',
        @value = N'Identifier',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'__sstr_cp_tbl',
        @level2type = N'COLUMN', @level2name = N'Id';

    -- single fk constraint scneario
    IF OBJECT_ID('dbo.__sstr_cp_detail', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_detail;
    IF OBJECT_ID('dbo.__sstr_cp_master', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_master;

    CREATE TABLE dbo.__sstr_cp_master
    (
        Id int NOT NULL IDENTITY(1,1) PRIMARY KEY,
        Name nvarchar(100) NOT NULL DEFAULT (N'unknown')
    );

    CREATE TABLE dbo.__sstr_cp_detail
    (
        ChildId  int NOT NULL CONSTRAINT PK_gci_detail PRIMARY KEY,
        ParentId int NULL CONSTRAINT FK_gci_detail_ChildId
                        FOREIGN KEY REFERENCES dbo.__sstr_cp_master(Id)
    );

    -- multi fk scenario
    IF OBJECT_ID('dbo.__sstr_cp_parent_a', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_parent_a;
    IF OBJECT_ID('dbo.__sstr_cp_parent_b', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_parent_b;

    CREATE TABLE dbo.__sstr_cp_parent_a
    (
        Id int NOT NULL CONSTRAINT PK_gci_parent_a PRIMARY KEY
    );

    CREATE TABLE dbo.__sstr_cp_parent_b
    (
        Id int NOT NULL CONSTRAINT PK_gci_parent_b PRIMARY KEY
    );

    IF OBJECT_ID('dbo.__sstr_cp_multi_fk', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_multi_fk;

    CREATE TABLE dbo.__sstr_cp_multi_fk
    (
        RefId int NULL
            CONSTRAINT FK_gci_multi_fk_a FOREIGN KEY REFERENCES dbo.__sstr_cp_parent_a(Id),
        CONSTRAINT FK_gci_multi_fk_b FOREIGN KEY (RefId) REFERENCES dbo.__sstr_cp_parent_b(Id)
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.column_api_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cp_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_tbl;
    
    IF OBJECT_ID('dbo.__sstr_cp_detail', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_detail;
    IF OBJECT_ID('dbo.__sstr_cp_master', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_master;

    IF OBJECT_ID('dbo.__sstr_cp_multi_fk', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_multi_fk;
    IF OBJECT_ID('dbo.__sstr_cp_parent_a', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_parent_a;
    IF OBJECT_ID('dbo.__sstr_cp_parent_b', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_parent_b;
END
GO

-- =============================================
-- is_nullable
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_is_nullable_should_return_0_for_not_null
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_nullable(N'dbo.__sstr_cp_tbl.Id');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_is_nullable_should_return_1_for_nullable
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_nullable(N'dbo.__sstr_cp_tbl.Price');
    EXEC Assert.Equals @r, 1;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- is_identity
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_is_identity_should_return_1_for_identity
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_identity(N'dbo.__sstr_cp_tbl.Id');
    EXEC Assert.Equals @r, 1;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_is_identity_should_return_0_for_non_identity
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_identity(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- is_sparse
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_is_sparse_should_return_1_for_sparse
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_sparse(N'dbo.__sstr_cp_tbl.SparseCol');
    EXEC Assert.Equals @r, 1;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_is_sparse_should_return_0_for_non_sparse
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_sparse(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- is_computed
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_is_computed_should_return_1_for_computed
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_computed(N'dbo.__sstr_cp_tbl.ComputedCol');
    EXEC Assert.Equals @r, 1;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_is_computed_should_return_0_for_non_computed
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_computed(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- is_filestream
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_is_filestream_should_return_1_for_filestream
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_filestream(N'dbo.__sstr_cp_tbl.Blob');
    EXEC Assert.Equals @r, 1;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_is_filestream_should_return_0_for_non_filestream
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_filestream(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- is_xml
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_is_xml_should_return_1_for_xml
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_xml(N'dbo.__sstr_cp_tbl.XmlCol');
    EXEC Assert.Equals @r, 1;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_is_xml_should_return_0_for_non_xml
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_xml(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- is_rowguidcol
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_is_rowguidcol_should_return_1_for_rowguidcol
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_rowguidcol(N'dbo.__sstr_cp_tbl.GuidCol');
    EXEC Assert.Equals @r, 1;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_is_rowguidcol_should_return_0_for_non_rowguidcol
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r bit = $(SchemaName).is_rowguidcol(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_typename
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_typename_should_return_int
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r sysname = $(SchemaName).column_typename(N'dbo.__sstr_cp_tbl.Id');
    EXEC Assert.Equals @r, 'int';
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_typename_should_return_nvarchar
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r sysname = $(SchemaName).column_typename(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 'nvarchar';
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_typename_should_return_null_for_missing
AS
BEGIN
    DECLARE @r sysname = $(SchemaName).column_typename(N'dbo.__sstr_no_such_table.Col');
    EXEC Assert.IsNull @r;
END
GO

-- =============================================
-- column_collation
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_collation_should_return_collation_for_string
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r sysname = $(SchemaName).column_collation(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.IsNotNull @r;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_collation_should_return_null_for_int
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r sysname = $(SchemaName).column_collation(N'dbo.__sstr_cp_tbl.Id');
    EXEC Assert.IsNull @r;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_desc
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_desc_should_return_description
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r nvarchar(4000) = CAST($(SchemaName).column_desc(N'dbo.__sstr_cp_tbl.Id') AS nvarchar(4000));
    EXEC Assert.Equals @r, 'Identifier';
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_desc_should_return_null_for_no_description
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r nvarchar(4000) = CAST($(SchemaName).column_desc(N'dbo.__sstr_cp_tbl.Name') AS nvarchar(4000));
    EXEC Assert.IsNull @r;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_scale / column_precision
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_scale_should_return_scale_for_decimal
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r tinyint = $(SchemaName).column_scale(N'dbo.__sstr_cp_tbl.Price');
    EXEC Assert.Equals @r, 2;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_precision_should_return_precision_for_decimal
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r tinyint = $(SchemaName).column_precision(N'dbo.__sstr_cp_tbl.Price');
    EXEC Assert.Equals @r, 18;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_formula
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_formula_should_return_computed_definition
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r nvarchar(4000) = CAST($(SchemaName).column_formula(N'dbo.__sstr_cp_tbl.ComputedCol') AS nvarchar(4000));
    EXEC Assert.IsNotNull @r;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_formula_should_return_null_for_non_computed
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r nvarchar(4000) = CAST($(SchemaName).column_formula(N'dbo.__sstr_cp_tbl.Name') AS nvarchar(4000));
    EXEC Assert.IsNull @r;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_max_length
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_length_should_return_200_for_nvarchar_100
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_max_length(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 200;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_length_should_return_50_for_varchar_50
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_max_length(N'dbo.__sstr_cp_tbl.Code');
    EXEC Assert.Equals @r, 50;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_length
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_size_should_return_100_for_nvarchar_100
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_length(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 100;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_size_should_return_50_for_varchar_50
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_length(N'dbo.__sstr_cp_tbl.Code');
    EXEC Assert.Equals @r, 50;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_size_should_return_0_for_int
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_length(N'dbo.__sstr_cp_tbl.Id');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_type_info (TVF)
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_type_should_return_int_info
AS
BEGIN
    EXEC dbo.column_api_setup;

    DECLARE @type sysname, @user_type_id int, @system_type_id int;
    SELECT
        @type = type_name,
        @user_type_id = user_type_id,
        @system_type_id = system_type_id
    FROM $(SchemaName).column_type_info(N'dbo.__sstr_cp_tbl.Id');

    EXEC Assert.Equals @type, 'int';
    EXEC Assert.Equals @system_type_id, 56;          -- int = 56
    EXEC Assert.Equals @user_type_id, 56;
    EXEC Assert.Equals @system_type_id, 56;

    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_type_should_return_empty_for_missing
AS
BEGIN
    DECLARE @count int =
        (SELECT COUNT(*) FROM $(SchemaName).column_type_info(N'dbo.__sstr_no_such_table.Col'));
    EXEC Assert.Equals @count, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_multi_fk_column_returns_one_row_in_non_column_fk_name_apis
AS
BEGIN
    EXEC dbo.column_api_setup;

    DECLARE @raised_error BIT = 1
    DECLARE @bool_value BIT
    DECLARE @int_value INT
    DECLARE @str_value NVARCHAR(2000)
    DECLARE @has_comma BIT
    DECLARE @label VARCHAR(100)

    BEGIN TRY
        SET @bool_value = $(SchemaName).is_nullable(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @bool_value = $(SchemaName).is_identity(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @bool_value = $(SchemaName).is_sparse(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @bool_value = $(SchemaName).is_computed(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @bool_value = $(SchemaName).is_filestream(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @bool_value = $(SchemaName).is_xml(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @bool_value = $(SchemaName).is_rowguidcol(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @str_value = $(SchemaName).column_typename(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @str_value = $(SchemaName).column_collation(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @str_value = $(SchemaName).column_desc(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @int_value = $(SchemaName).column_scale(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @int_value = $(SchemaName).column_precision(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @str_value = $(SchemaName).column_formula(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @bool_value = $(SchemaName).is_primary_key(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @bool_value = $(SchemaName).is_foreign_key(N'dbo.__sstr_cp_multi_fk.RefId');

        SET @str_value = $(SchemaName).column_parent(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @has_comma = CASE WHEN CHARINDEX(',', @str_value) = 0 THEN 0 ELSE 1 END
        SET @label = 'column_parent: ' + @str_value

        EXEC Assert.IsTrue @has_comma

        SET @str_value = $(SchemaName).column_fk_name(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @has_comma = CASE WHEN CHARINDEX(',', @str_value) = 0 THEN 0 ELSE 1 END
        SET @label = 'column_fk_name: ' + @str_value

        EXEC Assert.IsTrue @has_comma
        
        SET @str_value = $(SchemaName).column_pk_name(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @int_value = $(SchemaName).column_max_length(N'dbo.__sstr_cp_multi_fk.RefId');
        SET @int_value = $(SchemaName).column_length(N'dbo.__sstr_cp_multi_fk.RefId');

        SET @raised_error = 0
    END TRY
    BEGIN CATCH
        SET @raised_error = 1
    END CATCH

    EXEC Assert.IsFalse @raised_error, @label;

    EXEC dbo.column_api_teardown;
END
GO