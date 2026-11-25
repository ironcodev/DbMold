set ansi_nulls on
go

set quoted_identifier on
go
-- =============================================
-- $(SchemaName).varbinary_to_hex
-- =============================================
-- Encodes varbinary to an uppercase hexadecimal string.
--
-- The output is the hex digits without the 0x prefix (the format accepted
-- by hex_to_varbinary). xs:hexBinary emits uppercase; wrap with
-- lower(varbinary_to_hex(@v)) if you need lowercase.
--
-- Examples:
--   varbinary_to_hex(0xAB)     -> N'AB'
--   varbinary_to_hex(0xABCD)   -> N'ABCD'
--   varbinary_to_hex(0x)       -> N''
--   varbinary_to_hex(NULL)     -> NULL
-- =============================================
create or alter function $(SchemaName).varbinary_to_hex
(
    @v varbinary(max)
)
returns nvarchar(max)
as
begin
    if @v is null return null;

    return cast(N'' as xml).value(
        'xs:hexBinary(sql:variable("@v"))',
        'nvarchar(max)'
    );
end
go