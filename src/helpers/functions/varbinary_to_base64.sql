-- =============================================
-- $(SchemaName).varbinary_to_base64
-- =============================================
-- Encodes varbinary to a base64 string.
--
-- Examples:
--   varbinary_to_base64(0x68656C6C6F) -> N'aGVsbG8='
--   varbinary_to_base64(0x)           -> N''
--   varbinary_to_base64(NULL)         -> NULL
-- =============================================
CREATE OR ALTER FUNCTION [$(SchemaName)].[varbinary_to_base64]
(
	 @Value		VARBINARY(MAX)
) 
RETURNS VARCHAR(MAX)
AS
BEGIN
	if @value is null return null;

    return cast(N'' as xml).value('xs:base64Binary(sql:variable("@value"))', 'nvarchar(max)');
END
GO