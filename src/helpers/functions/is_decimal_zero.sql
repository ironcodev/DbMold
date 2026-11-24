create or alter function $(SchemaName).is_decimal_zero
(
    @x varchar(50)
)
returns bit
as
begin
    return
        $(SchemaName).is_decimal(@x)
        & case
            when trim(
                replace(
                    replace(
                        replace(
                            replace(trim(@x), '+', ''),
                            '-', ''
                        ),
                        '.', ''
                    ),
                    '0', ''
                )
            ) = '' then 1
            else 0
          end;
end
go