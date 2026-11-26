SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Tests for $(SchemaName).create_column
-- =============================================

CREATE OR ALTER PROCEDURE dbo.create_column_setup
AS
BEGIN
    IF OBJECT_ID(N'dbo.__sstr_cc_tbl', N'U') IS NOT NULL DROP TABLE dbo.__sstr_cc_tbl;
    CREATE TABLE dbo.__sstr_cc_tbl
    (
        Id int NOT NULL CONSTRAINT PK_cc_tbl PRIMARY KEY
    );

    IF OBJECT_ID(N'dbo.__sstr_cc_data', N'U') IS NOT NULL DROP TABLE dbo.__sstr_cc_data;
    CREATE TABLE dbo.__sstr_cc_data
    (
        Id    int NOT NULL CONSTRAINT PK_cc_data PRIMARY KEY,
        Qty   int NULL,
        Price decimal(18,2) NULL
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.create_column_teardown
AS
BEGIN
    IF OBJECT_ID(N'dbo.__sstr_cc_tbl',  N'U') IS NOT NULL DROP TABLE dbo.__sstr_cc_tbl;
    IF OBJECT_ID(N'dbo.__sstr_cc_data', N'U') IS NOT NULL DROP TABLE dbo.__sstr_cc_data;
END
GO

-- ---------------------------------------------
-- CREATE path
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_creates_simple_column
AS
BEGIN
    EXEC dbo.create_column_setup;

    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Notes",
        "type": "nvarchar(200)",
        "nullable": true
    }';

    declare @flag bit

    set @flag = $(SchemaName).column_exists(N'dbo.__sstr_cc_tbl.Notes')

    EXEC Assert.Equals @flag, 1;

    DECLARE @ci TABLE (type_name nvarchar(500), max_length int, is_nullable bit, is_identity bit);

    INSERT @ci(type_name, max_length, is_nullable, is_identity)
    SELECT type_name, max_length, is_nullable, is_identity
    FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Notes');

    DECLARE @tn nvarchar(500), @ml int, @null bit, @ident bit;
    SELECT @tn = type_name, @ml = max_length, @null = is_nullable, @ident = is_identity FROM @ci;

    EXEC Assert.Equals @tn,    N'nvarchar';
    EXEC Assert.Equals @ml,    400;
    EXEC Assert.Equals @null,  1;
    EXEC Assert.Equals @ident, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_creates_simple_nullable_column
AS
BEGIN
    EXEC dbo.create_column_setup;

    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Notes",
        "type": "nvarchar(200)?"
    }';

    declare @flag bit

    set @flag = $(SchemaName).column_exists(N'dbo.__sstr_cc_tbl.Notes')

    EXEC Assert.Equals @flag, 1;

    DECLARE @ci TABLE (type_name nvarchar(500), max_length int, is_nullable bit, is_identity bit);

    INSERT @ci(type_name, max_length, is_nullable, is_identity)
    SELECT type_name, max_length, is_nullable, is_identity
    FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Notes');

    DECLARE @tn nvarchar(500), @ml int, @null bit, @ident bit;
    SELECT @tn = type_name, @ml = max_length, @null = is_nullable, @ident = is_identity FROM @ci;

    EXEC Assert.Equals @tn,    N'nvarchar';
    EXEC Assert.Equals @ml,    400;
    EXEC Assert.Equals @null,  1;
    EXEC Assert.Equals @ident, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_creates_not_null_column
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Code",
        "type": "varchar(20)",
        "nullable": false,
        "default": "''x''"
    }';

    DECLARE @ci TABLE (is_nullable bit, default_value nvarchar(max));
    INSERT @ci SELECT is_nullable, default_value
                FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Code');

    DECLARE @null bit, @def nvarchar(max);
    SELECT @null = is_nullable, @def = default_value FROM @ci;

    EXEC Assert.Equals      @null, 0;
    EXEC Assert.MaxNotEquals @def, NULL;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_creates_identity_column
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Seq",
        "type": "int",
        "identity": { "seed": 1, "increment": 1 }
    }';

    DECLARE @ci TABLE (is_identity bit);
    INSERT @ci SELECT is_identity FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Seq');

    DECLARE @ident bit;
    SELECT @ident = is_identity FROM @ci;

    EXEC Assert.Equals @ident, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_creates_computed_column
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_data",
        "name": "Total",
        "computed": { "expression": "Qty * Price", "persisted": true }
    }';

    DECLARE @ci TABLE (is_computed bit, computed_definition nvarchar(max));
    INSERT @ci SELECT is_computed, computed_definition
                FROM $(SchemaName).column_info(N'dbo.__sstr_cc_data.Total');

    DECLARE @comp bit, @def nvarchar(max);
    SELECT @comp = is_computed, @def = computed_definition FROM @ci;

    EXEC Assert.Equals      @comp, 1;
    EXEC Assert.MaxNotEquals @def,  NULL;
