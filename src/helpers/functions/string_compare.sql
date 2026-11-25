create or alter function $(SchemaName).string_compare
(
    @a          nvarchar(max),
    @b          nvarchar(max),
    @trim       bit,
    @ignoreCase bit
)
returns smallint
as
begin
    set @a = isnull(@a, N'');
    set @b = isnull(@b, N'');

    if @trim = 1
    begin
        set @a = $(SchemaName).trim_whitespace(@a);
        set @b = $(SchemaName).trim_whitespace(@b);
    end

    if @ignoreCase = 1
        return
            case
                when datalength(@a) = datalength(@b)
                 and @a collate Latin1_General_CI_AS
                   = @b collate Latin1_General_CI_AS then 0
                when @a collate Latin1_General_CI_AS
                   < @b collate Latin1_General_CI_AS then -1
                else 1
            end;

    return
        case
            when datalength(@a) = datalength(@b)
             and @a collate Latin1_General_CS_AS
               = @b collate Latin1_General_CS_AS then 0
            when @a collate Latin1_General_CS_AS
               < @b collate Latin1_General_CS_AS then -1
            else 1
        end;
end
go