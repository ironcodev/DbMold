CREATE OR ALTER FUNCTION $(SchemaName).string_length
(
    @type sysname,
    @max_length int
)
RETURNS int
AS
BEGIN
    RETURN (
        SELECT $(SchemaName)._string_length(bt.system_type_id, @max_length)
        FROM            sys.types AS rt -- requested type
            INNER JOIN  sys.types AS bt -- base type
                ON bt.user_type_id = rt.system_type_id AND bt.user_type_id = bt.system_type_id
        WHERE rt.user_type_id = TYPE_ID(@type)
    )
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName)._string_length
(
    @system_type_id int,
    @max_length int
)
RETURNS int
AS
BEGIN
    IF @system_type_id IS NULL
        RETURN NULL;

    DECLARE @size int = 0;

    ;WITH string_type_families AS
    (
        SELECT
            system_type_id,
            CASE
                WHEN name IN (N'varchar', N'char', N'varbinary', N'binary')
                    THEN N'bytes'

                WHEN name IN (N'nvarchar', N'nchar')
                    THEN N'unicode'

                WHEN name IN (N'text', N'ntext', N'xml', N'image')
                    THEN N'max'
            END AS size_family
        FROM sys.types
        WHERE user_type_id = system_type_id
          AND is_user_defined = 0
    )
    SELECT @size =
        CASE size_family
            WHEN N'bytes'   THEN @max_length
            WHEN N'unicode' THEN CASE WHEN @max_length = -1 THEN -1 ELSE @max_length / 2 END
            WHEN N'max'     THEN -1
            ELSE 0
        END
    FROM string_type_families
    WHERE system_type_id = @system_type_id;

    RETURN @size;
END;
GO
