-- =============================================
-- $(SchemaName).trim_both
-- =============================================
-- Removes every leading and trailing character in @chars from @s.
-- Equivalent to TRIM(@chars FROM @s) on SQL Server 2022, and to
-- $(SchemaName).trim_left($(SchemaName).trim_right(@s, @chars), @chars)
-- on older versions.
-- =============================================
create or alter function $(SchemaName).trim_both
(
    @s     nvarchar(max),
    @chars nvarchar(100),
    @case_insensitive bit
)
returns nvarchar(max)
as
begin
    return $(SchemaName).trim_left($(SchemaName).trim_right(@s, @chars, @case_insensitive), @chars, @case_insensitive);
end