END
GO

-- ---------------------------------------------
-- Idempotency: second call is NO CHANGE
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_second_call_is_no_change
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    DECLARE @spec nvarchar(max) = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Notes",
        "type": "nvarchar(200)",
        "nullable": true
    }';

    EXEC $(SchemaName).create_column @spec = @spec;
    EXEC $(SchemaName).create_column @spec = @spec;

    DECLARE @ci TABLE (type_name nvarchar(500), max_length int, is_nullable bit);
    INSERT @ci SELECT type_name, max_length, is_nullable
                FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Notes');

    DECLARE @tn nvarchar(500), @ml int, @null bit;
    SELECT @tn = type_name, @ml = max_length, @null = is_nullable FROM @ci;

    EXEC Assert.Equals @tn,   N'nvarchar';
    EXEC Assert.Equals @ml,   400;
    EXEC Assert.Equals @null, 1;
END
GO

-- ---------------------------------------------
-- ALTER path: widening type
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_alters_varchar_to_wider
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "varchar(50)"
    }';

    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "varchar(200)"
    }';

    DECLARE @ci TABLE (max_length int);
    INSERT @ci SELECT max_length FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Tmp');

    DECLARE @ml int;
    SELECT @ml = max_length FROM @ci;

    EXEC Assert.Equals @ml, 200;
END
GO

-- ---------------------------------------------
-- ALTER path: nullable flip (empty table -> allowed)
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_alters_nullable_to_not_null_on_empty_table
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "nullable": true
    }';

    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "nullable": false
    }';

    DECLARE @ci TABLE (is_nullable bit);
    INSERT @ci SELECT is_nullable FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Tmp');

    DECLARE @null bit;
    SELECT @null = is_nullable FROM @ci;

    EXEC Assert.Equals @null, 0;
END
GO

-- ---------------------------------------------
-- ALTER path: narrowing with no offending data
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_alters_varchar_to_narrower_when_data_fits
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "varchar(100)"
    }';

    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "varchar(50)"
    }';

    DECLARE @ci TABLE (max_length int);
    INSERT @ci SELECT max_length FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Tmp');

    DECLARE @ml int;
    SELECT @ml = max_length FROM @ci;

    EXEC Assert.Equals @ml, 50;
END
GO

-- ---------------------------------------------
-- ALTER path: sparse toggle
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_toggles_sparse
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "nullable": true
    }';

    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "nullable": true,
        "sparse": true
    }';

    DECLARE @ci TABLE (is_sparse bit);
    INSERT @ci SELECT is_sparse FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Tmp');

    DECLARE @sp bit;
    SELECT @sp = is_sparse FROM @ci;

    EXEC Assert.Equals @sp, 1;
END
GO

-- ---------------------------------------------
-- Default handling
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_does_not_touch_default_when_absent
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "nullable": true,
        "default": "42"
    }';

    -- no "default" in this call; must not drop the existing one
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "nullable": true
    }';

    DECLARE @ci TABLE (default_value nvarchar(max));
    INSERT @ci SELECT default_value FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Tmp');

    DECLARE @def nvarchar(max);
    SELECT @def = default_value FROM @ci;

    EXEC Assert.MaxNotEquals @def, NULL;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_replaces_default_when_value_differs
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "nullable": true,
        "default": "1"
    }';

    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "nullable": true,
        "default": "2"
    }';

    DECLARE @ci TABLE (default_value nvarchar(max));
    INSERT @ci SELECT default_value FROM $(SchemaName).column_info(N'dbo.__sstr_cc_tbl.Tmp');

    DECLARE @def nvarchar(max);
    SELECT @def = default_value FROM @ci;

    DECLARE @ok bit = CASE WHEN $(SchemaName)._normalize_default(@def) = N'2' THEN 1 ELSE 0 END;
    EXEC Assert.IsTrue @ok;
