IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'$(SchemaName)')
    EXEC(N'CREATE SCHEMA [$(SchemaName)]');
GO
