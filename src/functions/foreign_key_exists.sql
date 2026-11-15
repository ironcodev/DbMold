-- =============================================
-- $(SchemaName).foreign_key_exists
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).foreign_key_exists
(
    @fk_column nvarchar(1000),
    @pk_column nvarchar(1000)
)
RETURNS bit
AS
BEGIN
    IF @fk_column IS NULL OR LTRIM(RTRIM(@fk_column)) = ''
        RETURN 0;
    IF @pk_column IS NULL OR LTRIM(RTRIM(@pk_column)) = ''
        RETURN 0;

    DECLARE @fk TABLE
    (
        [db]        sysname,
        [schema]    sysname,
        [table]     sysname,
        [column]    sysname,
        ord         int
    );

    DECLARE @pk TABLE
    (
        [db]        sysname,
        [schema]    sysname,
        [table]     sysname,
        [column]    sysname,
        ord         int
    );

    -- NOTE: _parse_column_list returns columns named
    -- schema_name and table_name (not schema / table).
    INSERT INTO @fk ([db], [schema], [table], [column], ord)
    SELECT [db], schema_name, table_name, column_name, ord
    FROM $(SchemaName)._parse_column_list(@fk_column);

    INSERT INTO @pk ([db], [schema], [table], [column], ord)
    SELECT [db], schema_name, table_name, column_name, ord
    FROM $(SchemaName)._parse_column_list(@pk_column);

    IF NOT EXISTS (SELECT 1 FROM @fk) OR NOT EXISTS (SELECT 1 FROM @pk)
        RETURN 0;

    DECLARE @fk_count int = (SELECT COUNT(*) FROM @fk);
    DECLARE @pk_count int = (SELECT COUNT(*) FROM @pk);
    IF @fk_count <> @pk_count
        RETURN 0;

    DECLARE @fk_db sysname, @fk_schema sysname, @fk_table sysname;
    DECLARE @pk_db sysname, @pk_schema sysname, @pk_table sysname;

    SELECT TOP (1)
        @fk_db = [db], @fk_schema = [schema], @fk_table = [table]
    FROM @fk;

    SELECT TOP (1)
        @pk_db = [db], @pk_schema = [schema], @pk_table = [table]
    FROM @pk;

    DECLARE @fk_table_id int = OBJECT_ID(
        QUOTENAME(@fk_db) + N'.' + QUOTENAME(@fk_schema) + N'.' + QUOTENAME(@fk_table), N'U');
    DECLARE @pk_table_id int = OBJECT_ID(
        QUOTENAME(@pk_db) + N'.' + QUOTENAME(@pk_schema) + N'.' + QUOTENAME(@pk_table), N'U');

    IF @fk_table_id IS NULL OR @pk_table_id IS NULL
        RETURN 0;

    RETURN CASE
        WHEN EXISTS (
            SELECT 1
            FROM sys.foreign_key_columns fkc
            JOIN sys.foreign_keys fk
              ON fk.object_id = fkc.constraint_object_id
            JOIN sys.columns fk_col
              ON fk_col.object_id = fkc.parent_object_id
             AND fk_col.column_id = fkc.parent_column_id
            JOIN sys.columns pk_col
              ON pk_col.object_id = fkc.referenced_object_id
             AND pk_col.column_id = fkc.referenced_column_id
            JOIN @fk f
              ON f.ord = fkc.constraint_column_id
             AND f.[column] = fk_col.name
            JOIN @pk p
              ON p.ord = fkc.constraint_column_id
             AND p.[column] = pk_col.name
            WHERE fkc.parent_object_id     = @fk_table_id
              AND fkc.referenced_object_id = @pk_table_id
            GROUP BY fk.object_id
            HAVING COUNT(*) = @fk_count
        ) THEN 1
        ELSE 0
    END;
END;
GO