/* --- HAPPY PATH: Integers --- */

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_true_for_positive_integer
AS
BEGIN
    DECLARE @r bit = $(SchemaName).is_decimal(N'123');
    EXEC Assert.Equals @r, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_true_for_zero
AS
BEGIN
    DECLARE @r bit = $(SchemaName).is_decimal(N'0');
    EXEC Assert.Equals @r, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_true_for_negative_integer
AS
BEGIN
    -- Assuming is_integer handles the negative sign
    DECLARE @r bit = $(SchemaName).is_decimal(N'-123');
    EXEC Assert.Equals @r, 1;
END
GO

/* --- HAPPY PATH: Decimals --- */

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_true_for_standard_decimal
AS
BEGIN
    DECLARE @r bit = $(SchemaName).is_decimal(N'123.45');
    EXEC Assert.Equals @r, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_true_for_decimal_with_leading_zero
AS
BEGIN
    DECLARE @r bit = $(SchemaName).is_decimal(N'0.5');
    EXEC Assert.Equals @r, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_true_for_negative_decimal
AS
BEGIN
    DECLARE @r bit = $(SchemaName).is_decimal(N'-12.34');
    EXEC Assert.Equals @r, 1;
END
GO

/* --- EDGE CASES: Dot Placement --- */

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_true_for_leading_dot
AS
BEGIN
    -- Logic check: @left will be '', @right will be '5'. calls is_integer('5')
    DECLARE @r bit = $(SchemaName).is_decimal(N'.5');
    EXEC Assert.Equals @r, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_true_for_trailing_dot
AS
BEGIN
    -- Logic check: @left will be '10', @right will be ''. calls is_integer('10')
    DECLARE @r bit = $(SchemaName).is_decimal(N'10.');
    EXEC Assert.Equals @r, 1;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_false_for_single_dot
AS
BEGIN
    -- Logic check: @left='', @right=''. returns 0.
    DECLARE @r bit = $(SchemaName).is_decimal(N'.');
    EXEC Assert.Equals @r, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_false_for_multiple_dots
AS
BEGIN
    -- Logic check: charindex finds first dot. @left='1', @right='2.3'. 
    -- is_integer('2.3') should be false.
    DECLARE @r bit = $(SchemaName).is_decimal(N'1.2.3');
    EXEC Assert.Equals @r, 0;
END
GO

/* --- NEGATIVE PATH: Invalid Strings --- */

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_false_for_empty_string
AS
BEGIN
    DECLARE @r bit = $(SchemaName).is_decimal(N'');
    EXEC Assert.Equals @r, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_false_for_whitespace
AS
BEGIN
    -- Depends on is_empty behavior, usually whitespace is not 'empty' but not a decimal
    DECLARE @r bit = $(SchemaName).is_decimal(N'   ');
    EXEC Assert.Equals @r, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_false_for_alphabetic_string
AS
BEGIN
    DECLARE @r bit = $(SchemaName).is_decimal(N'abc');
    EXEC Assert.Equals @r, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_false_for_mixed_alphanumeric
AS
BEGIN
    DECLARE @r bit = $(SchemaName).is_decimal(N'12a.5');
    EXEC Assert.Equals @r, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_false_for_string_with_commas
AS
BEGIN
    -- Commas are usually not allowed in standard decimal parsing unless handled
    DECLARE @r bit = $(SchemaName).is_decimal(N'1,234.56');
    EXEC Assert.Equals @r, 0;
END
GO

CREATE OR ALTER PROCEDURE sstr.is_decimal_returns_false_for_scientific_notation
AS
BEGIN
    -- Standard is_integer usually fails on 'e'
    DECLARE @r bit = $(SchemaName).is_decimal(N'1e10');
    EXEC Assert.Equals @r, 0;
END
GO