END
GO

-- ---------------------------------------------
-- Dry run: no side effect
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_dry_run_does_not_create
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    DECLARE @spec nvarchar(max) = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Ghost",
        "type": "int",
        "nullable": true,
        "dryRun": true
    }';

    EXEC $(SchemaName).create_column @spec = @spec;

    declare @exists bit = $(SchemaName).column_exists(N'dbo.__sstr_cc_tbl.Ghost')

    EXEC Assert.Equals @exists, 0;
END
GO

-- ---------------------------------------------
-- THROW cases
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.create_column_throws_on_unknown_type
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    DECLARE @err int = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_column @spec = N'{
            "table": "dbo.__sstr_cc_tbl",
            "name": "Bad",
            "type": "not_a_type"
        }';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH

    EXEC Assert.Equals @err, 50002;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_throws_on_nullabality_conflict
AS
BEGIN
    EXEC dbo.create_column_setup;

    DECLARE @err int = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_column @spec = N'{
            "table": "dbo.__sstr_cc_tbl",
            "name": "Notes",
            "type": "nvarchar(200)?",
            "nullable": false
        }';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH

    EXEC Assert.Equals @err, 50002;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_throws_on_missing_table
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    DECLARE @err int = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_column @spec = N'{
            "table": "dbo.__sstr_no_such_table",
            "name": "X",
            "type": "int"
        }';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH

    EXEC Assert.Equals @err, 50001;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_throws_on_identity_change
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int",
        "identity": { "seed": 1, "increment": 1 }
    }';

    -- try to remove identity: must throw
    DECLARE @err int = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_column @spec = N'{
            "table": "dbo.__sstr_cc_tbl",
            "name": "Tmp",
            "type": "int"
        }';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH

    EXEC Assert.Equals @err, 50011;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_throws_on_computed_change
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_data",
        "name": "Total2",
        "computed": { "expression": "Qty * Price", "persisted": true }
    }';

    DECLARE @err int = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_column @spec = N'{
            "table": "dbo.__sstr_cc_data",
            "name": "Total2",
            "computed": { "expression": "Qty + Price", "persisted": true }
        }';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH

    EXEC Assert.Equals @err, 50015;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_throws_on_forbidden_type_change
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_tbl",
        "name": "Tmp",
        "type": "int"
    }';

    DECLARE @err int = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_column @spec = N'{
            "table": "dbo.__sstr_cc_tbl",
            "name": "Tmp",
            "type": "varchar(50)"
        }';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH

    EXEC Assert.Equals @err, 50016;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_throws_on_narrowing_with_data
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_data",
        "name": "Tmp",
        "type": "varchar(100)",
        "nullable": true
    }';

    INSERT dbo.__sstr_cc_data (Id, Qty, Price, Tmp)
    VALUES (1, 10, 1.00, REPLICATE(N'x', 80));

    DECLARE @err int = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_column @spec = N'{
            "table": "dbo.__sstr_cc_data",
            "name": "Tmp",
            "type": "varchar(50)",
            "nullable": true
        }';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH

    EXEC Assert.Equals @err, 50017;

    -- cleanup so the next test starts clean
    DELETE dbo.__sstr_cc_data WHERE Id = 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.create_column_throws_on_not_null_with_nulls
AS
BEGIN
    EXEC dbo.create_column_setup;
    
    EXEC $(SchemaName).create_column @spec = N'{
        "table": "dbo.__sstr_cc_data",
        "name": "Tmp",
        "type": "int",
        "nullable": true
    }';

    INSERT dbo.__sstr_cc_data (Id, Qty, Price, Tmp)
    VALUES (1, 10, 1.00, NULL);

    DECLARE @err int = 0;
    BEGIN TRY
        EXEC $(SchemaName).create_column @spec = N'{
            "table": "dbo.__sstr_cc_data",
            "name": "Tmp",
            "type": "int",
            "nullable": false
        }';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();
    END CATCH

    EXEC Assert.Equals @err, 50017;

    DELETE dbo.__sstr_cc_data WHERE Id = 1;
END
GO