-- =============================================
-- Unit tests for $(SchemaName).parse_column_type
-- Run with:  npx sstr run
-- =============================================

-- =============================================
-- Warm-up / cool-down for the parse_column_type suite
-- =============================================

CREATE OR ALTER PROCEDURE dbo.parse_column_type_setup
AS
BEGIN
    -- Fail fast with a clear message if the TVF is missing or broken.
    IF OBJECT_ID(N'$(SchemaName).parse_column_type', N'IF') IS NULL
        THROW 50000, N'parse_column_type TVF is missing; cannot run suite.', 1;

    -- Smoke-call it once so a compile-time breakage surfaces here, not in every test.
    DECLARE @ok bit;
    SELECT @ok = is_valid FROM $(SchemaName).parse_column_type(N'int');
    IF @ok IS NULL
        THROW 50001, N'parse_column_type returned no row for N''int''; cannot run suite.', 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.parse_column_type_teardown
AS
BEGIN
    -- Pure-function suite: nothing to clean up.
    -- Kept for symmetry and so the cooldown script can drop it explicitly.
    RETURN;
END
GO
-- =============================================
-- Tests for $(SchemaName).parse_column_type
-- =============================================

-- ---------------------------------------------
-- Unknown / garbage input
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_unknown_type_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit, validation_error nvarchar(max));
    INSERT @r SELECT is_valid, validation_error
               FROM $(SchemaName).parse_column_type(N'not_a_real_type');

    DECLARE @valid bit, @err nvarchar(max);
    SELECT @valid = is_valid, @err = validation_error FROM @r;

    EXEC Assert.Equals       @valid, 0;
    EXEC Assert.MaxNotEquals @err, NULL;

    DECLARE @ok bit = CASE WHEN @err LIKE N'%Unknown type name%' THEN 1 ELSE 0 END;
    EXEC Assert.IsTrue @ok;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_empty_string_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit, validation_error nvarchar(max));
    INSERT @r SELECT is_valid, validation_error
               FROM $(SchemaName).parse_column_type(N'');

    DECLARE @valid bit, @err nvarchar(max);
    SELECT @valid = is_valid, @err = validation_error FROM @r;

    EXEC Assert.Equals       @valid, 0;
    EXEC Assert.MaxNotEquals @err, NULL;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_null_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit, validation_error nvarchar(max));
    INSERT @r SELECT is_valid, validation_error
               FROM $(SchemaName).parse_column_type(NULL);

    DECLARE @valid bit, @err nvarchar(max);
    SELECT @valid = is_valid, @err = validation_error FROM @r;

    EXEC Assert.Equals       @valid, 0;
    EXEC Assert.MaxNotEquals @err, NULL;
END
GO

-- ---------------------------------------------
-- Fixed-width types with no arguments
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_int_defaults
AS
BEGIN
    DECLARE @r TABLE (
        type_name nvarchar(500), normalized_type nvarchar(4000),
        system_type_id int, byte_length int, precision int, scale int,
        is_valid bit, is_max bit, validation_error nvarchar(max)
    );
    INSERT @r
    SELECT type_name, normalized_type, system_type_id, byte_length,
           precision, scale, is_valid, is_max, validation_error
    FROM $(SchemaName).parse_column_type(N'int');

    DECLARE @type_name nvarchar(500), @norm nvarchar(4000),
            @sysid int, @bytes int, @prec int, @scale int,
            @valid bit, @is_max bit, @err nvarchar(max);
    SELECT @type_name = type_name, @norm = normalized_type,
           @sysid = system_type_id, @bytes = byte_length,
           @prec = precision, @scale = scale,
           @valid = is_valid, @is_max = is_max, @err = validation_error
    FROM @r;

    EXEC Assert.Equals       @valid,   1;
    EXEC Assert.MaxEquals    @err,     NULL;
    EXEC Assert.MaxNotEquals @type_name, NULL;
    EXEC Assert.MaxEquals    @type_name, N'int';
    EXEC Assert.MaxEquals    @norm,      N'int';
    EXEC Assert.Equals       @sysid,     56;
    EXEC Assert.IsGT         @sysid,     0;
    EXEC Assert.Equals       @bytes,     4;
    EXEC Assert.IsGTE        @bytes,     1;
    EXEC Assert.Equals       @is_max,    0;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_bigint_defaults
