-- =============================================
-- $(SchemaName).column_type_change
-- =============================================
-- Classifies a proposed type change and reports what, if anything, must be
-- verified before ALTER COLUMN can run.
--
-- Both source and target are described by:
--   @type_name   -- canonical name from sys.types (e.g. 'int', 'varchar')
--   @length      -- sys.columns.max_length semantics (-1 for max)
--   @precision   -- sys.columns.precision (NULL for non-numeric)
--   @scale       -- sys.columns.scale (NULL for non-numeric/non-temporal)
--
-- Returns a single row:
--   class                    'widening' | 'narrowing' | 'lateral' | 'forbidden'
--   requires_data_check      1 when existing rows must be verified to fit the target
--   requires_collation_check 1 when the code page / collation changes
--   reason                   human-readable summary (NULL for widening)
--
-- Classification:
--   widening   target domain superset of source; no data check needed
--   narrowing  target domain subset; rows must be verified to fit
--   lateral    same family but encoding or collation changes (n<->varchar);
--              always requires a data check, and a collation check when the
--              target is the non-Unicode side
--   forbidden  different type family, or a change SQL Server will not accept
--
-- Notes:
--   - @length follows sys.columns.max_length: -1 means MAX, and nchar/nvarchar
--     lengths are in BYTES (2 per character). The comparison logic divides by
--     two where the domain is defined in characters.
--   - The function only classifies; it does not query data. The caller performs
--     the data and collation checks named by the returned flags.
-- =============================================
CREATE OR ALTER FUNCTION $(SchemaName).column_type_change
(
    @from_type      sysname,
    @from_length    int,
    @from_precision int,
    @from_scale     int,
    @to_type        sysname,
    @to_length      int,
    @to_precision   int,
    @to_scale       int
)
RETURNS TABLE
AS
RETURN
(
    WITH
    norm AS
    (
        SELECT
            f_type   = @from_type,
            t_type   = @to_type,

            f_chars  = CASE
                           WHEN @from_type IN (N'nchar', N'nvarchar')
                               THEN CASE WHEN @from_length = -1 THEN -1
                                         ELSE @from_length / 2 END
                           WHEN @from_type IN (N'char', N'varchar', N'binary', N'varbinary')
                               THEN @from_length
                           ELSE NULL
                       END,
            t_chars  = CASE
                           WHEN @to_type IN (N'nchar', N'nvarchar')
                               THEN CASE WHEN @to_length = -1 THEN -1
                                         ELSE @to_length / 2 END
                           WHEN @to_type IN (N'char', N'varchar', N'binary', N'varbinary')
                               THEN @to_length
                           ELSE NULL
                       END,

            f_int_digits = CASE
                               WHEN @from_type IN (N'decimal', N'numeric')
                                   THEN @from_precision - @from_scale
                               ELSE NULL
                           END,
            t_int_digits = CASE
                               WHEN @to_type IN (N'decimal', N'numeric')
                                   THEN @to_precision - @to_scale
                               ELSE NULL
                           END
    ),
    classify AS
    (
        SELECT
            n.*,

            is_int_family  = CASE WHEN n.f_type IN (N'tinyint', N'smallint', N'int', N'bigint')
                                   AND n.t_type IN (N'tinyint', N'smallint', N'int', N'bigint')
                                  THEN 1 ELSE 0 END,

            int_rank_f     = CASE n.f_type WHEN N'tinyint' THEN 1 WHEN N'smallint' THEN 2
                                           WHEN N'int' THEN 3 WHEN N'bigint' THEN 4 END,
            int_rank_t     = CASE n.t_type WHEN N'tinyint' THEN 1 WHEN N'smallint' THEN 2
                                           WHEN N'int' THEN 3 WHEN N'bigint' THEN 4 END,

            is_char_family = CASE WHEN n.f_type IN (N'char', N'varchar', N'nchar', N'nvarchar')
                                  THEN 1 ELSE 0 END,
            is_char_to     = CASE WHEN n.t_type IN (N'char', N'varchar', N'nchar', N'nvarchar')
                                  THEN 1 ELSE 0 END,
            same_char_fam  = CASE WHEN (n.f_type IN (N'char', N'nchar')
                                        AND n.t_type IN (N'char', N'nchar'))
                                   OR (n.f_type IN (N'varchar', N'nvarchar')
                                        AND n.t_type IN (N'varchar', N'nvarchar'))
                                  THEN 1 ELSE 0 END,
            fixed_to_var   = CASE WHEN (n.f_type = N'char'    AND n.t_type = N'varchar')
                                   OR (n.f_type = N'nchar'   AND n.t_type = N'nvarchar')
                                   OR (n.f_type = N'binary'  AND n.t_type = N'varbinary')
                                  THEN 1 ELSE 0 END,
            var_to_fixed   = CASE WHEN (n.f_type = N'varchar'    AND n.t_type = N'char')
                                   OR (n.f_type = N'nvarchar'   AND n.t_type = N'nchar')
                                   OR (n.f_type = N'varbinary'  AND n.t_type = N'binary')
                                  THEN 1 ELSE 0 END,

            is_bin_family  = CASE WHEN n.f_type IN (N'binary', N'varbinary')
                                   AND n.t_type IN (N'binary', N'varbinary')
                                  THEN 1 ELSE 0 END,

            is_dec_family  = CASE WHEN n.f_type IN (N'decimal', N'numeric')
                                   AND n.t_type IN (N'decimal', N'numeric')
                                  THEN 1 ELSE 0 END,

            is_dt2_family  = CASE WHEN n.f_type = n.t_type
                                   AND n.t_type IN (N'datetime2', N'datetimeoffset', N'time')
                                  THEN 1 ELSE 0 END,
            is_dt_family   = CASE WHEN n.f_type IN (N'smalldatetime', N'datetime', N'datetime2')
                                   AND n.t_type IN (N'smalldatetime', N'datetime', N'datetime2')
                                  THEN 1 ELSE 0 END,
            dt_rank_f      = CASE n.f_type WHEN N'smalldatetime' THEN 1 WHEN N'datetime' THEN 2
                                           WHEN N'datetime2' THEN 3 END,
            dt_rank_t      = CASE n.t_type WHEN N'smalldatetime' THEN 1 WHEN N'datetime' THEN 2
                                           WHEN N'datetime2' THEN 3 END,

            is_float_family = CASE WHEN n.f_type IN (N'real', N'float')
                                    AND n.t_type IN (N'real', N'float')
                                   THEN 1 ELSE 0 END,

            is_money_family = CASE WHEN n.f_type = n.t_type
                                    AND n.f_type IN (N'money', N'smallmoney')
                                   THEN 1 ELSE 0 END,
            money_rank_f    = CASE n.f_type WHEN N'smallmoney' THEN 1 WHEN N'money' THEN 2 END,
            money_rank_t    = CASE n.t_type WHEN N'smallmoney' THEN 1 WHEN N'money' THEN 2 END
        FROM norm AS n
    ),
    verdict AS
    (
        SELECT
            c.*,

            class = CASE

                -- ---------- identity ----------
                WHEN c.f_type = c.t_type AND c.f_type IN (
                     N'int', N'bigint', N'smallint', N'tinyint', N'bit',
                     N'uniqueidentifier', N'date', N'xml',
                     N'varchar', N'nvarchar', N'char', N'nchar',
                     N'binary', N'varbinary', N'real', N'float',
                     N'money', N'smallmoney', N'datetime', N'smalldatetime',
                     N'datetime2', N'datetimeoffset', N'time',
                     N'decimal', N'numeric')
                     AND (
                         (c.f_chars IS NULL AND c.t_chars IS NULL)
                         OR (c.f_chars IS NOT NULL AND c.f_chars = c.t_chars)
                         OR (c.f_chars = -1 AND c.t_chars = -1)
                     )
                     AND ISNULL(c.f_int_digits, -1)  = ISNULL(c.t_int_digits, -1)
                     AND ISNULL(@from_scale, -1)     = ISNULL(@to_scale, -1)
                    THEN N'widening'

                -- ---------- integer family ----------
                WHEN c.is_int_family = 1
                    THEN CASE
                             WHEN c.int_rank_t >= c.int_rank_f THEN N'widening'
                             ELSE N'narrowing'
                         END

                -- ---------- character family ----------
                WHEN c.is_char_family = 1 AND c.is_char_to = 1
                    THEN CASE

                        WHEN c.f_type = c.t_type THEN
                            CASE
                                WHEN c.f_chars = -1 AND c.t_chars = -1 THEN N'widening'
                                WHEN c.f_chars = -1 THEN N'narrowing'
                                WHEN c.t_chars = -1 THEN N'widening'
                                WHEN c.t_chars >= c.f_chars THEN N'widening'
                                ELSE N'narrowing'
                            END

                        WHEN c.fixed_to_var = 1 THEN
                            CASE
                                WHEN c.t_chars = -1 THEN N'widening'
                                WHEN c.t_chars >= c.f_chars THEN N'widening'
                                ELSE N'narrowing'
                            END

                        WHEN c.var_to_fixed = 1 THEN N'narrowing'

                        WHEN c.same_char_fam = 1 THEN
                            CASE
                                WHEN c.f_type IN (N'char', N'varchar')
                                    AND c.t_type IN (N'nchar', N'nvarchar')
                                    AND (c.t_chars = -1 OR (c.f_chars <> -1 AND c.t_chars >= c.f_chars))
                                    THEN N'widening'
                                WHEN c.f_type IN (N'nchar', N'nvarchar')
                                    AND c.t_type IN (N'char', N'varchar')
                                    THEN N'lateral'

                                ELSE N'narrowing'
                            END

                        WHEN c.f_type = N'char' AND c.t_type = N'nvarchar' THEN
                            CASE
                                WHEN c.t_chars = -1 THEN N'widening'
                                WHEN c.f_chars <> -1 AND c.t_chars >= c.f_chars
                                    THEN N'widening'
                                ELSE N'narrowing'
                            END

                        ELSE N'forbidden'
                    END

                -- ---------- binary family ----------
                WHEN c.is_bin_family = 1
                    THEN CASE
                        WHEN c.f_type = N'binary'    AND c.t_type = N'varbinary'
                             AND (c.t_chars = -1 OR c.t_chars >= c.f_chars) THEN N'widening'
                        WHEN c.f_type = N'varbinary' AND c.t_type = N'binary'
                             THEN N'narrowing'
                        WHEN c.f_type = c.t_type THEN
                            CASE
                                WHEN c.f_chars = -1 AND c.t_chars = -1 THEN N'widening'
                                WHEN c.f_chars = -1 THEN N'narrowing'
                                WHEN c.t_chars = -1 THEN N'widening'
                                WHEN c.t_chars >= c.f_chars THEN N'widening'
                                ELSE N'narrowing'
                            END
                        ELSE N'forbidden'
                    END

                -- ---------- decimal family ----------
                WHEN c.is_dec_family = 1
                    THEN CASE
                        WHEN c.t_int_digits >= c.f_int_digits
                             AND @to_scale >= @from_scale
                            THEN N'widening'
                        ELSE N'narrowing'
                    END

                -- ---------- temporal precision family ----------
                WHEN c.is_dt2_family = 1
                    THEN CASE
                        WHEN @to_scale >= @from_scale THEN N'widening'
                        ELSE N'narrowing'
                    END

                -- ---------- temporal family ----------
                WHEN c.is_dt_family = 1
                    THEN CASE
                        WHEN c.dt_rank_t >= c.dt_rank_f THEN N'widening'
                        ELSE N'narrowing'
                    END

                -- ---------- float family ----------
                WHEN c.is_float_family = 1
                    THEN CASE
                        WHEN c.f_type = N'real' AND c.t_type = N'float' THEN N'widening'
                        WHEN c.f_type = c.t_type THEN N'widening'
                        ELSE N'narrowing'
                    END

                -- ---------- money family ----------
                WHEN c.is_money_family = 1
                    THEN CASE
                        WHEN c.money_rank_t >= c.money_rank_f THEN N'widening'
                        ELSE N'narrowing'
                    END

                -- ---------- money <-> decimal ----------
                WHEN c.f_type = N'money' AND c.t_type IN (N'decimal', N'numeric')
                    THEN CASE
                        WHEN c.t_int_digits >= 15 AND @to_scale >= 4 THEN N'widening'
                        ELSE N'narrowing'
                    END

                ELSE N'forbidden'
            END
        FROM classify AS c
    )
    SELECT
        class = v.class,

        requires_data_check = CASE
            WHEN v.class IN (N'narrowing', N'lateral') THEN 1
            ELSE 0
        END,

        requires_collation_check = CASE
            WHEN v.f_type IN (N'nchar', N'nvarchar')
                 AND v.t_type IN (N'char', N'varchar')
                THEN 1
            WHEN v.f_type IN (N'char', N'varchar')
                 AND v.t_type IN (N'nchar', N'nvarchar')
                THEN 1
            ELSE 0
        END,

        reason = CASE
            WHEN v.class = N'forbidden'
                THEN N'type change from ' + v.f_type + N' to ' + v.t_type
                   + N' is not supported; use a manual migration.'
            WHEN v.class = N'narrowing'
                THEN N'target type is narrower than the source; '
                   + N'existing values must fit the new domain.'
            WHEN v.class = N'lateral'
                THEN N'Unicode to non-Unicode conversion may lose characters; '
                   + N'an explicit target collation and a data check are required.'
            ELSE NULL
        END
    FROM verdict AS v
);
GO