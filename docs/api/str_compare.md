# str_compare

## Usage examples
### Case-insensitive comparison
```sql
declare @result int;

exec $(SchemaName).str_compare
    @a = n'abc',
    @b = n'ABC',
    @collation = n'Latin1_General_CI_AS',
    @result = @result output;

select @result; -- 0
```

### Case-sensitive comparison
```sql
declare @result int;

exec $(SchemaName).str_compare
    @a = n'abc',
    @b = n'ABC',
    @collation = n'Latin1_General_CS_AS',
    @result = @result output;

select @result; -- -1
```
