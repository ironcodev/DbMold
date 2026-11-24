-- =============================================
-- $(SchemaName).string_equals
-- =============================================
-- Returns 1 if @a and @b are equal under the requested options.
--
-- @trim       1 = trim both values before comparing
-- @ignoreCase 1 = case-insensitive comparison
--             0 = case-sensitive comparison
--
-- Null is treated as the empty string, so string_equals(NULL, '') = 1.
-- That matches the two-value semantics of a string comparison; if a
-- caller needs null to be distinct from '', check @a IS NULL and @b IS
-- NULL before calling.
--
-- Examples:
--   string_equals(N' a ', N'a',   1, 1) -> 1   -- trim + CI
--   string_equals(N'a',   N'A',   0, 1) -> 1
--   string_equals(N'a',   N'A',   0, 0) -> 0
-- =============================================
create or alter function $(SchemaName).string_equals
(
    @a          nvarchar(max),
    @b          nvarchar(max),
    @trim       bit,
    @ignoreCase bit
)
returns bit
as
begin
    return case
        when $(SchemaName).string_compare(@a, @b, @trim, @ignoreCase) = 0
            then 1
        else 0
    end;
end
go