AS
BEGIN
    DECLARE @r TABLE (byte_length int, system_type_id int, is_valid bit);
    INSERT @r SELECT byte_length, system_type_id, is_valid
               FROM $(SchemaName).parse_column_type(N'bigint');

    DECLARE @bytes int, @sysid int, @valid bit;
    SELECT @bytes = byte_length, @sysid = system_type_id, @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 1;
    EXEC Assert.Equals @bytes, 8;
    EXEC Assert.Equals @sysid, 127;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_bit_defaults
AS
BEGIN
    DECLARE @r TABLE (byte_length int, is_valid bit);
    INSERT @r SELECT byte_length, is_valid
               FROM $(SchemaName).parse_column_type(N'bit');

    DECLARE @bytes int, @valid bit;
    SELECT @bytes = byte_length, @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 1;
    EXEC Assert.Equals @bytes, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_uniqueidentifier_defaults
AS
BEGIN
    DECLARE @r TABLE (byte_length int, is_valid bit);
    INSERT @r SELECT byte_length, is_valid
               FROM $(SchemaName).parse_column_type(N'uniqueidentifier');

    DECLARE @bytes int, @valid bit;
    SELECT @bytes = byte_length, @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 1;
    EXEC Assert.Equals @bytes, 16;
END
GO

-- ---------------------------------------------
-- Character types
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_varchar_length
AS
BEGIN
    DECLARE @r TABLE (
        type_name nvarchar(500), char_length int, byte_length int,
        normalized_type nvarchar(4000), is_valid bit, is_max bit,
        validation_error nvarchar(max)
    );
    INSERT @r
    SELECT type_name, char_length, byte_length, normalized_type, is_valid, is_max, validation_error
    FROM $(SchemaName).parse_column_type(N'varchar(100)');

    DECLARE @tn nvarchar(500), @cl int, @bl int,
            @norm nvarchar(4000), @valid bit, @is_max bit, @err nvarchar(max);
    SELECT @tn = type_name, @cl = char_length, @bl = byte_length,
           @norm = normalized_type, @valid = is_valid, @is_max = is_max, @err = validation_error
    FROM @r;

    EXEC Assert.Equals    @valid,  1;
    EXEC Assert.MaxEquals @err,    NULL;
    EXEC Assert.MaxEquals @tn,     N'varchar';
    EXEC Assert.Equals    @cl,     100;
    EXEC Assert.IsGTE     @cl,     1;
    EXEC Assert.Equals    @bl,     100;
    EXEC Assert.MaxEquals @norm,   N'varchar(100)';
    EXEC Assert.Equals    @is_max, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_varchar_max
AS
BEGIN
    DECLARE @r TABLE (char_length int, byte_length int, is_max bit, is_valid bit);
    INSERT @r SELECT char_length, byte_length, is_max, is_valid
               FROM $(SchemaName).parse_column_type(N'varchar(max)');

    DECLARE @cl int, @bl int, @is_max bit, @valid bit;
    SELECT @cl = char_length, @bl = byte_length,
           @is_max = is_max, @valid = is_valid
    FROM @r;

    EXEC Assert.Equals @valid,  1;
    EXEC Assert.Equals @cl,     -1;
    EXEC Assert.Equals @bl,     -1;
    EXEC Assert.Equals @is_max, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_nvarchar_doubles_bytes
AS
BEGIN
    DECLARE @r TABLE (char_length int, byte_length int, is_valid bit);
    INSERT @r SELECT char_length, byte_length, is_valid
               FROM $(SchemaName).parse_column_type(N'nvarchar(100)');

    DECLARE @cl int, @bl int, @valid bit;
    SELECT @cl = char_length, @bl = byte_length, @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 1;
    EXEC Assert.Equals @cl,    100;
    EXEC Assert.Equals @bl,    200;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_nvarchar_max
AS
BEGIN
    DECLARE @r TABLE (char_length int, byte_length int, is_max bit, is_valid bit);
    INSERT @r SELECT char_length, byte_length, is_max, is_valid
               FROM $(SchemaName).parse_column_type(N'nvarchar(max)');

    DECLARE @cl int, @bl int, @is_max bit, @valid bit;
    SELECT @cl = char_length, @bl = byte_length,
           @is_max = is_max, @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid,  1;
    EXEC Assert.Equals @cl,     -1;
    EXEC Assert.Equals @bl,     -1;
    EXEC Assert.Equals @is_max, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_char_default_length
