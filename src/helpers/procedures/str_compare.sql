
-- =============================================
-- $(SchemaName).str_compare
-- =============================================
-- Compares two strings using the specified collation.
--
-- @collation  The collation used for comparison.
-- @result     -1 = @a is less than @b
--              0 = @a equals @b
--              1 = @a is greater than @b
--
-- NULL is treated as an empty string.
--
-- Note:
-- SQL Server collation comparison semantics apply.
-- In particular, trailing spaces are ignored during
-- string equality comparisons.
-- =============================================

create or alter procedure $(SchemaName).str_compare
(
    @a          nvarchar(max),
    @b          nvarchar(max),
    @collation  sysname,
    @result     int output
)
as
begin
    set nocount on;

    set @result = null;

    -- Validate the collation name.
    if @collation is null
       or not exists
       (
           select 1
           from sys.fn_helpcollations()
           where name = @collation
       )
    begin
        throw 50001, 'Invalid collation name.', 1;
    end;

    -- Treat NULL as an empty string.
    set @a = isnull(@a, n'');
    set @b = isnull(@b, n'');

    declare @sql nvarchar(max);

    set @sql =
        n'select @result =
            case
                when @a collate ' + quotename(@collation) + n'
                   = @b collate ' + quotename(@collation) + n' then 0
                when @a collate ' + quotename(@collation) + n'
                   < @b collate ' + quotename(@collation) + n' then -1
                else 1
            end;';

    exec sys.sp_executesql
        @sql,
        n'@a nvarchar(max), @b nvarchar(max), @result int output',
        @a = @a,
        @b = @b,
        @result = @result output;
end
go
