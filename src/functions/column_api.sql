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

CREATE OR ALTER FUNCTION $(SchemaName).is_nullable(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (select is_nullable FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_identity(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (select is_identity FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_sparse(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (select is_sparse FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_computed(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (select is_computed FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_filestream(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (select is_filestream FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_xml(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (select is_xml FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_rowguidcol(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (select is_rowguidcol FROM $(SchemaName).column_info(@column));
END;
GO


-- ---------------------------------------------
-- String / scalar properties
-- ---------------------------------------------

CREATE OR ALTER FUNCTION $(SchemaName).column_typename(@column $(SchemaName).object_name)
RETURNS sysname
AS
BEGIN
    RETURN (select type_name FROM $(SchemaName).column_info(@column));
END;
GO


create or alter function $(SchemaName).column_type
(
    @column $(SchemaName).object_name
)
returns nvarchar(517)
as
begin
    declare @type_name sysname;
    declare @length int;
    declare @max_length int;
    declare @precision tinyint;
    declare @scale tinyint;
    declare @has_user_defined_type bit;
    declare @type_length nvarchar(35);
    declare @type_schema_name sysname;
    declare @xml_schema_collection_id int;
    declare @xml_schema_collection_name sysname;
    declare @xml_schema_collection_schema_name sysname;
    declare @is_xml_document bit;

    select
        @type_name = type_name,
        @length = length,
        @precision = precision,
        @scale = scale,
        @has_user_defined_type = has_user_defined_type,
        @type_schema_name = type_schema_name,
        @xml_schema_collection_id = xml_schema_collection_id,
        @xml_schema_collection_name = xml_schema_collection_name,
        @xml_schema_collection_schema_name = xml_schema_collection_schema_name,
        @is_xml_document = is_xml_document
    from $(SchemaName).column_info(@column);

    if @type_name is null
        return null;

    if @has_user_defined_type = 1
        return quotename(@type_schema_name) + N'.' + quotename(@type_name);

    if @type_name = N'xml'
    begin
        if @xml_schema_collection_id is null
            return N'xml';

        return
            N'xml('
            + case when @is_xml_document = 1 then N'DOCUMENT ' else N'CONTENT ' end
            + quotename(@xml_schema_collection_schema_name)
            + N'.'
            + quotename(@xml_schema_collection_name)
            + N')';
    end;

    if @type_name in (N'char', N'varchar', N'nchar', N'nvarchar', N'binary', N'varbinary')
    begin
        set @max_length = $(SchemaName).string_max_length(@type_name, @length);

        if @max_length = -1
            set @type_length = N'(max)';
        else
            set @type_length = N'(' + convert(nvarchar(10), @max_length) + N')';

        return @type_name + @type_length;
    end;

    if @type_name in (N'decimal', N'numeric')
        return @type_name
            + N'(' + convert(nvarchar(3), @precision)
            + N',' + convert(nvarchar(3), @scale) + N')';

    if @type_name in (N'time', N'datetime2', N'datetimeoffset', N'float')
        return @type_name
            + N'(' + convert(nvarchar(3),
                case
                    when @type_name = N'float' then @precision
                    else @scale
                end
            ) + N')';

    return @type_name;
end;
go

CREATE OR ALTER FUNCTION $(SchemaName).column_collation(@column $(SchemaName).object_name)
RETURNS sysname
AS
BEGIN
    RETURN (select collation_name FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_desc(@column $(SchemaName).object_name)
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (select column_description FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_scale(@column $(SchemaName).object_name)
RETURNS tinyint
AS
BEGIN
    RETURN (select scale FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_precision(@column $(SchemaName).object_name)
RETURNS tinyint
AS
BEGIN
    RETURN (select [precision] FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_formula(@column $(SchemaName).object_name)
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (select computed_definition FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_primary_key(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN (select is_primary_key FROM $(SchemaName).column_info(@column));
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).is_foreign_key(@column $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN (SELECT parent_column FROM $(SchemaName).column_info(@column)) IS NULL THEN 0 ELSE 1 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).column_parent(@column $(SchemaName).object_name)
RETURNS nvarchar(max)
AS
BEGIN
    RETURN (SELECT parent_column FROM $(SchemaName).column_info(@column));
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
create or alter function $(SchemaName).column_fk_name(@column $(SchemaName).object_name)
returns nvarchar(max)
as
begin
    return
    (
        select STRING_AGG(constraint_name, ',')
        from $(SchemaName).column_foreign_keys(@column, 'out')
    );
end;
go

-- =============================================
-- $(SchemaName).column_pk_name
-- =============================================
-- Returns the name of the primary key constraint on a column, or NULL
-- when the column is not part of the primary key.
-- =============================================
create or alter function $(SchemaName).column_pk_name(@column $(SchemaName).object_name)
returns sysname
as
begin
    return (
        select primary_key_constraint
        from $(SchemaName).column_info(@column)
    );
end;
go

-- ---------------------------------------------
-- column_length: mirrors COL_LENGTH (bytes).
-- Returns NULL if the column does not exist.
CREATE OR ALTER FUNCTION $(SchemaName).column_max_length(@column $(SchemaName).object_name)
RETURNS int
AS
BEGIN
    RETURN (select max_length FROM $(SchemaName).column_info(@column));
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
    @column $(SchemaName).object_name
)
RETURNS int
AS
BEGIN
    RETURN (select [length] FROM $(SchemaName).column_info(@column));
END;
GO