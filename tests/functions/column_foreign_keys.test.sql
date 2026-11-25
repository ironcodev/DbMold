-- 19. FK column reports the FK constraint name.
CREATE OR ALTER PROCEDURE sstr.column_foreign_keys_fk_column_reports_constraint
AS
BEGIN
    EXEC dbo.column_foreign_keys_setup;

    DECLARE @fk_name nvarchar(500);

    SELECT @fk_name = foreign_key_constraint
    FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_gci_child.ParentId');

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
    FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_gci_multi_fk.RefId');

    -- two FKs on the same column -> two rows
    EXEC Assert.Equals @count,            2;
    -- each row names a different parent column
    EXEC Assert.Equals @distinct_parents, 2;
    -- each row names a different FK constraint
    EXEC Assert.Equals @distinct_fks,     2;

    -- both parent columns are present, in either order
    DECLARE @has_a bit = CASE WHEN EXISTS (
        SELECT 1 FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_gci_multi_fk.RefId')
        WHERE parent_column = N'[dbo].[__sstr_gci_parent_a].[Id]'
          AND foreign_key_constraint = N'FK_gci_multi_fk_a'
    ) THEN 1 ELSE 0 END;

    DECLARE @has_b bit = CASE WHEN EXISTS (
        SELECT 1 FROM $(SchemaName).column_foreign_keys(N'dbo.__sstr_gci_multi_fk.RefId')
        WHERE parent_column = N'[dbo].[__sstr_gci_parent_b].[Id]'
          AND foreign_key_constraint = N'FK_gci_multi_fk_b'
    ) THEN 1 ELSE 0 END;

    EXEC Assert.Equals @has_a, 1;
    EXEC Assert.Equals @has_b, 1;

    EXEC dbo.column_foreign_keys_teardown;
END
GO
