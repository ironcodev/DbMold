-- =============================================
-- Tests for column property functions
-- =============================================

CREATE OR ALTER PROCEDURE dbo.column_api_setup
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cp_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_tbl;
    IF OBJECT_ID('dbo.__sstr_gci_detail', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_detail;
    IF OBJECT_ID('dbo.__sstr_gci_master', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_master;

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

    CREATE TABLE dbo.__sstr_gci_master
    (
        Id int NOT NULL IDENTITY(1,1) PRIMARY KEY,
        Name nvarchar(100) NOT NULL DEFAULT (N'unknown')
    );

    CREATE TABLE dbo.__sstr_gci_detail
    (
        ChildId  int NOT NULL CONSTRAINT PK_gci_detail PRIMARY KEY,
        ParentId int NULL CONSTRAINT FK_gci_detail_ChildId
                        FOREIGN KEY REFERENCES dbo.__sstr_gci_master(Id)
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.column_api_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cp_tbl', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cp_tbl;
    IF OBJECT_ID('dbo.__sstr_gci_detail', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_detail;
    IF OBJECT_ID('dbo.__sstr_gci_master', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_gci_master;
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
-- column_size
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_size_should_return_200_for_nvarchar_100
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_size(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 200;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_size_should_return_50_for_varchar_50
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_size(N'dbo.__sstr_cp_tbl.Code');
    EXEC Assert.Equals @r, 50;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_length
-- =============================================

CREATE OR ALTER PROCEDURE sstr.column_api_column_length_should_return_100_for_nvarchar_100
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_length(N'dbo.__sstr_cp_tbl.Name');
    EXEC Assert.Equals @r, 100;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_length_should_return_50_for_varchar_50
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_length(N'dbo.__sstr_cp_tbl.Code');
    EXEC Assert.Equals @r, 50;
    EXEC dbo.column_api_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_api_column_length_should_return_0_for_int
AS
BEGIN
    EXEC dbo.column_api_setup;
    DECLARE @r int = $(SchemaName).column_length(N'dbo.__sstr_cp_tbl.Id');
    EXEC Assert.Equals @r, 0;
    EXEC dbo.column_api_teardown;
END
GO

-- =============================================
-- column_type (TVF)
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
    FROM $(SchemaName).column_type(N'dbo.__sstr_cp_tbl.Id');

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
        (SELECT COUNT(*) FROM $(SchemaName).column_type(N'dbo.__sstr_no_such_table.Col'));
    EXEC Assert.Equals @count, 0;
END
GO
