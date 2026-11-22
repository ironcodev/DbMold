-- =============================================
-- $(SchemaName).hex_to_varbinary
-- =============================================
-- Decodes a hexadecimal string to varbinary.
--
-- The input is the hex digits without the 0x prefix (the format produced
-- by varbinary_to_hex). Case-insensitive: 'AB' and 'ab' decode to the
-- same byte. An odd number of hex digits is rejected by xs:hexBinary.
--
-- Examples:
--   hex_to_varbinary(N'AB')      -> 0xAB
--   hex_to_varbinary(N'ABCD')    -> 0xABCD
--   hex_to_varbinary(N'abcd')    -> 0xABCD
--   hex_to_varbinary(N'')        -> 0x
--   hex_to_varbinary(NULL)       -> NULL
--   hex_to_varbinary(N'ABC')     -> error: xs:hexBinary requires an even number of digits
-- =============================================
create or alter function $(SchemaName).hex_to_varbinary
(
    @s nvarchar(max)
)
returns varbinary(max)
as
begin
    if @s is null return null;

    return cast(N'' as xml).value(
        'xs:hexBinary(sql:variable("@s"))',
        'varbinary(max)'
    );
end
go