create or alter proc $(SchemaName).set_debugging(@category varchar(50), @value bit)
as
begin
    set nocount on;

    if @category = '*'
        set @category = 'all'

    set @category = 'debug.' + @category
    set @value = isnull(cast(@value as varchar(1)), '0')

    exec $(SchemaName).set_config @category, @value
end
go

/*
    debugging levels:
        query  , q :  dynamic queries
        nquery , qn:  nested queries
        dquery , qd:  deep queries
        lquery , ql:  loop queries
        vars   , v :  local variables
        dvars  , vd:  deep variables
        lvars  , vl:  loop variables
        debug  , d :  debug
        log    , l :  log
        warning, w :  warnings
        trace  , t :  trace
        errors , e :  show error_message()
        result , r :  results
        config , c :  configs
        setting, s :  settings
        procedure,p:  procedures
        all   , * :  everything
*/
create or alter function $(SchemaName).get_debugging(@category varchar(50))
returns bit
as
begin
    declare @result bit

    if @category = '*'
        set @category = 'all'

    set @category = 'debug.' + @category

    set @result = case when $(SchemaName).get_config(@category) = '1' then 1 else 0 end

    return @result
end
go

create or alter function $(SchemaName).is_debugging(@category varchar(500)) returns bit
as
begin
    return (case when exists
    (
        select 1 from string_split(@category, ',')
        where $(SchemaName).get_debugging([value]) = 1
    ) or $(SchemaName).get_debugging('all') = 1 then 1 else 0 end)
end
go
