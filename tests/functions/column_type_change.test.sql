-- =============================================
-- Tests for $(SchemaName).column_type_change
-- =============================================
-- No setup needed; the TVF takes scalar parameters only.
-- =============================================

CREATE OR ALTER PROCEDURE dbo.column_type_change_setup
AS
BEGIN
    IF OBJECT_ID(N'$(SchemaName).column_type_change', N'IF') IS NULL
        THROW 50000, N'column_type_change TVF is missing.', 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.column_type_change_teardown
AS
BEGIN
    RETURN;
END
GO

-- ---------------------------------------------
-- Widening
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.column_type_change_int_to_bigint_is_widening
AS
BEGIN
    DECLARE @class nvarchar(20), @data bit, @coll bit;
    SELECT @class = class, @data = requires_data_check, @coll = requires_collation_check
    FROM $(SchemaName).column_type_change(
        N'int', 4, 10, 0,
        N'bigint', 8, 19, 0);

    EXEC Assert.Equals @class, N'widening';
    EXEC Assert.Equals @data,  0;
    EXEC Assert.Equals @coll,  0;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_varchar_widen_is_widening
AS
BEGIN
    DECLARE @class nvarchar(20), @data bit;
    SELECT @class = class, @data = requires_data_check
    FROM $(SchemaName).column_type_change(
        N'varchar', 50, NULL, NULL,
        N'varchar', 100, NULL, NULL);

    EXEC Assert.Equals @class, N'widening';
    EXEC Assert.Equals @data,  0;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_varchar_to_max_is_widening
AS
BEGIN
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'varchar', 100, NULL, NULL,
        N'varchar', -1, NULL, NULL);

    EXEC Assert.Equals @class, N'widening';
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_decimal_int_digits_preserved_is_widening
AS
BEGIN
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'decimal', 9, 18, 2,
        N'decimal', 9, 19, 2);

    EXEC Assert.Equals @class, N'widening';
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_datetime2_scale_increase_is_widening
AS
BEGIN
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'datetime2', 7, NULL, 3,
        N'datetime2', 8, NULL, 7);

    EXEC Assert.Equals @class, N'widening';
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_varchar_to_nvarchar_is_widening
AS
BEGIN
    DECLARE @class nvarchar(20), @coll bit;
    SELECT @class = class, @coll = requires_collation_check
    FROM $(SchemaName).column_type_change(
        N'varchar', 100, NULL, NULL,
        N'nvarchar', 200, NULL, NULL);

    EXEC Assert.Equals @class, N'widening';
    EXEC Assert.Equals @coll,  1;
END
GO

-- ---------------------------------------------
-- Narrowing
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.column_type_change_bigint_to_int_is_narrowing
AS
BEGIN
    DECLARE @class nvarchar(20), @data bit;
    SELECT @class = class, @data = requires_data_check
    FROM $(SchemaName).column_type_change(
        N'bigint', 8, 19, 0,
        N'int', 4, 10, 0);

    EXEC Assert.Equals @class, N'narrowing';
    EXEC Assert.Equals @data,  1;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_varchar_shrink_is_narrowing
AS
BEGIN
    DECLARE @class nvarchar(20), @data bit;
    SELECT @class = class, @data = requires_data_check
    FROM $(SchemaName).column_type_change(
        N'varchar', 100, NULL, NULL,
        N'varchar', 50, NULL, NULL);

    EXEC Assert.Equals @class, N'narrowing';
    EXEC Assert.Equals @data,  1;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_varchar_max_to_fixed_is_narrowing
AS
BEGIN
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'varchar', -1, NULL, NULL,
        N'varchar', 8000, NULL, NULL);

    EXEC Assert.Equals @class, N'narrowing';
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_decimal_integer_digits_shrink_is_narrowing
AS
BEGIN
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'decimal', 9, 18, 2,
        N'decimal', 9, 18, 3);

    EXEC Assert.Equals @class, N'narrowing';
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_datetime2_scale_decrease_is_narrowing
AS
BEGIN
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'datetime2', 8, NULL, 7,
        N'datetime2', 7, NULL, 3);

    EXEC Assert.Equals @class, N'narrowing';
END
GO

-- ---------------------------------------------
-- Lateral
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.column_type_change_nvarchar_to_varchar_is_lateral
AS
BEGIN
    DECLARE @class nvarchar(20), @data bit, @coll bit;
    SELECT @class = class, @data = requires_data_check, @coll = requires_collation_check
    FROM $(SchemaName).column_type_change(
        N'nvarchar', 200, NULL, NULL,
        N'varchar', 100, NULL, NULL);

    EXEC Assert.Equals @class, N'lateral';
    EXEC Assert.Equals @data,  1;
    EXEC Assert.Equals @coll,  1;
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_nchar_to_char_is_lateral
AS
BEGIN
    DECLARE @class nvarchar(20), @coll bit;
    SELECT @class = class, @coll = requires_collation_check
    FROM $(SchemaName).column_type_change(
        N'nchar', 20, NULL, NULL,
        N'char', 10, NULL, NULL);

    EXEC Assert.Equals @class, N'lateral';
    EXEC Assert.Equals @coll,  1;
END
GO

-- ---------------------------------------------
-- Forbidden
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.column_type_change_int_to_varchar_is_forbidden
AS
BEGIN
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'int', 4, 10, 0,
        N'varchar', 20, NULL, NULL);

    EXEC Assert.Equals @class, N'forbidden';
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_datetime_to_int_is_forbidden
AS
BEGIN
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'datetime', 8, NULL, 3,
        N'int', 4, 10, 0);

    EXEC Assert.Equals @class, N'forbidden';
END
GO

CREATE OR ALTER PROCEDURE sstr.column_type_change_char_to_nvarchar_is_forbidden_when_shrinks
AS
BEGIN
    -- char(100) -> nvarchar(50): 100 chars do not fit in 50 chars
    DECLARE @class nvarchar(20);
    SELECT @class = class
    FROM $(SchemaName).column_type_change(
        N'char', 100, NULL, NULL,
        N'nvarchar', 100, NULL, NULL);   -- nvarchar(50) = 100 bytes

    EXEC Assert.Equals @class, N'narrowing';
END
GO