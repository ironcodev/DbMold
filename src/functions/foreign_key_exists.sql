-- =============================================
-- $(SchemaName).foreign_key_exists
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).foreign_key_exists
(
    @fk_column nvarchar(2000),
    @pk_column nvarchar(2000)
)
RETURNS bit
AS
BEGIN
    IF      $(SchemaName).is_empty(@fk_column) = 1
        OR  $(SchemaName).is_empty(@pk_column) = 1
        RETURN 0;

    DECLARE @fk TABLE
    (
        [object_id] int,
        [db]        sysname,
        [schema]    sysname,
        [table]     sysname,
        [column]    sysname,
        [ord]       int
    );

    DECLARE @pk TABLE
    (
        [object_id] int,
        [db]        sysname,
        [schema]    sysname,
        [table]     sysname,
        [column]    sysname,
        [ord]       int
    );

    INSERT INTO @fk ([object_id], [db], [schema], [table], [column], ord)
    SELECT [object_id], [db], [schema], [table], [column], [ord]
    FROM $(SchemaName).parse_column_list(@fk_column);

    INSERT INTO @pk ([object_id], [db], [schema], [table], [column], ord)
    SELECT [object_id], [db], [schema], [table], [column], [ord]
    FROM $(SchemaName).parse_column_list(@pk_column);

    IF NOT EXISTS (SELECT 1 FROM @fk) OR NOT EXISTS (SELECT 1 FROM @pk)
        RETURN 0;

    DECLARE @fk_count int = (SELECT COUNT(*) FROM @fk);
    DECLARE @pk_count int = (SELECT COUNT(*) FROM @pk);

    IF @fk_count <> @pk_count
        RETURN 0;

    DECLARE @fk_table_id int, @fk_db sysname, @fk_schema sysname, @fk_table sysname;
    DECLARE @pk_table_id int, @pk_db sysname, @pk_schema sysname, @pk_table sysname;

    SELECT TOP (1)
        @fk_table_id = [object_id], @fk_db = [db], @fk_schema = [schema], @fk_table = [table]
    FROM @fk;

    SELECT TOP (1)
        @pk_table_id = [object_id], @pk_db = [db], @pk_schema = [schema], @pk_table = [table]
    FROM @pk;

    DECLARE @current_db sysname = DB_NAME()

    IF @fk_db <> @current_db or @pk_db <> @current_db
        RETURN 0;

    IF @fk_table_id IS NULL OR @pk_table_id IS NULL
        RETURN 0;

    RETURN CASE
        WHEN EXISTS 
        (
            SELECT 1
            FROM            sys.foreign_key_columns fkc
                INNER JOIN  sys.foreign_keys        fk      ON fk.object_id     = fkc.constraint_object_id
                INNER JOIN  sys.columns             fk_col  ON fk_col.object_id = fkc.parent_object_id      AND fk_col.column_id = fkc.parent_column_id
                INNER JOIN  sys.columns             pk_col  ON pk_col.object_id = fkc.referenced_object_id  AND pk_col.column_id = fkc.referenced_column_id
                INNER JOIN  @fk                     f       ON f.ord            = fkc.constraint_column_id  AND f.[column] = fk_col.name
                INNER JOIN  @pk                     p       ON p.ord            = fkc.constraint_column_id  AND p.[column] = pk_col.name
            WHERE fkc.parent_object_id = @fk_table_id AND fkc.referenced_object_id = @pk_table_id
            GROUP BY fk.object_id
            HAVING COUNT(*) = @fk_count
        ) THEN 1
        ELSE 0
    END;
END;
GO