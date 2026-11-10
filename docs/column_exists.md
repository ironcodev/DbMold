# `mold.column_exists`

Returns whether a column exists on a user table.

---

## Signature

```sql
CREATE OR ALTER FUNCTION mold.column_exists
(
    @name nvarchar(776)
)
RETURNS bit
```

| Parameter | Type             | Description                                  |
|-----------|------------------|----------------------------------------------|
| `@name`   | `nvarchar(776)`  | Qualified column name. See "Input formats".   |

**Returns:** `bit` — `1` if the column exists on a user table, `0` otherwise.

---

## Input formats

The last dot separates the column from the object. Everything before it is treated as the table name (and may itself contain dots).

| Input                              | Resolves to                          |
|------------------------------------|--------------------------------------|
| `'Products.Id'`                    | `dbo.Products.Id`                    |
| `'sales.Products.Id'`              | `sales.Products.Id`                  |
| `'db.sales.Products.Id'`           | `db.sales.Products.Id`               |
| `'[sales].[My.Table].[My.Column]'` | `sales.[My.Table].[My.Column]`       |

### Default schema

If the object part has no dot, it is resolved against the **`dbo`** schema — **not** the caller's `DEFAULT_SCHEMA`.

### Quoted names

Bracketed identifiers work for both the object and the column part. `[sales].[My.Table].[My.Column]` is parsed correctly.

---

## Examples

```sql
IF mold.column_exists('Products.Id') = 1
    PRINT 'Column exists.';

IF mold.column_exists('sales.Products.DiscountPrice') = 1
    PRINT 'Column exists.';
```

---

## Behavior details

| Situation                                    | Result |
|----------------------------------------------|--------|
| `@name` is `NULL`                            | `0`    |
| `@name` is empty or whitespace-only          | `0`    |
| `@name` contains no dot                      | `0`    |
| Object part starts with `#`                  | `0` (temp tables are not supported) |
| Object does not exist                        | `0`    |
| Object is a view                             | `0`    |
| Column does not exist on the object          | `0`    |

---

## Limitations

- **Temp tables are not supported.** SQL Server does not allow a UDF to resolve temporary tables (`#x`, `##x`). Calls that reference a temp table always return `0`.
- Only **user tables** are recognized as the object part. Views, synonyms, and system tables return `0`.
- The column name must be a single segment; a bare `Column` (without a table) is not supported.

---

## Idempotency

Pure read. Safe to call any number of times.

---

## Related

- [`mold.table_exists`](table_exists.md) — check a table
- [`mold.default_exists`](default_exists.md) — check a default constraint
- [`mold.create_column`](create_column.md) — create or sync a column
