-- =============================================
-- $(SchemaName).parse_column_type
-- =============================================
-- Parses a T-SQL type declaration string and returns a single row of
-- normalized metadata describing the type. Intended as the single
-- source of truth for type resolution inside create_column (and any
-- other helper that needs to reason about a column's declared type).
--
-- Accepts (whitespace- and bracket-tolerant):
--   'int'
--   'varchar(100)'
--   'nvarchar(max)'
--   'decimal(18,2)'
--   'datetime2(7)'
--   'uniqueidentifier'
--   '[dbo].[MyUdt]'
--   'varchar(100) NOT NULL'   -- trailing NULL / NOT NULL is stripped
--
-- Returns one row with:
--   input_type, base_type_name, type_schema, type_name, normalized_type,
--   args, arg1, arg2,
--   system_type_id, user_type_id, type_schema_id,
--   is_user_defined, is_table_type, is_assembly_type, collation_name,
--   is_max, char_length, byte_length, precision, scale, fractional_scale,
--   is_valid, validation_error
--
-- Notes:
--   - char_length is in CHARACTERS for nchar/nvarchar and BYTES otherwise.
--   - byte_length matches what sys.columns.max_length would store
--     (-1 for max); use it when comparing against column_info.max_length.
--   - is_valid = 0 when the base type is unknown, arguments are malformed,
--     or the type is a user-defined table type. Callers should THROW
--     using validation_error verbatim.
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).parse_column_type
(
    @type nvarchar(4000)
)
RETURNS TABLE
AS
RETURN
(
    WITH
    src AS
    (
        SELECT
            cleaned = LTRIM(RTRIM(
                          CASE
                              WHEN LTRIM(RTRIM(@type)) LIKE N'% NOT NULL'
                                  THEN LEFT(LTRIM(RTRIM(@type)), LEN(LTRIM(RTRIM(@type))) - 9)
                              WHEN LTRIM(RTRIM(@type)) LIKE N'% NULL'
                                  THEN LEFT(LTRIM(RTRIM(@type)), LEN(LTRIM(RTRIM(@type))) - 5)
                              ELSE LTRIM(RTRIM(@type))
                          END))
    ),
    split AS
    (
        SELECT
            base_name = LTRIM(RTRIM(
                            CASE WHEN CHARINDEX(N'(', s.cleaned) > 0
                                 THEN LEFT(s.cleaned, CHARINDEX(N'(', s.cleaned) - 1)
                                 ELSE s.cleaned END)),
            args      = CASE
                            WHEN CHARINDEX(N'(', s.cleaned) > 0
                                 AND RIGHT(s.cleaned, 1) = N')'
                                THEN SUBSTRING(s.cleaned,
                                               CHARINDEX(N'(', s.cleaned) + 1,
                                               LEN(s.cleaned) - CHARINDEX(N'(', s.cleaned) - 1)
                            ELSE NULL
                        END
        FROM src AS s
    ),
    norm AS
    (
        SELECT
            base_clean  = LTRIM(RTRIM(
                              CASE
                                  WHEN PARSENAME(REPLACE(REPLACE(split.base_name, N'[', N''), N']', N''), 2) IS NOT NULL
                                      THEN PARSENAME(REPLACE(REPLACE(split.base_name, N'[', N''), N']', N''), 1)
                                  ELSE REPLACE(REPLACE(split.base_name, N'[', N''), N']', N'')
                              END)),
            schema_part = CASE
                              WHEN PARSENAME(REPLACE(REPLACE(split.base_name, N'[', N''), N']', N''), 2) IS NOT NULL
                                  THEN PARSENAME(REPLACE(REPLACE(split.base_name, N'[', N''), N']', N''), 2)
                              ELSE NULL
                          END,
            args = split.args
        FROM split
    ),
    argsplit AS
    (
        SELECT
            n.base_clean,
            n.schema_part,
            n.args,
            p1 = CASE
                     WHEN n.args IS NULL THEN NULL
                     WHEN CHARINDEX(N',', n.args) > 0
                         THEN LTRIM(RTRIM(LEFT(n.args, CHARINDEX(N',', n.args) - 1)))
                     ELSE LTRIM(RTRIM(n.args))
                 END,
            p2 = CASE
                     WHEN n.args IS NULL THEN NULL
                     WHEN CHARINDEX(N',', n.args) > 0
                         THEN LTRIM(RTRIM(SUBSTRING(n.args, CHARINDEX(N',', n.args) + 1, 4000)))
                     ELSE NULL
                 END
        FROM norm AS n
    ),
    resolved AS
    (
        SELECT
            a.base_clean,
            a.schema_part,
            a.args,
            a.p1,
            a.p2,
            t.system_type_id,
            t.user_type_id,
            t.name        AS type_name,
            t.schema_id   AS type_schema_id,
            t.is_user_defined,
            t.is_table_type,
            t.is_assembly_type,
            t.max_length,
            t.precision,
            t.scale,
            t.collation_name
        FROM argsplit AS a
        OUTER APPLY
        (
            SELECT TOP (1) *
            FROM sys.types AS t
            WHERE t.name = a.base_clean
              AND (a.schema_part IS NULL OR t.schema_id = SCHEMA_ID(a.schema_part))
            ORDER BY
                t.is_user_defined ASC,
                CASE WHEN a.schema_part IS NOT NULL AND t.schema_id = SCHEMA_ID(a.schema_part) THEN 0 ELSE 1 END,
                CASE WHEN t.schema_id = SCHEMA_ID(N'dbo') THEN 0 ELSE 1 END
        ) AS t
    ),
    interpreted AS
    (
        SELECT
            r.base_clean,
            r.schema_part,
            r.args,
            r.p1,
            r.p2,
            r.system_type_id,
            r.user_type_id,
            r.type_name,
            r.type_schema_id,
            r.is_user_defined,
            r.is_table_type,
            r.is_assembly_type,
            r.collation_name,

            is_max = CASE WHEN LOWER(ISNULL(r.p1, N'')) = N'max' THEN 1 ELSE 0 END,

                        char_length =
                CASE
                    WHEN r.type_name IN (N'char', N'varchar', N'binary', N'varbinary') THEN
                        CASE
                            WHEN LOWER(ISNULL(r.p1, N'')) = N'max' THEN -1
                            WHEN r.p1 IS NOT NULL THEN TRY_CAST(r.p1 AS int)
                            ELSE 1                                  -- default length is 1
                        END
                    WHEN r.type_name IN (N'nchar', N'nvarchar') THEN
                        CASE
                            WHEN LOWER(ISNULL(r.p1, N'')) = N'max' THEN -1
                            WHEN r.p1 IS NOT NULL THEN TRY_CAST(r.p1 AS int)
                            ELSE 1                                  -- default length is 1 char
                        END
                    ELSE NULL
                END,

            num_precision =
                CASE
                    WHEN r.type_name IN (N'decimal', N'numeric') THEN
                        CASE WHEN r.p1 IS NOT NULL THEN TRY_CAST(r.p1 AS int)
                             ELSE r.precision END
                    WHEN r.type_name IN (N'tinyint', N'smallint', N'int', N'bigint',
                                         N'money', N'smallmoney', N'float', N'real',
                                         N'datetime', N'datetime2', N'datetimeoffset',
                                         N'time', N'bit')
                        THEN r.precision
                    ELSE NULL
                END,

            num_scale =
                CASE
                    WHEN r.type_name IN (N'decimal', N'numeric') THEN
                        CASE WHEN r.p2 IS NOT NULL THEN TRY_CAST(r.p2 AS int)
                             WHEN r.p1 IS NOT NULL THEN 0
                             ELSE r.scale END
                    WHEN r.type_name IN (N'datetime2', N'datetimeoffset', N'time') THEN
                        CASE WHEN r.p1 IS NOT NULL THEN TRY_CAST(r.p1 AS int)
                             ELSE r.scale END
                    WHEN r.type_name IN (N'money', N'smallmoney') THEN r.scale
                    ELSE NULL
                END,

            frac_scale =
                CASE
                    WHEN r.type_name IN (N'datetime2', N'datetimeoffset', N'time') THEN
                        CASE WHEN r.p1 IS NOT NULL THEN TRY_CAST(r.p1 AS int)
                             ELSE r.scale END
                    ELSE NULL
                END,

            byte_length =
                CASE
                    WHEN r.type_name IN (N'nchar', N'nvarchar') THEN
                        CASE
                            WHEN LOWER(ISNULL(r.p1, N'')) = N'max' THEN -1
                            WHEN r.p1 IS NOT NULL THEN TRY_CAST(r.p1 AS int) * 2
                            ELSE 2                                  -- 1 char = 2 bytes
                        END
                    WHEN r.type_name IN (N'char', N'varchar', N'binary', N'varbinary') THEN
                        CASE
                            WHEN LOWER(ISNULL(r.p1, N'')) = N'max' THEN -1
                            WHEN r.p1 IS NOT NULL THEN TRY_CAST(r.p1 AS int)
                            ELSE 1                                  -- default length is 1 byte
                        END
                    ELSE r.max_length
                END,

            has_unknown_base_type =
                CASE WHEN r.type_name IS NULL THEN 1 ELSE 0 END,

            has_bad_arg =
                CASE
                    WHEN r.args IS NULL THEN 0
                    WHEN r.type_name IN (N'char', N'varchar', N'nchar', N'nvarchar',
                                         N'binary', N'varbinary')
                         AND NOT (LOWER(r.p1) = N'max'
                                  OR (TRY_CAST(r.p1 AS int) IS NOT NULL AND TRY_CAST(r.p1 AS int) > 0))
                        THEN 1
                    WHEN r.type_name IN (N'decimal', N'numeric')
                         AND (TRY_CAST(r.p1 AS int) IS NULL
                              OR TRY_CAST(r.p1 AS int) NOT BETWEEN 1 AND 38
                              OR (r.p2 IS NOT NULL AND (TRY_CAST(r.p2 AS int) IS NULL OR TRY_CAST(r.p2 AS int) < 0))
                              OR (r.p2 IS NOT NULL AND TRY_CAST(r.p2 AS int) > TRY_CAST(r.p1 AS int)))
                        THEN 1
                    WHEN r.type_name IN (N'datetime2', N'datetimeoffset', N'time')
                         AND (TRY_CAST(r.p1 AS int) IS NULL OR TRY_CAST(r.p1 AS int) NOT BETWEEN 0 AND 7)
                        THEN 1
                    WHEN r.type_name NOT IN (N'char', N'varchar', N'nchar', N'nvarchar',
                                             N'binary', N'varbinary',
                                             N'decimal', N'numeric',
                                             N'datetime2', N'datetimeoffset', N'time')
                         AND r.p1 IS NOT NULL
                        THEN 1
                    ELSE 0
                END,

            normalized_type =
                CASE
                    WHEN r.type_name IS NULL THEN NULL

                        WHEN r.type_name IN (N'char', N'varchar', N'binary', N'varbinary') THEN
                            r.type_name + N'('
                            + (CASE
                                WHEN LOWER(ISNULL(r.p1, N'')) = N'max' THEN N'max'
                                WHEN r.p1 IS NOT NULL THEN r.p1
                                ELSE N'1'
                            END)
                            + N')'

                    WHEN r.type_name IN (N'nchar', N'nvarchar') THEN
                        r.type_name + N'('
                        + (CASE
                               WHEN LOWER(ISNULL(r.p1, N'')) = N'max' THEN N'max'
                               WHEN r.p1 IS NOT NULL THEN r.p1
                               ELSE N'1'
                           END)
                        + N')'

                    WHEN r.type_name IN (N'decimal', N'numeric') THEN
                        r.type_name + N'('
                        + CAST(ISNULL(TRY_CAST(r.p1 AS int), r.precision) AS nvarchar(20))
                        + N','
                        + CAST(ISNULL(TRY_CAST(r.p2 AS int), 0) AS nvarchar(20))
                        + N')'

                    WHEN r.type_name IN (N'datetime2', N'datetimeoffset', N'time') THEN
                        r.type_name + N'('
                        + CAST(ISNULL(TRY_CAST(r.p1 AS int), r.scale) AS nvarchar(20))
                        + N')'

                    WHEN r.is_user_defined = 1 AND r.schema_part IS NOT NULL THEN
                        QUOTENAME(r.schema_part) + N'.' + QUOTENAME(r.type_name)

                    ELSE r.type_name
                END
        FROM resolved AS r
    )
    SELECT
        input_type         = @type,

        base_type_name     = base_clean,
        type_schema        = schema_part,
        type_name          = type_name,
        normalized_type    = normalized_type,
        args               = args,
        arg1               = p1,
        arg2               = p2,

        system_type_id     = system_type_id,
        user_type_id       = user_type_id,
        type_schema_id     = type_schema_id,
        is_user_defined    = is_user_defined,
        is_table_type      = is_table_type,
        is_assembly_type   = is_assembly_type,
        collation_name     = collation_name,

        is_max             = is_max,
        char_length        = char_length,
        byte_length        = byte_length,
        precision          = num_precision,
        scale              = num_scale,
        fractional_scale   = frac_scale,

        is_valid           = CASE
                                 WHEN has_unknown_base_type = 1 THEN 0
                                 WHEN has_bad_arg = 1 THEN 0
                                 WHEN is_table_type = 1 THEN 0
                                 ELSE 1
                             END,
        validation_error   =
            CASE
                WHEN has_unknown_base_type = 1
                    THEN N'Unknown type name: ' + ISNULL(base_clean, N'(null)')
                WHEN is_table_type = 1
                    THEN N'User-defined table types cannot be used as column types: ' + base_clean
                WHEN has_bad_arg = 1
                    THEN N'Invalid argument(s) for type ' + base_clean + N': (' + ISNULL(args, N'') + N')'
                ELSE NULL
            END
    FROM interpreted
);
go