AS
BEGIN
    DECLARE @r TABLE (type_name nvarchar(500), char_length int, is_valid bit);
    INSERT @r SELECT type_name, char_length, is_valid
               FROM $(SchemaName).parse_column_type(N'char');

    DECLARE @tn nvarchar(500), @cl int, @valid bit;
    SELECT @tn = type_name, @cl = char_length, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'char';
    EXEC Assert.Equals    @cl,    1;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_varchar_zero_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit, validation_error nvarchar(max));
    INSERT @r SELECT is_valid, validation_error
               FROM $(SchemaName).parse_column_type(N'varchar(0)');

    DECLARE @valid bit, @err nvarchar(max);
    SELECT @valid = is_valid, @err = validation_error FROM @r;

    EXEC Assert.Equals       @valid, 0;
    EXEC Assert.MaxNotEquals @err, NULL;

    DECLARE @ok bit = CASE WHEN @err LIKE N'%Invalid argument%' THEN 1 ELSE 0 END;
    EXEC Assert.IsTrue @ok;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_varchar_negative_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit);
    INSERT @r SELECT is_valid FROM $(SchemaName).parse_column_type(N'varchar(-5)');

    DECLARE @valid bit;
    SELECT @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_varchar_non_numeric_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit);
    INSERT @r SELECT is_valid FROM $(SchemaName).parse_column_type(N'varchar(abc)');

    DECLARE @valid bit;
    SELECT @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 0;
END
GO

-- ---------------------------------------------
-- Decimal / numeric
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_decimal_precision_scale
AS
BEGIN
    DECLARE @r TABLE (
        type_name nvarchar(500), precision int, scale int,
        normalized_type nvarchar(4000), is_valid bit, validation_error nvarchar(max)
    );
    INSERT @r
    SELECT type_name, precision, scale, normalized_type, is_valid, validation_error
    FROM $(SchemaName).parse_column_type(N'decimal(18,2)');

    DECLARE @tn nvarchar(500), @p int, @s int,
            @norm nvarchar(4000), @valid bit, @err nvarchar(max);
    SELECT @tn = type_name, @p = precision, @s = scale,
           @norm = normalized_type, @valid = is_valid, @err = validation_error FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @err,   NULL;
    EXEC Assert.MaxEquals @tn,    N'decimal';
    EXEC Assert.Equals    @p,     18;
    EXEC Assert.Equals    @s,     2;
    EXEC Assert.IsLTE     @s,     @p;
    EXEC Assert.MaxEquals @norm,  N'decimal(18,2)';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_numeric_alias
AS
BEGIN
    DECLARE @r TABLE (type_name nvarchar(500), precision int, scale int, is_valid bit);
    INSERT @r SELECT type_name, precision, scale, is_valid
               FROM $(SchemaName).parse_column_type(N'numeric(10,4)');

    DECLARE @tn nvarchar(500), @p int, @s int, @valid bit;
    SELECT @tn = type_name, @p = precision, @s = scale, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'numeric';
    EXEC Assert.Equals    @p,     10;
    EXEC Assert.Equals    @s,     4;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_decimal_default_scale
AS
BEGIN
    DECLARE @r TABLE (precision int, scale int, normalized_type nvarchar(4000));
    INSERT @r SELECT precision, scale, normalized_type
               FROM $(SchemaName).parse_column_type(N'decimal(10)');

    DECLARE @p int, @s int, @norm nvarchar(4000);
    SELECT @p = precision, @s = scale, @norm = normalized_type FROM @r;

    EXEC Assert.Equals    @p,    10;
    EXEC Assert.Equals    @s,    0;
    EXEC Assert.MaxEquals @norm, N'decimal(10,0)';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_decimal_scale_gt_precision_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit, validation_error nvarchar(max));
    INSERT @r SELECT is_valid, validation_error
               FROM $(SchemaName).parse_column_type(N'decimal(5,10)');

    DECLARE @valid bit, @err nvarchar(max);
    SELECT @valid = is_valid, @err = validation_error FROM @r;

    EXEC Assert.Equals       @valid, 0;
    EXEC Assert.MaxNotEquals @err, NULL;

    DECLARE @ok bit = CASE WHEN @err LIKE N'%Invalid argument%' THEN 1 ELSE 0 END;
    EXEC Assert.IsTrue @ok;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_decimal_precision_gt_38_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit);
    INSERT @r SELECT is_valid FROM $(SchemaName).parse_column_type(N'decimal(39,2)');

    DECLARE @valid bit;
    SELECT @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 0;
