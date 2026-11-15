-- =============================================
-- $(SchemaName)._parse_column_list
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName)._parse_column_list
(
    @name nvarchar(1000)
)
RETURNS TABLE
AS
RETURN
WITH
    parsed AS
    (
        SELECT
            ends_with_rparen =
                CASE
                    WHEN LEN(@name) >= 1 AND RIGHT(@name, 1) = N')' THEN 1
                    ELSE 0
                END
    ),
    -- Generate 1..LEN(@name) without window functions in WHERE.
    nums AS
    (
        SELECT TOP (LEN(@name))
            n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ),
    positions AS
    (
        SELECT
            n = nums.n,
            ch = SUBSTRING(@name, nums.n, 1)
        FROM nums
    ),
    depth_calc AS
    (
        SELECT
            n, ch,
            depth = SUM(
                CASE
                    WHEN ch = N']' THEN 1
                    WHEN ch = N'[' THEN -1
                    ELSE 0
                END
            ) OVER (ORDER BY n ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
        FROM positions
    ),
    matching_open AS
    (
        SELECT TOP (1) n AS open_pos
        FROM depth_calc
        WHERE ch = N'('
          AND ISNULL(depth, 0) = 0
          AND (SELECT ends_with_rparen FROM parsed) = 1
        ORDER BY n DESC
    ),
    parts AS
    (
        SELECT
            table_part =
                CASE
                    WHEN (SELECT open_pos FROM matching_open) IS NOT NULL THEN
                        RTRIM(LEFT(@name, (SELECT open_pos FROM matching_open) - 1), N'.')
                    ELSE @name
                END,
            column_part =
                CASE
                    WHEN (SELECT open_pos FROM matching_open) IS NOT NULL THEN
                        SUBSTRING(@name,
                            (SELECT open_pos FROM matching_open) + 1,
                            LEN(@name) - (SELECT open_pos FROM matching_open) - 1)
                    ELSE NULL
                END
        FROM parsed
    ),
    tbl AS
    (
        SELECT
            pt.[db],
            pt.[schema],
            pt.[table],
            pp.column_part
        FROM parts pp
        CROSS APPLY $(SchemaName).parse_table_name(pp.table_part) pt
    )
-- Branch 1: multi-column form.
SELECT
    [db]        = ISNULL(t.[db], DB_NAME()),
    schema_name = t.[schema],
    table_name  = t.[table],
    column_name = LTRIM(RTRIM(j.[value])),
    ord         = j.[key] + 1
FROM tbl t
CROSS APPLY OPENJSON(
    N'[' + ISNULL(
        N'"' + REPLACE(REPLACE(t.column_part, N'"', N'""'), N',', N'","') + N'"',
        N'null'
    ) + N']'
) j
WHERE t.column_part IS NOT NULL

UNION ALL

-- Branch 2: single-column form.
SELECT
    [db]        = ISNULL(pc.[db], DB_NAME()),
    schema_name = pc.[schema],
    table_name  = pc.[table],
    column_name = pc.[column],
    ord         = 1
FROM $(SchemaName).parse_column_name(@name) pc
WHERE NOT EXISTS (SELECT 1 FROM parts WHERE column_part IS NOT NULL)
  AND pc.[column] IS NOT NULL;
GO