# str_compare

## Usage examples
### Case-insensitive comparison
```sql
declare @result int;

exec $(SchemaName).str_compare
    @a = N'abc',
    @b = N'ABC',
    @collation = N'Latin1_General_CI_AS',
    @result = @result output;

select @result; -- 0
```

### Case-sensitive comparison
```sql
declare @result int;

exec $(SchemaName).str_compare
    @a = N'abc',
    @b = N'ABC',
    @collation = N'Latin1_General_CS_AS',
    @result = @result output;

select @result; -- -1
```
