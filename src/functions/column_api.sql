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

CREATE OR ALTER FUNCTION $(SchemaName).is_nullable(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_nullable FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_identity(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_identity FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_sparse(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_sparse FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_computed(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_computed FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_filestream(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_filestream FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_xml(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_xml FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_rowguidcol(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_rowguidcol FROM $(SchemaName).column_info(@name));
END;
GO


-- ---------------------------------------------
-- String / scalar properties
-- ---------------------------------------------

CREATE OR ALTER FUNCTION $(SchemaName).column_typename(@name nvarchar(1000))
RETURNS sysname
AS
BEGIN
    RETURN (SELECT type_name FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_collation(@name nvarchar(1000))
RETURNS sysname
AS
BEGIN
    RETURN (SELECT collation_name FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_desc(@name nvarchar(1000))
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (SELECT column_description FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_scale(@name nvarchar(1000))
RETURNS tinyint
AS
BEGIN
    RETURN (SELECT scale FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_precision(@name nvarchar(1000))
RETURNS tinyint
AS
BEGIN
    RETURN (SELECT [precision] FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_formula(@name nvarchar(1000))
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (SELECT computed_definition FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_primary_key(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN (SELECT is_primary_key FROM $(SchemaName).column_info(@name));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_foreign_key(@name nvarchar(1000))
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN (SELECT parent_column FROM $(SchemaName).column_info(@name)) IS NULL THEN 0 ELSE 1 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_parent(@name nvarchar(1000))
RETURNS nvarchar(1000)
AS
BEGIN
    RETURN (SELECT parent_column FROM $(SchemaName).column_info(@name));
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
create or alter function $(SchemaName).column_fk_name(@name nvarchar(1000))
returns nvarchar(500)
as
begin
    declare @count int;
    select @count = count(*) from $(SchemaName).column_info(@name) where foreign_key_constraint is not null;
    if @count <> 1 return null;
    return (select foreign_key_constraint from $(SchemaName).column_info(@name) where foreign_key_constraint is not null);
end;
go

-- =============================================
-- $(SchemaName).column_pk_name
-- =============================================
-- Returns the name of the primary key constraint on a column, or NULL
-- when the column is not part of the primary key.
-- =============================================
create or alter function $(SchemaName).column_pk_name(@name nvarchar(1000))
returns nvarchar(500)
as
begin
    return (
        select primary_key_constraint
        from $(SchemaName).column_info(@name)
    );
end;
go

-- ---------------------------------------------
-- column_size: mirrors COL_LENGTH (bytes).
-- Returns NULL if the column does not exist.
CREATE OR ALTER FUNCTION $(SchemaName).column_size(@name nvarchar(1000))
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

create or alter function $(SchemaName).column_length(@name nvarchar(1000))
returns int
as
begin
    declare @system_type_id int, @max_len int;

    select @system_type_id = system_type_id, @max_len = max_length
    from $(SchemaName).column_info(@name);

    if @system_type_id is null
        return null;

    return case
        when @system_type_id in (167, 175, 165, 173)      -- varchar, char, varbinary, binary
            then @max_len
        when @system_type_id in (231, 239)                -- nvarchar, nchar
            then case when @max_len = -1 then -1 else @max_len / 2 end
        when @system_type_id in (35, 99, 241)             -- text, ntext, xml
            then -1
        when @system_type_id = 34                          -- image
            then -1
        else 0
    end;
end;
go