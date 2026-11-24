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

CREATE OR ALTER FUNCTION $(SchemaName).is_nullable(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (SELECT TOP(1) is_nullable FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_identity(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (SELECT TOP(1) is_identity FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_sparse(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (SELECT TOP(1) is_sparse FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_computed(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (SELECT TOP(1) is_computed FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_filestream(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (SELECT TOP(1) is_filestream FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_xml(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (SELECT TOP(1) is_xml FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_rowguidcol(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (SELECT TOP(1) is_rowguidcol FROM $(SchemaName).column_info(@name));
END;
GO


-- ---------------------------------------------
-- String / scalar properties
-- ---------------------------------------------

CREATE OR ALTER FUNCTION $(SchemaName).column_typename(@name $(SchemaName).object_name)
RETURNS sysname
AS
BEGIN
    RETURN (SELECT TOP(1) type_name FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_collation(@name $(SchemaName).object_name)
RETURNS sysname
AS
BEGIN
    RETURN (SELECT TOP(1) collation_name FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_desc(@name $(SchemaName).object_name)
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (SELECT TOP(1) column_description FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_scale(@name $(SchemaName).object_name)
RETURNS tinyint
AS
BEGIN
    RETURN (SELECT TOP(1) scale FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_precision(@name $(SchemaName).object_name)
RETURNS tinyint
AS
BEGIN
    RETURN (SELECT TOP(1) [precision] FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_formula(@name $(SchemaName).object_name)
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (SELECT TOP(1) computed_definition FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_primary_key(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (SELECT TOP(1) is_primary_key FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_foreign_key(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE parent_column IS NOT NULL) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_parent(@name $(SchemaName).object_name)
RETURNS nvarchar(777)
AS
BEGIN
    RETURN (SELECT STRING_AGG(parent_column, ',') FROM $(SchemaName).column_info(@name));
END;
GO

-- =============================================
-- $(SchemaName).column_fk_name
-- =============================================
-- Returns the name of the foreign key constraint on a column, or NULL
-- when the column is not the child side of any FK.
--
-- If the column participates in more than one FK, the alphabetically
-- first constraint name is returned, so the function is deterministic.
-- Use column_info when you need every constraint name.
-- =============================================
create or alter function $(SchemaName).column_fk_name(@name $(SchemaName).object_name)
returns sysname
as
begin
    return
    (
        select STRING_AGG(foreign_key_constraint, ',')
        from $(SchemaName).column_info(@name)
        where foreign_key_constraint is not null
    );
end;
go

-- =============================================
-- $(SchemaName).column_pk_name
-- =============================================
-- Returns the name of the primary key constraint on a column, or NULL
-- when the column is not part of the primary key.
-- =============================================
create or alter function $(SchemaName).column_pk_name(@name $(SchemaName).object_name)
returns sysname
as
begin
    return (
        select top(1) primary_key_constraint
        from $(SchemaName).column_info(@name)
    );
end;
go

-- ---------------------------------------------
-- column_length: mirrors COL_LENGTH (bytes).
-- Returns NULL if the column does not exist.
CREATE OR ALTER FUNCTION $(SchemaName).column_max_length(@name $(SchemaName).object_name)
RETURNS int
AS
BEGIN
    RETURN (SELECT TOP(1) max_length FROM $(SchemaName).column_info(@name));
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
CREATE OR ALTER FUNCTION $(SchemaName).column_length
(
    @name $(SchemaName).object_name
)
RETURNS int
AS
BEGIN
    RETURN (SELECT TOP(1) [length] FROM $(SchemaName).column_info(@name));
END;
GO