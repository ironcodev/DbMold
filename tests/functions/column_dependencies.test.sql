SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Tests for $(SchemaName).column_dependencies
-- =============================================

CREATE OR ALTER PROCEDURE dbo.column_dependencies_setup
AS
BEGIN
    -- Clean first, in dependency order (view -> FK child -> base table).
    exec dbo.column_dependencies_teardown

    CREATE TABLE dbo.__sstr_dep_tbl
    (
        Id      int           NOT NULL CONSTRAINT PK_dep_tbl PRIMARY KEY,
        Price   decimal(18,2) NOT NULL CONSTRAINT UQ_dep_tbl_price UNIQUE,
        Qty     int           NOT NULL,
        Total   AS (Price * Qty) PERSISTED
    );

    CREATE TABLE dbo.__sstr_dep_ref
    (
        Id      int           NOT NULL CONSTRAINT PK_dep_ref PRIMARY KEY,
        Price   decimal(18,2) NOT NULL,
        CONSTRAINT FK_dep_ref_tbl FOREIGN KEY (Price)
            REFERENCES dbo.__sstr_dep_tbl(Price)
    );

    EXEC(N'CREATE VIEW dbo.__sstr_dep_vw WITH SCHEMABINDING
           AS SELECT Id, Price FROM dbo.__sstr_dep_tbl;');

    CREATE INDEX IX_dep_tbl_price ON dbo.__sstr_dep_tbl(Price);
    CREATE STATISTICS ST_dep_tbl_qty ON dbo.__sstr_dep_tbl(Qty);
END
GO

CREATE OR ALTER PROCEDURE dbo.column_dependencies_teardown
AS
BEGIN
    IF OBJECT_ID(N'dbo.__sstr_dep_vw',       N'V') IS NOT NULL DROP VIEW  dbo.__sstr_dep_vw;
    IF OBJECT_ID(N'dbo.__sstr_dep_plain_vw', N'V') IS NOT NULL DROP VIEW  dbo.__sstr_dep_plain_vw;
    IF OBJECT_ID(N'dbo.__sstr_dep_ref',      N'U') IS NOT NULL DROP TABLE dbo.__sstr_dep_ref;
    IF OBJECT_ID(N'dbo.__sstr_dep_tbl',      N'U') IS NOT NULL DROP TABLE dbo.__sstr_dep_tbl;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_dependencies_finds_all_kinds_for_price
AS
BEGIN
    EXEC dbo.column_dependencies_setup;

    DECLARE @deps TABLE (dependency nvarchar(1000), type nvarchar(64));
    INSERT @deps
    SELECT dependency, type
    FROM $(SchemaName).column_dependencies(N'dbo.__sstr_dep_tbl.Price');

    DECLARE @has_index bit = CASE WHEN EXISTS (SELECT 1 FROM @deps WHERE type = N'index')           THEN 1 ELSE 0 END;
    DECLARE @has_fk    bit = CASE WHEN EXISTS (SELECT 1 FROM @deps WHERE type = N'foreign key')     THEN 1 ELSE 0 END;
    DECLARE @has_comp  bit = CASE WHEN EXISTS (SELECT 1 FROM @deps WHERE type = N'computed column') THEN 1 ELSE 0 END;
    DECLARE @has_view  bit = CASE WHEN EXISTS (SELECT 1 FROM @deps WHERE type = N'view')            THEN 1 ELSE 0 END;

    EXEC Assert.Equals @has_index, 1;
    EXEC Assert.Equals @has_fk,    1;
    EXEC Assert.Equals @has_comp,  1;
    EXEC Assert.Equals @has_view,  1;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_dependencies_finds_user_stats_and_computed
AS
BEGIN
    EXEC dbo.column_dependencies_setup;

    DECLARE @deps TABLE (dependency nvarchar(1000), type nvarchar(64));
    INSERT @deps
    SELECT dependency, type
    FROM $(SchemaName).column_dependencies(N'dbo.__sstr_dep_tbl.Qty');

    DECLARE @has_stats bit = CASE WHEN EXISTS (SELECT 1 FROM @deps WHERE type = N'statistics')      THEN 1 ELSE 0 END;
    DECLARE @has_comp  bit = CASE WHEN EXISTS (SELECT 1 FROM @deps WHERE type = N'computed column') THEN 1 ELSE 0 END;
    DECLARE @has_idx   bit = CASE WHEN EXISTS (SELECT 1 FROM @deps WHERE type = N'index')           THEN 1 ELSE 0 END;

    EXEC Assert.Equals @has_stats, 1;
    EXEC Assert.Equals @has_comp,  1;
    EXEC Assert.Equals @has_idx,   0;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_dependencies_pk_reported_as_index
AS
BEGIN
    EXEC dbo.column_dependencies_setup;
    
    IF OBJECT_ID(N'dbo.__sstr_dep_vw',       N'V') IS NOT NULL DROP VIEW  dbo.__sstr_dep_vw;
    IF OBJECT_ID(N'dbo.__sstr_dep_plain_vw', N'V') IS NOT NULL DROP VIEW  dbo.__sstr_dep_plain_vw;
    
    DECLARE @deps TABLE (dependency nvarchar(1000), type nvarchar(64));
    INSERT @deps
    SELECT dependency, type
    FROM $(SchemaName).column_dependencies(N'dbo.__sstr_dep_tbl.Id');

    DECLARE @cnt int, @idx_cnt int, @other_cnt int;
    SELECT @cnt       = COUNT(*) FROM @deps;
    SELECT @idx_cnt   = COUNT(*) FROM @deps WHERE type = N'index';
    SELECT @other_cnt = COUNT(*) FROM @deps WHERE type <> N'index';

    EXEC Assert.Equals @cnt,       1;
    EXEC Assert.Equals @idx_cnt,   1;
    EXEC Assert.Equals @other_cnt, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_dependencies_missing_column_returns_empty
AS
BEGIN
    EXEC dbo.column_dependencies_setup;

    DECLARE @cnt int;
    SELECT @cnt = COUNT(*)
    FROM $(SchemaName).column_dependencies(N'dbo.__sstr_dep_tbl.NoSuchColumn');

    EXEC Assert.Equals @cnt, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_dependencies_missing_table_returns_empty
AS
BEGIN
    EXEC dbo.column_dependencies_setup;

    DECLARE @cnt int;
    SELECT @cnt = COUNT(*)
    FROM $(SchemaName).column_dependencies(N'dbo.__sstr_no_such_table.x');

    EXEC Assert.Equals @cnt, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_dependencies_plain_view_not_reported
AS
BEGIN
    EXEC dbo.column_dependencies_setup;

    EXEC(N'CREATE VIEW dbo.__sstr_dep_plain_vw AS SELECT Id, Price FROM dbo.__sstr_dep_tbl;');

    DECLARE @has_view bit = CASE WHEN EXISTS (
        SELECT 1 FROM $(SchemaName).column_dependencies(N'dbo.__sstr_dep_tbl.Price')
        WHERE type = N'view'
          AND dependency = N'[dbo].[__sstr_dep_plain_vw]'
    ) THEN 1 ELSE 0 END;

    EXEC Assert.Equals @has_view, 0;
END
GO