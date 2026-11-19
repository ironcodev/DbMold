create or alter proc $(SchemaName).record_exists(@table sysname, @json nvarchar(max))
as
begin
    set nocount on;

    if $(SchemaName).table_exists(@table) = 0
    begin
        raiserror('record_exists failed: table does not exist', 16, 1);
        return;
    end

    declare @cnt int;

    if @json is null or ltrim(rtrim(@json)) = N'' or ltrim(rtrim(@json)) = N'{}'
    begin
        declare @sql0 nvarchar(max) = N'select @cnt_out = count(*) from ' + @table;
        exec sp_executesql @sql0, N'@cnt_out int output', @cnt output;
    end
    else
    begin
        declare @where nvarchar(max) = N'';
        declare @key sysname, @val nvarchar(max);

        declare cur cursor local fast_forward for
            select [key], [value] from openjson(@json);

        open cur;
        fetch next from cur into @key, @val;
        while @@fetch_status = 0
        begin
            if @where <> N'' set @where += N' and ';

            if @val is null
                set @where += quotename(@key) + N' is null';
            else
                set @where += quotename(@key) + N' = ' + quotename(@val, '''');

            fetch next from cur into @key, @val;
        end
        close cur;
        deallocate cur;

        declare @sql nvarchar(max) =
            N'select @cnt_out = count(*) from ' + @table + N' where ' + @where;
        exec sp_executesql @sql, N'@cnt_out int output', @cnt output;
    end

    if @cnt = 0
        raiserror('record_exists failed: no matching records found', 16, 1);
end
go