END
GO

-- ---------------------------------------------
-- Temporal types
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_datetime2_precision
AS
BEGIN
    DECLARE @r TABLE (
        type_name nvarchar(500), fractional_scale int,
        normalized_type nvarchar(4000), is_valid bit
    );
    INSERT @r
    SELECT type_name, fractional_scale, normalized_type, is_valid
    FROM $(SchemaName).parse_column_type(N'datetime2(3)');

    DECLARE @tn nvarchar(500), @fs int, @norm nvarchar(4000), @valid bit;
    SELECT @tn = type_name, @fs = fractional_scale,
           @norm = normalized_type, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'datetime2';
    EXEC Assert.Equals    @fs,    3;
    EXEC Assert.IsBetween @fs,    0, 7;
    EXEC Assert.MaxEquals @norm,  N'datetime2(3)';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_datetime2_default_precision
AS
BEGIN
    DECLARE @r TABLE (fractional_scale int, is_valid bit);
    INSERT @r SELECT fractional_scale, is_valid
               FROM $(SchemaName).parse_column_type(N'datetime2');

    DECLARE @fs int, @valid bit;
    SELECT @fs = fractional_scale, @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 1;
    EXEC Assert.Equals @fs,    7;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_datetime2_precision_9_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit);
    INSERT @r SELECT is_valid FROM $(SchemaName).parse_column_type(N'datetime2(9)');

    DECLARE @valid bit;
    SELECT @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_time_precision
AS
BEGIN
    DECLARE @r TABLE (fractional_scale int, is_valid bit);
    INSERT @r SELECT fractional_scale, is_valid
               FROM $(SchemaName).parse_column_type(N'time(0)');

    DECLARE @fs int, @valid bit;
    SELECT @fs = fractional_scale, @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 1;
    EXEC Assert.Equals @fs,    0;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_datetime_no_args
AS
BEGIN
    DECLARE @r TABLE (type_name nvarchar(500), is_valid bit);
    INSERT @r SELECT type_name, is_valid
               FROM $(SchemaName).parse_column_type(N'datetime');

    DECLARE @tn nvarchar(500), @valid bit;
    SELECT @tn = type_name, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'datetime';
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_datetime_with_args_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit, validation_error nvarchar(max));
    INSERT @r SELECT is_valid, validation_error
               FROM $(SchemaName).parse_column_type(N'datetime(3)');

    DECLARE @valid bit, @err nvarchar(max);
    SELECT @valid = is_valid, @err = validation_error FROM @r;

    EXEC Assert.Equals       @valid, 0;
    EXEC Assert.MaxNotEquals @err, NULL;

    DECLARE @ok bit = CASE WHEN @err LIKE N'%Invalid argument%' THEN 1 ELSE 0 END;
    EXEC Assert.IsTrue @ok;
END
GO

-- ---------------------------------------------
-- Non-argument types receiving arguments
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_int_with_args_is_invalid
AS
BEGIN
    DECLARE @r TABLE (is_valid bit, validation_error nvarchar(max));
    INSERT @r SELECT is_valid, validation_error
               FROM $(SchemaName).parse_column_type(N'int(11)');

    DECLARE @valid bit, @err nvarchar(max);
    SELECT @valid = is_valid, @err = validation_error FROM @r;

    EXEC Assert.Equals       @valid, 0;
    EXEC Assert.MaxNotEquals @err, NULL;
END
GO

-- ---------------------------------------------
-- Whitespace / case / brackets
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_leading_trailing_whitespace
AS
BEGIN
    DECLARE @r TABLE (type_name nvarchar(500), char_length int, is_valid bit);
    INSERT @r SELECT type_name, char_length, is_valid
               FROM $(SchemaName).parse_column_type(N'   varchar(50)   ');

    DECLARE @tn nvarchar(500), @cl int, @valid bit;
    SELECT @tn = type_name, @cl = char_length, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'varchar';
    EXEC Assert.Equals    @cl,    50;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_uppercase
