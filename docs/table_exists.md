# `mold.table_exists`

> Use `x` for schema if you used `Install-x.sql`.

Returns whether a table exists in the current database (or in `tempdb`
for temporary tables).

---

## Signature

```sql
CREATE OR ALTER FUNCTION mold.table_exists
(
    @name nvarchar(776)
)
RETURNS bit
```

| Parameter | Type             | Description                              |
|-----------|------------------|------------------------------------------|
| `@name`   | `nvarchar(776)`  | Name of the table. See "Input formats".  |

**Returns:** `bit` — `1` if the table exists, `0` otherwise.

---

## Input formats

| Input                          | Resolves to                          |
|--------------------------------|--------------------------------------|
| `'Products'`                   | `dbo.Products`                       |
| `'sales.Products'`             | `sales.Products`                     |
| `'db.sales.Products'`          | `db.sales.Products`                  |
| `'#tmp1'`                      | `tempdb..#tmp1` (local temp table)   |
| `'##tmp2'`                     | `tempdb..##tmp2` (global temp table) |
| `'[sales].[My.Table]'`         | `sales.[My.Table]`                   |

### Default schema

If `@name` does not contain a dot, it is resolved against the **`dbo`**
schema — **not** against the caller's `DEFAULT_SCHEMA`.

This is intentional:

- `DEFAULT_SCHEMA` is per-user and varies between environments.
- Relying on it would make migration scripts behave differently in
  development and production.
- `dbo` is predictable and portable.

To target a different schema, qualify the name explicitly
(`'sales.Products'`).

### Whitespace

Leading and trailing whitespace is trimmed before resolution.

### Quoted names

Identifiers wrapped in `[...]` are handled natively by `OBJECT_ID`, so
names that contain dots (e.g. `[sales].[My.Table]`) work as expected.

---

## What counts as a "table"

`mold.table_exists` returns `1` only for **user tables**
(`sys.objects.type = 'U'`). It returns `0` for:

- views
- synonyms
- stored procedures
- functions
- system tables

Temporary tables (`#...` and `##...`) are user tables in `tempdb` and
are therefore recognized.

---

## Examples

### Check a table in the default schema

```sql
IF mold.table_exists('Products') = 1
    PRINT 'Table exists.';
```

### Check a table in a custom schema

```sql
IF mold.table_exists('sales.Products') = 1
    PRINT 'Table exists.';
```

### Check a local temp table

```sql
IF mold.table_exists('#tmp1') = 1
    PRINT 'Temp table exists.';
```

### Check a global temp table

```sql
IF mold.table_exists('##tmp2') = 1
    PRINT 'Global temp table exists.';
```

### Use it as a guard before dropping

```sql
IF mold.table_exists('sales.Products') = 1
    DROP TABLE sales.Products;
```

### Use it in a migration script

```sql
IF mold.table_exists('sales.Products') = 1
BEGIN
    EXEC USP_Sales_init_products;
END
```

---

## Behavior details

| Situation                            | Result |
|--------------------------------------|--------|
| `@name` is `NULL`                    | `0`    |
| `@name` is empty or whitespace-only  | `0`    |
| Name has leading/trailing spaces     | trimmed, then resolved |
| Name has no dot                      | resolved as `dbo.<name>` |
| Name starts with `#`                 | resolved in `tempdb` |
| Name starts with `##`                | resolved in `tempdb` |
| Object exists but is a view          | `0`    |
| Object exists but is a synonym       | `0`    |
| Name exists in another database      | resolved if `db.schema.name` form is used |

---

## Idempotency

`mold.table_exists` is a **pure read** — it does not modify anything.
It is safe to call any number of times, from any context, with any
input.

---

## Limitations

- Only user tables are recognized. Views, synonyms, and other object
  types return `0`. (A future `mold.object_exists` may cover the general
  case.)
- Cross-database checks work only if the caller has permission to see
  the target database. If not, `OBJECT_ID` returns `NULL` and the
  function returns `0`.
- The function uses `OBJECT_ID` internally, which performs a metadata
  lookup. This is cheap, but it is still a lookup — avoid calling it in
  tight loops over thousands of names.

---

## Related

- [`mold.column_exists`](column_exists.md) — check a column
- [`mold.default_exists`](default_exists.md) — check a default constraint
- [`mold.create_table`](create_table.md) — create or sync a table
- [`mold.drop_table`](drop_table.md) — drop a table if it exists
