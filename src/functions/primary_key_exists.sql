/*
    Function: primary_key_exists

    Description:
        Determines whether the specified table has a primary key whose
        complete column list matches the supplied columns in the same order.

    Input:
        @name - A table-and-column specification accepted by parse_column_list.
                Examples:
                    N'dbo.Users.Id'
                    N'dbo.UserRoles(UserId,RoleId)'

    Returns:
        bit
            1 - The table's primary key contains exactly the supplied columns,
                in the supplied order.
            0 - The table does not exist, has no primary key, the supplied
                columns do not exactly match its primary key, the input is
                invalid, or the specification refers to another database.

    Notes:
        - Uses parse_column_list to parse the input.
        - Checks metadata in the current database only. A scalar UDF cannot
          use dynamic SQL to inspect an arbitrary database.
        - Composite-key column order is significant.
        - A partial or superset column list is not considered a match.
*/

CREATE OR ALTER FUNCTION $(SchemaName).primary_key_exists
(
    @name nvarchar(1000)
)
RETURNS bit
AS
BEGIN
    IF $(SchemaName).is_empty(@name) = 1
        RETURN 0;

    DECLARE
        @db             sysname,
        @schema         sysname,
        @table          sysname,
        @object_id      int,
        @column_count   int;

    DECLARE @columns TABLE
    (
        [object_id] int,
        [db]        sysname,
        [schema]    sysname,
        [table]     sysname,
        [column]    sysname,
        [ord]       int
    );

    INSERT INTO @columns
    (
        [object_id],
        [db],
        [schema],
        [table],
        [column],
        [ord]
    )
    SELECT
        [object_id],
        [db],
        [schema],
        [table],
        [column],
        [ord]
    FROM $(SchemaName).parse_column_list(@name);

    SELECT TOP (1)
        @object_id  = [object_id],
        @db         = [db],
        @schema     = [schema],
        @table      = [table]
    FROM @columns;

    SELECT @column_count = COUNT(*) FROM @columns;

    -- A valid specification must identify a database, schema, table,
    -- and at least one column.
    IF @column_count = 0 OR @db IS NULL OR @schema IS NULL OR @table IS NULL
        RETURN 0;

    -- Scalar UDFs cannot use dynamic SQL to inspect another database.
    IF @db <> DB_NAME()
        RETURN 0;

    IF @object_id IS NULL
        RETURN 0;

    /*
        Match a primary-key constraint only when:
          1. Its number of key columns equals the requested column count.
          2. Every requested column matches the key column at the same
             ordinal position.

        The second condition uses a double NOT EXISTS so that every
        requested column must have a corresponding key column.
    */
    IF EXISTS
    (
        SELECT 1
        FROM sys.key_constraints kc
        WHERE kc.parent_object_id = @object_id
          AND kc.type = N'PK'
          AND
          (
              SELECT COUNT(*)
              FROM sys.index_columns ic
              WHERE ic.object_id = kc.parent_object_id
                AND ic.index_id = kc.unique_index_id
                AND ic.key_ordinal > 0
          ) = @column_count
          AND NOT EXISTS
          (
              SELECT 1
              FROM @columns requested
              WHERE NOT EXISTS
              (
                  SELECT 1
                  FROM sys.index_columns ic
                  INNER JOIN sys.columns c
                      ON c.object_id = ic.object_id
                     AND c.column_id = ic.column_id
                  WHERE ic.object_id = kc.parent_object_id
                    AND ic.index_id = kc.unique_index_id
                    AND ic.key_ordinal = requested.[ord]
                    AND c.name = requested.[column]
              )
          )
    )
        RETURN 1;

    RETURN 0;
END
GO
