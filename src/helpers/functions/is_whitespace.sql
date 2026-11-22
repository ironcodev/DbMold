-- =============================================
-- $(SchemaName).is_whitespace
-- =============================================
-- Returns 1 if @value consists only of whitespace (space, tab, CR, LF),
-- 0 otherwise. A null value returns 0 (null is not whitespace).
-- An empty string returns 1 (vacuously all-whitespace).
--
-- Examples:
--   is_whitespace(N'   ')      -> 1
--   is_whitespace(N'  a  ')    -> 0
--   is_whitespace(N'')         -> 1
--   is_whitespace(NULL)        -> 0
--   is_whitespace(NCHAR(9))    -> 1
--   is_whitespace(N'a' + NCHAR(10) + N'b') -> 0
-- =============================================
create or alter function $(SchemaName).is_whitespace
(
    @value nvarchar(max)
)
returns bit
as
begin
    if @value is null return 0;

    return case
        when patindex(N'%[^ ' + char(9) + char(10) + char(13) + N']%', @value) = 0 then 1
        else 0
    end;
end
go