AS
BEGIN
    DECLARE @r TABLE (type_name nvarchar(500), char_length int, is_valid bit);
    INSERT @r SELECT type_name, char_length, is_valid
               FROM $(SchemaName).parse_column_type(N'VARCHAR(75)');

    DECLARE @tn nvarchar(500), @cl int, @valid bit;
    SELECT @tn = type_name, @cl = char_length, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'varchar';
    EXEC Assert.Equals    @cl,    75;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_internal_spaces
AS
BEGIN
    DECLARE @r TABLE (precision int, scale int, is_valid bit);
    INSERT @r SELECT precision, scale, is_valid
               FROM $(SchemaName).parse_column_type(N'decimal( 18 , 2 )');

    DECLARE @p int, @s int, @valid bit;
    SELECT @p = precision, @s = scale, @valid = is_valid FROM @r;

    EXEC Assert.Equals @valid, 1;
    EXEC Assert.Equals @p,     18;
    EXEC Assert.Equals @s,     2;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_bracketed_base
AS
BEGIN
    DECLARE @r TABLE (type_name nvarchar(500), char_length int, is_valid bit);
    INSERT @r SELECT type_name, char_length, is_valid
               FROM $(SchemaName).parse_column_type(N'[varchar](25)');

    DECLARE @tn nvarchar(500), @cl int, @valid bit;
    SELECT @tn = type_name, @cl = char_length, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'varchar';
    EXEC Assert.Equals    @cl,    25;
END
GO

-- ---------------------------------------------
-- NULL / NOT NULL suffix stripping
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_strips_trailing_not_null
AS
BEGIN
    DECLARE @r TABLE (type_name nvarchar(500), char_length int, is_valid bit);
    INSERT @r SELECT type_name, char_length, is_valid
               FROM $(SchemaName).parse_column_type(N'varchar(100) NOT NULL');

    DECLARE @tn nvarchar(500), @cl int, @valid bit;
    SELECT @tn = type_name, @cl = char_length, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'varchar';
    EXEC Assert.Equals    @cl,    100;
END
GO

CREATE OR ALTER PROCEDURE sstr.parse_column_type_strips_trailing_null
AS
BEGIN
    DECLARE @r TABLE (type_name nvarchar(500), is_valid bit);
    INSERT @r SELECT type_name, is_valid
               FROM $(SchemaName).parse_column_type(N'int NULL');

    DECLARE @tn nvarchar(500), @valid bit;
    SELECT @tn = type_name, @valid = is_valid FROM @r;

    EXEC Assert.Equals    @valid, 1;
    EXEC Assert.MaxEquals @tn,    N'int';
END
GO

-- ---------------------------------------------
-- System type ids (spot-check the family mapping)
-- ---------------------------------------------
CREATE OR ALTER PROCEDURE sstr.parse_column_type_system_type_ids_spot_check
AS
BEGIN
    DECLARE @cases TABLE (input nvarchar(200), expected_sysid int);
    INSERT @cases VALUES
        (N'int',              56),
        (N'bigint',          127),
        (N'smallint',         52),
        (N'tinyint',          48),
        (N'bit',             104),
        (N'varchar(10)',     167),
        (N'nvarchar(10)',    231),
        (N'char(10)',        175),
        (N'decimal(10,2)',   106),
        (N'datetime',         61),
        (N'datetime2(3)',     42),
        (N'uniqueidentifier', 36);

    DECLARE @failures nvarchar(max) = N'';

    DECLARE @input nvarchar(200), @expected int, @actual int;

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT input, expected_sysid FROM @cases ORDER BY expected_sysid;
    OPEN c;
    FETCH NEXT FROM c INTO @input, @expected;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @r TABLE (system_type_id int, is_valid bit);
        INSERT @r SELECT system_type_id, is_valid
                   FROM $(SchemaName).parse_column_type(@input);

        SET @actual = NULL;
        SELECT @actual = system_type_id FROM @r;

        IF @actual IS NULL OR @actual <> @expected
            SET @failures = @failures
                          + CONCAT(N'[', @input, N'] expected sysid ', @expected,
                                   N' but got ', ISNULL(CAST(@actual AS nvarchar(20)), N'NULL'), N'; ');

        FETCH NEXT FROM c INTO @input, @expected;
    END
    CLOSE c;
    DEALLOCATE c;

    EXEC Assert.MaxEquals @failures, N'';
END
GO