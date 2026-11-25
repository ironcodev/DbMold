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
    IF OBJECT_ID('dbo.__sstr_cfk_parent', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_parent;

    CREATE TABLE dbo.__sstr_cfk_parent
    (
        Id int NOT NULL IDENTITY(1,1) CONSTRAINT PK_cfk_tbl PRIMARY KEY,
        Name nvarchar(100) NOT NULL DEFAULT (N'unknown'),
        Price decimal(18,2) NULL,
        ComputedCol AS (Price * 2),
        SparseCol int SPARSE NULL,
        Code char(4) NOT NULL
    );

    -- composite unique key, so a column can be a non-PK unique column
    ALTER TABLE dbo.__sstr_cfk_parent
        ADD CONSTRAINT UQ_cfk_tbl_code UNIQUE (Code);

    -- child table with two single-column FKs and one composite FK
    CREATE TABLE dbo.__sstr_cfk_child
    (
        ChildId  int NOT NULL CONSTRAINT PK_cfk_child PRIMARY KEY,
        ParentId int NULL CONSTRAINT FK_cfk_child_tbl_id
                       FOREIGN KEY REFERENCES dbo.__sstr_cfk_parent(Id) ON DELETE CASCADE,
        Code     char(4) NULL CONSTRAINT FK_cfk_child_tbl_code
                       FOREIGN KEY REFERENCES dbo.__sstr_cfk_parent(Code) ON DELETE NO ACTION ON UPDATE SET NULL,
        Price    decimal(18,2) NULL
    );

    EXEC sp_addextendedproperty
        @name = N'MS_Description',
        @value = N'Identifier of the row',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'__sstr_cfk_parent',
        @level2type = N'COLUMN', @level2name = N'Id';

    IF OBJECT_ID('dbo.__sstr_cfk_multi_fk', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_multi_fk;
    IF OBJECT_ID('dbo.__sstr_cfk_parent_a', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_parent_a;
    IF OBJECT_ID('dbo.__sstr_cfk_parent_b', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_parent_b;

    CREATE TABLE dbo.__sstr_cfk_parent_a
    (
        Id int NOT NULL CONSTRAINT PK_cfk_parent_a PRIMARY KEY
    );

    CREATE TABLE dbo.__sstr_cfk_parent_b
    (
        Id int NOT NULL CONSTRAINT PK_cfk_parent_b PRIMARY KEY
    );

    CREATE TABLE dbo.__sstr_cfk_multi_fk
    (
        RefId int NULL
            CONSTRAINT FK_cfk_multi_fk_a FOREIGN KEY REFERENCES dbo.__sstr_cfk_parent_a(Id) ON DELETE CASCADE ON UPDATE CASCADE,
            CONSTRAINT FK_cfk_multi_fk_b FOREIGN KEY (RefId) REFERENCES dbo.__sstr_cfk_parent_b(Id)  ON DELETE NO ACTION ON UPDATE SET NULL
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.column_foreign_keys_teardown
AS
BEGIN
    IF OBJECT_ID('dbo.__sstr_cfk_child', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_child;
    IF OBJECT_ID('dbo.__sstr_cfk_parent', 'U') IS NOT NULL
        DROP TABLE dbo.__sstr_cfk_parent;
    
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
    FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_cfk_child.ParentId', 'out');

    DECLARE
        @count                  INT,
        @direction              varchar(8),
        @constraint_name        nvarchar(500),
        @child_schema           sysname,
        @child_table            sysname,
        @child_column           sysname,
        @parent_schema          sysname,
        @parent_table           sysname,
        @parent_column          sysname,
        @constraint_column_id   int,
        @is_disabled            bit,
        @is_not_trusted         bit,
        @delete_rule            nvarchar(60),
        @update_rule            nvarchar(60)

    SELECT @count = count(*) FROM @info

    EXEC Assert.Equals @count, 1;
    SELECT
        @direction              = [direction],
        @constraint_name        = [constraint_name],
        @child_schema           = [child_schema],
        @child_table            = [child_table],
        @child_column           = [child_column],
        @parent_schema          = [parent_schema],
        @parent_table           = [parent_table],
        @parent_column          = [parent_column],
        @constraint_column_id   = [constraint_column_id],
        @is_disabled            = [is_disabled],
        @is_not_trusted         = [is_not_trusted],
        @delete_rule            = [delete_rule],
        @update_rule            = [update_rule]
    FROM @info

    EXEC Assert.Equals @direction       , 'outgoing'            , 'direction';
    EXEC Assert.Equals @constraint_name , 'FK_cfk_child_tbl_id' , 'constraint_name';
    EXEC Assert.Equals @child_schema    , 'dbo'                 , 'child_schema';
    EXEC Assert.Equals @child_table     , '__sstr_cfk_child'    , 'child_table';
    EXEC Assert.Equals @child_column    , 'ParentId'            , 'child_column';
    EXEC Assert.Equals @parent_schema   , 'dbo'                 , 'parent_schema';
    EXEC Assert.Equals @parent_table    , '__sstr_cfk_parent'   , 'parent_table';
    EXEC Assert.Equals @parent_column   , 'Id'                  , 'parent_column';
    EXEC Assert.Equals @is_disabled     , 0                     , 'is_disabled';
    EXEC Assert.Equals @is_not_trusted  , 0                     , 'is_not_trusted';
    EXEC Assert.Equals @delete_rule     , 'CASCADE'             , 'delete_rule';
    EXEC Assert.Equals @update_rule     , 'NO_ACTION'           , 'update_rule';

    EXEC dbo.column_foreign_keys_teardown;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_foreign_keys_multi_fk_column_reports_constraint
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
    FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_cfk_multi_fk.RefId', 'out');

    DECLARE
        @count                  INT,
        @direction              varchar(8),
        @constraint_name        nvarchar(500),
        @child_schema           sysname,
        @child_table            sysname,
        @child_column           sysname,
        @parent_schema          sysname,
        @parent_table           sysname,
        @parent_column          sysname,
        @constraint_column_id   int,
        @is_disabled            bit,
        @is_not_trusted         bit,
        @delete_rule            nvarchar(60),
        @update_rule            nvarchar(60)

    SELECT @count = count(*) FROM @info

    EXEC Assert.Equals @count, 2;

    SELECT
        @direction              = [direction],
        @constraint_name        = [constraint_name],
        @child_schema           = [child_schema],
        @child_table            = [child_table],
        @child_column           = [child_column],
        @parent_schema          = [parent_schema],
        @parent_table           = [parent_table],
        @parent_column          = [parent_column],
        @constraint_column_id   = [constraint_column_id],
        @is_disabled            = [is_disabled],
        @is_not_trusted         = [is_not_trusted],
        @delete_rule            = [delete_rule],
        @update_rule            = [update_rule]
    FROM @info
    WHERE [parent_table] = '__sstr_cfk_parent_a'

    EXEC Assert.Equals @direction       , 'outgoing'            , 'a: direction';
    EXEC Assert.Equals @constraint_name , 'FK_cfk_multi_fk_a'   , 'a: constraint_name';
    EXEC Assert.Equals @child_schema    , 'dbo'                 , 'a: child_schema';
    EXEC Assert.Equals @child_table     , '__sstr_cfk_multi_fk' , 'a: child_table';
    EXEC Assert.Equals @child_column    , 'RefId'               , 'a: child_column';
    EXEC Assert.Equals @parent_schema   , 'dbo'                 , 'a: parent_schema';
    EXEC Assert.Equals @parent_column   , 'Id'                  , 'a: parent_column';
    EXEC Assert.Equals @is_disabled     , 0                     , 'a: is_disabled';
    EXEC Assert.Equals @is_not_trusted  , 0                     , 'a: is_not_trusted';
    EXEC Assert.Equals @delete_rule     , 'CASCADE'             , 'a: delete_rule';
    EXEC Assert.Equals @update_rule     , 'CASCADE'             , 'a: update_rule';

    SELECT
        @direction              = [direction],
        @constraint_name        = [constraint_name],
        @child_schema           = [child_schema],
        @child_table            = [child_table],
        @child_column           = [child_column],
        @parent_schema          = [parent_schema],
        @parent_table           = [parent_table],
        @parent_column          = [parent_column],
        @constraint_column_id   = [constraint_column_id],
        @is_disabled            = [is_disabled],
        @is_not_trusted         = [is_not_trusted],
        @delete_rule            = [delete_rule],
        @update_rule            = [update_rule]
    FROM @info
    WHERE [parent_table] = '__sstr_cfk_parent_b'

    EXEC Assert.Equals @direction       , 'outgoing'            , 'b: direction';
    EXEC Assert.Equals @constraint_name , 'FK_cfk_multi_fk_b'   , 'b: constraint_name';
    EXEC Assert.Equals @child_schema    , 'dbo'                 , 'b: child_schema';
    EXEC Assert.Equals @child_table     , '__sstr_cfk_multi_fk' , 'b: child_table';
    EXEC Assert.Equals @child_column    , 'RefId'               , 'b: child_column';
    EXEC Assert.Equals @parent_schema   , 'dbo'                 , 'b: parent_schema';
    EXEC Assert.Equals @parent_column   , 'Id'                  , 'b: parent_column';
    EXEC Assert.Equals @is_disabled     , 0                     , 'b: is_disabled';
    EXEC Assert.Equals @is_not_trusted  , 0                     , 'b: is_not_trusted';
    EXEC Assert.Equals @delete_rule     , 'NO_ACTION'           , 'b: delete_rule';
    EXEC Assert.Equals @update_rule     , 'SET_NULL'            , 'b: update_rule';

    EXEC dbo.column_foreign_keys_teardown;
END
GO