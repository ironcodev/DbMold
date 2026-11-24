CREATE OR ALTER FUNCTION $(SchemaName).has_foreign_key(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_foreign_keys(@name, 'in')) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).has_primary_key(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE is_primary_key = 1) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).has_identity(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE is_identity = 1) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).has_filestream(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE is_filestream = 1) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).has_xml(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE is_xml = 1) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).has_computed_columns(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE is_computed = 1) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).has_sparse_columns(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE is_sparse = 1) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).has_persisted_columns(@name $(SchemaName).object_name)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE is_persisted = 1) THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER FUNCTION $(SchemaName).has_column_of_type(@name $(SchemaName).object_name, @type sysname)
RETURNS bit
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM $(SchemaName).column_info(@name) WHERE type_name = @type) THEN 1 ELSE 0 END;
END;
GO

