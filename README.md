# DbMold

> **Mold your SQL Server schema — idempotent, forward-only, dependency-free.**

DbMold is a tiny set of T-SQL stored procedures and functions that make
schema changes **safe to run multiple times**. No external tools, no
libraries, no SQLCLR — just `EXEC <schema>.create_column @spec = N'{...}'`.

It is designed for database developers who write deployment scripts and
want to stop re-implementing the same "does this object exist? does it have
the right definition? should I create or alter it?" logic over and over.

---

## Why?

Writing a single idempotent DDL statement in SQL Server is surprisingly
painful. To "just add a column", you must:

1. Check that the table exists.
2. Check that the column does not already exist.
3. If it exists, check that its type and nullability match.
4. Check the default constraint, and its name (which is auto-generated
   and different on every server).
5. Build the right `ALTER` statement.
6. Wrap everything in error handling.

DbMold collapses all of this into a single call:

```sql
EXEC <schema>.create_column @spec = N'{
  "table": "sales.Products",
  "column": "DiscountPrice",
  "type": "int",
  "nullable": true,
  "default":  "0"
}';
```

Run it once, run it a hundred times — the result is the same, and you never
get an error because "the column already exists".

---

## Installation

DbMold ships with two install scripts:

- `dist/install-mold.sql` — creates the `mold` schema (descriptive name).
- `dist/install-m.sql` — creates the `m` schema (shorthand for `mold`,
  the first letter of the project name).

Both expose the same API; only the schema name differs. Pick the one
that fits your preferences:

- Use `mold` if you value readability and brand recognition.
- Use `m` if you prefer a short, memorable prefix — especially useful
  when the package is used heavily and every keystroke counts.

## Features

- **Idempotent**: safe to run repeatedly; no-op when nothing changes.
- **Forward-only**: no `down` scripts. Fix forward with a new migration.
- **Dependency-free**: pure T-SQL, no CLR, no external library.
- **CI/CD friendly**: drop the scripts into any deployment pipeline.
- **JSON specs**: one parameter per procedure, easy to build from any language.
- **Safe**: all identifiers are validated and quoted with `QUOTENAME`.

## Placeholder

All scripts use `$(SchemaName)`. Replace it with `mold` or `m` before running,
or use the provided build scripts:

- `npm run build` → generates `dist/install-<schema>.sql` and `dist/install-x.sql`
- `npm test` → runs tests against both schemas

## API

All objects live in the `mold` schema. Naming follows a simple rule:

| Kind            | Pattern          | Example                  |
|-----------------|------------------|--------------------------|
| Procedure       | `verb_noun`      | `<schema>.create_column`     |
| Predicate (UDF) | `noun_verb`      | `<schema>.column_exists`     |
| Getter (UDF)    | `verb_noun`      | `<schema>.get_default`       |

### Procedures (idempotent)

| Object                          | Purpose                                           |
|---------------------------------|---------------------------------------------------|
| `<schema>.create_table`             | Creates or syncs a table with its columns.          |
| `<schema>.create_column`            | Creates or syncs a column (type, nullability, default). |
| `<schema>.create_foreign_key`       | Creates or syncs a foreign key.                     |
| `<schema>.drop_table`               | Drops a table if it exists.                        |
| `<schema>.drop_column`              | Drops a column if it exists.                       |
| `<schema>.drop_foreign_key`         | Drops a foreign key if it exists.                  |

### Functions

| Object                          | Returns | Purpose                            |
|---------------------------------|---------|------------------------------------|
| `<schema>.table_exists`             | `bit`   | Does the table (or temp table) exist? |
| `<schema>.column_exists`            | `bit`   | Does the column exist?             |
| `<schema>.default_exists`           | `bit`   | Does the column have this default? |
| `<schema>.get_default`              | `nvarchar(max)` | Current default of a column. |
| `<schema>.get_column_info`          | `table` | Type, nullability, default, etc.   |

---

## Examples

### Add a column (idempotent)

```sql
EXEC <schema>.create_column @spec = N'{
  "table": "sales.Products",
  "column": "DiscountPrice",
  "type": "int",
  "nullable": true,
  "default": "0"
}';
```

### Create a table

```sql
EXEC <schema>.create_table @spec = N'{
  "name": "sales.Docs",
  "columns": [
    { "name": "Id", "type": "int", "nullable": false, "identity": true },
    { "name": "Body", "type": "nvarchar(max)", "nullable": true }
  ],
  "textimage": "FLG_BLOB"
}';
```

### Create a foreign key

```sql
EXEC <schema>.create_foreign_key @spec = N'{
  "parent":     "sales.OrderDetails.OrderId",
  "child":      "sales.Orders.Id",
  "deleteRule": "cascade",
  "updateRule": "cascade"
}';
```

### Check existence

```sql
IF <schema>.table_exists('sales.Products') = 1
    PRINT 'Table exists.';

IF <schema>.column_exists('sales.Products.IsShipped') = 1
    PRINT 'Column exists.';
```

### Drop (idempotent)

```sql
EXEC <schema>.drop_column 'sales.Products.IsShipped';
EXEC <schema>.drop_table  'tmp1';
```

---

## Design principles

1. **Idempotency over cleverness.** Every procedure is a no-op when the
   target already matches the spec. No errors, no side effects.
2. **Forward-only.** DbMold does not ship `down` scripts. If a migration
   was wrong, write a new one. This mirrors how mature teams run
   production databases.
3. **No SQLCLR, no external tools.** Everything is T-SQL, deployable into
   any SQL Server instance, including locked-down ones.
4. **Safe dynamic SQL.** All identifiers are validated against a whitelist
   and quoted with `QUOTENAME` before being concatenated into dynamic SQL.
5. **One parameter per procedure.** A single `@spec` JSON parameter keeps
   the API stable and makes it easy to build calls from C#, Python, or
   any CI/CD tool.

---

## What DbMold is *not*

- It is **not** a migration engine. It does not track versions, order
  scripts, or compute a plan. Use your own changeset tool for that.
- It is **not** a replacement for Flyway, Liquibase, or EF Migrations.
  Those tools manage *when* and *in what order* migrations run; DbMold
  makes each *individual* migration idempotent and safe.
- It is **not** a backup or rollback tool. See "Rollback" below.

---

## Rollback

DbMold is **forward-only** by design. We do not provide `down` scripts,
and we recommend you don't write them either:

- `down` scripts are rarely tested and often broken.
- `down` cannot restore data that a `up` migration has deleted or transformed.
- Running `down` in production is riskier than the original migration.

If a deployment goes wrong, fix forward: write a new migration that
compensates. For local development, drop and recreate the database —
it's faster and safer than a `down` script.

For production, take a snapshot or backup **before** deploying. That is
your real rollback.

---

## Requirements

- SQL Server 2016 or later (for `JSON_VALUE` and `FOR JSON`).
- No CLR, no external assemblies, no special permissions beyond
  `CREATE PROCEDURE`, `CREATE FUNCTION`, `ALTER`, and `EXECUTE`.

---

## Contributing

Issues and pull requests are welcome. Please:

- Keep the API small and focused.
- Add tests for any new behavior.
- Follow the naming convention (`verb_noun` for procedures and getters,
  `noun_verb` for predicates).
- Keep the code T-SQL-only.

---

## License

MIT — see [LICENSE](LICENSE).