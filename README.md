# DbMold

> **Mold your SQL Server schema — idempotent, forward-only, dependency-free.**

DbMold is a tiny set of T-SQL stored procedures and functions that make
schema changes **safe to run multiple times**. No external tools, no
libraries, no SQLCLR — just `EXEC mold.create_column @spec = N'{...}'`.

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
EXEC mold.create_column @spec = N'{
  "table":   "sales.Products",
  "name":    "DiscountPrice",
  "type":    "int",
  "nullable": true,
  "default": "0"
}';
