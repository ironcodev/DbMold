-- =============================================
-- Column property functions (scalar)
-- =============================================
-- These are thin wrappers over $(SchemaName).column_info to make it easy
-- to check a single property of a column.
--
-- All take a single argument: a column reference
--   ('Table.Column', 'Schema.Table.Column', 'Db.Schema.Table.Column', ...).
--
-- If the column does not exist, they return NULL (for most) or 0 (for
-- boolean checks).
-- =============================================


-- ---------------------------------------------
-- Boolean checks (return bit)
-- ---------------------------------------------

CREATE OR ALTER FUNCTION $(SchemaName).is_nullable (@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_nullable FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_identity (@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_identity FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_sparse (@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_sparse FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_computed (@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_computed FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_filestream (@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_filestream FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_xml (@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_xml FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_rowguidcol (@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_rowguidcol FROM $(SchemaName).column_info(@name));
END;
GO


-- ---------------------------------------------
-- String / scalar properties
-- ---------------------------------------------

CREATE OR ALTER FUNCTION $(SchemaName).column_typename (@name nvarchar(1000))
RETURNS sysname
AS
BEGIN
    RETURN (SELECT type_name FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_collation (@name nvarchar(1000))
RETURNS sysname
AS
BEGIN
    RETURN (SELECT collation_name FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_desc (@name nvarchar(1000))
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (SELECT column_description FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_scale (@name nvarchar(1000))
RETURNS tinyint
AS
BEGIN
    RETURN (SELECT scale FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_precision (@name nvarchar(1000))
RETURNS tinyint
AS
BEGIN
    RETURN (SELECT [precision] FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_formula (@name nvarchar(1000))
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (SELECT computed_definition FROM $(SchemaName).column_info(@name));
END;
GO


-- ---------------------------------------------
-- column_size: mirrors COL_LENGTH (bytes).
-- Returns NULL if the column does not exist.
-- ---------------------------------------------

CREATE OR ALTER FUNCTION $(SchemaName).column_size (@name nvarchar(1000))
RETURNS int
AS
BEGIN
    RETURN (SELECT max_length FROM $(SchemaName).column_info(@name));
END;
GO


-- ---------------------------------------------
-- column_length: logical length for string columns.
--   varchar  -> max_length
--   nvarchar -> max_length / 2
--   text, ntext -> -1
--   other    -> 0
-- Returns NULL if the column does not exist.
-- ---------------------------------------------

CREATE OR ALTER FUNCTION $(SchemaName).column_length (@name nvarchar(1000))
RETURNS int
AS
BEGIN
    DECLARE @type sysname, @max_len smallint;

    SELECT @type = type_name, @max_len = max_length
    FROM $(SchemaName).column_info(@name);

    IF @type IS NULL
        RETURN NULL;

    RETURN CASE
        WHEN @type IN (N'varchar', N'char', N'varbinary', N'binary')
            THEN @max_len
        WHEN @type IN (N'nvarchar', N'nchar')
            THEN @max_len / 2
        WHEN @type IN (N'text', N'ntext', N'image')
            THEN -1
        ELSE 0
    END;
END;
GO