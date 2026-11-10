-- =============================================
-- mold.column_exists
-- =============================================
-- Returns 1 if the specified column exists on a user table, 0 otherwise.
--
-- Supported input formats:
--   'Table.Column'                 -> dbo.Table.Column
--   'Schema.Table.Column'          -> Schema.Table.Column
--   'Db.Schema.Table.Column'       -> Db.Schema.Table.Column
--   '[sales].[My.Table].[My.Col]'  -> sales.[My.Table].[My.Col]
--
-- Temp tables (#x, ##x) are NOT supported: UDFs cannot access them.
-- =============================================
CREATE OR ALTER FUNCTION mold.column_exists
(
    @name nvarchar(776)
)
RETURNS bit
AS
BEGIN
    IF @name IS NULL OR LTRIM(RTRIM(@name)) = ''
        RETURN 0;

    DECLARE @normalized nvarchar(776) = LTRIM(RTRIM(@name));

    DECLARE @last_dot int = CHARINDEX(N'.', REVERSE(@normalized));
    IF @last_dot = 0
        RETURN 0;

    DECLARE @object_part nvarchar(776) =
        LEFT(@normalized, LEN(@normalized) - @last_dot);
    DECLARE @column_part nvarchar(776) =
        RIGHT(@normalized, @last_dot - 1);

    IF @column_part = N'' OR @object_part = N''
        RETURN 0;

    -- Temp tables are out of scope for a UDF.
    IF LEFT(@object_part, 1) = N'#'
        RETURN 0;

    DECLARE @object_name nvarchar(776) = @object_part;
    IF CHARINDEX(N'.', @object_name) = 0
        SET @object_name = N'dbo.' + QUOTENAME(@object_name);

    DECLARE @column_name sysname = @column_part;
    IF LEN(@column_name) >= 2
       AND LEFT(@column_name, 1) = N'['
       AND RIGHT(@column_name, 1) = N']'
        SET @column_name = SUBSTRING(@column_name, 2, LEN(@column_name) - 2);

    IF OBJECT_ID(@object_name, N'U') IS NULL
        RETURN 0;

    IF COL_LENGTH(@object_name, @column_name) IS NULL
        RETURN 0;

    RETURN 1;
END;
GO