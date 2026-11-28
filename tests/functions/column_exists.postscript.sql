DROP TABLE IF EXISTS [ mo].__sstr_test_tbl;

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = N' mo')
    DROP SCHEMA [ mo];
