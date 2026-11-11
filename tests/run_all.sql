IF $(SchemaName).table_exists('dbo.SomeTable') <> 0
BEGIN
    PRINT 'FAIL: table_exists';
END