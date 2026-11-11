-- =============================================
-- scripts/reset-test-db.sql
-- Recreates the test database from scratch.
-- Run against [master].
-- =============================================
USE master;
GO
SET NOCOUNT ON;

DECLARE @db sysname = N'$(TestDbName)';

-- Drop if exists.
IF DB_ID(@db) IS NOT NULL
BEGIN
    DECLARE @sql nvarchar(max) = N'
        ALTER DATABASE ' + QUOTENAME(@db) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE ' + QUOTENAME(@db) + N';';
    EXEC(@sql);
END

-- Create fresh.
DECLARE @create nvarchar(max) = N'CREATE DATABASE ' + QUOTENAME(@db) + N';';
EXEC(@create);

PRINT 'Test database [' + @db + '] recreated.';