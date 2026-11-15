-- =============================================
-- Tests for $(SchemaName)._normalize_default
-- =============================================

CREATE OR ALTER PROCEDURE sstr.normalize_default_should_strip_double_parens
AS
BEGIN
    DECLARE @r nvarchar(4000) = $(SchemaName)._normalize_default(N'((10))');
    EXEC Assert.Equals @r, '10';
END
GO

CREATE OR ALTER PROCEDURE sstr.normalize_default_should_strip_single_parens
AS
BEGIN
    DECLARE @r nvarchar(4000) = $(SchemaName)._normalize_default(N'(0)');
    EXEC Assert.Equals @r, '0';
END
GO

CREATE OR ALTER PROCEDURE sstr.normalize_default_should_preserve_function_call
AS
BEGIN
    DECLARE @r nvarchar(4000) = $(SchemaName)._normalize_default(N'(getdate())');
    EXEC Assert.Equals @r, 'getdate()';
END
GO

CREATE OR ALTER PROCEDURE sstr.normalize_default_should_handle_null
AS
BEGIN
    DECLARE @r nvarchar(4000) = $(SchemaName)._normalize_default(NULL);
    EXEC Assert.IsNull @r;
END
GO

CREATE OR ALTER PROCEDURE sstr.normalize_default_should_trim_whitespace
AS
BEGIN
    DECLARE @r nvarchar(4000) = $(SchemaName)._normalize_default(N'  ((42))  ');
    EXEC Assert.Equals @r, '42';
END
GO