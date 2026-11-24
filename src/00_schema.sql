IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'$(SchemaName)')
    EXEC(N'CREATE SCHEMA [$(SchemaName)]');
GO
IF '$(SchemaName)' = 'mold' AND NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'config' AND schema_id = schema_id('$(SchemaName)'))
    CREATE TABLE $(SchemaName).config([key] VARCHAR(100) PRIMARY KEY, [value] NVARCHAR(1000));
GO

IF NOT EXISTS (SELECT 1 FROM sys.types WHERE name = 'object_name' AND schema_id = schema_id('$(SchemaName)'))
    CREATE TYPE $(SchemaName).object_name FROM nvarchar(1035); -- 4 * 258 (return type of QUOTENAME) + 3 (dots)

GO
