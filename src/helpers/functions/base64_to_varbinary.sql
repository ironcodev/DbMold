-- =============================================
-- $(SchemaName).base64_to_varbinary
-- =============================================
-- Decodes a base64 string to varbinary.
--
-- Examples:
--   base64_to_varbinary(N'aGVsbG8=') -> 0x68656C6C6F
--   base64_to_varbinary(N'')         -> 0x
--   base64_to_varbinary(NULL)        -> NULL
-- =============================================
CREATE OR ALTER FUNCTION [$(SchemaName)].[base64_to_varbinary]
(
	 @s		VARCHAR(MAX)
) 
RETURNS VARBINARY(MAX)
AS
BEGIN
	if @s is null return null;

    -- SQL Server 2022+: return cast(N'' as xml).value('xs:base64Binary(sql:variable("@s"))', 'varbinary(max)');
    return cast(N'' as xml).value('xs:base64Binary(sql:variable("@s"))', 'varbinary(max)');
END

GO