create or alter proc parse_column_name_testcase
(
	@name nvarchar(1000),
	@assert_db nvarchar(500),
	@assert_schema nvarchar(500),
	@assert_table nvarchar(500),
	@assert_column nvarchar(500)
)
as
begin
	declare @db nvarchar(500)
	declare @schema nvarchar(500)
	declare @table nvarchar(500)
	declare @column nvarchar(500)

	select
        @db = [db],
        @schema = [schema],
        @table = [table],
        @column = [column] 
    from m.parse_column_name(@name)

    -- assert: db
    if @assert_db is null
        exec Assert.[IsNull] @assert_db
    else
        exec Assert.Equals @db, @assert_db

    -- assert: schema
    if @assert_schema is null
        exec Assert.[IsNull] @assert_schema
    else
        exec Assert.Equals @schema, @assert_schema

    -- assert: table
    if @assert_table is null
        exec Assert.[IsNull] @assert_table
    else
        exec Assert.Equals @table, @assert_table

    -- assert: column
    if @assert_column is null
        exec Assert.[IsNull] @assert_column
    else
        exec Assert.Equals @column, @assert_column
end

go

-- ===================================================
--                  Single Part
-- ===================================================
create or alter proc sstr.column_single_part_no_brackets
as
begin
    exec parse_column_name_testcase 'a', null, null, null, 'a'
end

go

create or alter proc sstr.column_single_part_with_brackets_no_dot
as
begin
    exec parse_column_name_testcase '[a]', null, null, null, 'a'
end

go

create or alter proc sstr.column_single_part_with_brackets_and_dot
as
begin
    exec parse_column_name_testcase '[a1.a2]', null, null, null, 'a1.a2'
end

go

-- ===================================================
--                  Two Parts
-- ===================================================
create or alter proc sstr.column_two_parts_no_brackets
as
begin
    exec parse_column_name_testcase 'a.b', null, 'dbo', 'a', 'b'
end

go

create or alter proc sstr.column_two_parts_part1_bracket_no_dot
as
begin
    exec parse_column_name_testcase '[a].b', null, 'dbo', 'a', 'b'
end

go

create or alter proc sstr.column_two_parts_part2_bracket_no_dot
as
begin
    exec parse_column_name_testcase 'a.[b]', null, 'dbo', 'a', 'b'
end

go

create or alter proc sstr.column_two_parts_with_brackets_no_dot
as
begin
    exec parse_column_name_testcase '[a].[b]', null, 'dbo', 'a', 'b'
end

go

create or alter proc sstr.column_two_parts_part1_bracket_and_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].b', null, 'dbo', 'a1.a2', 'b'
end

go

create or alter proc sstr.column_two_parts_part2_bracket_and_dot
as
begin
    exec parse_column_name_testcase 'a.[b1.b2]', null, 'dbo', 'a', 'b1.b2'
end

go

create or alter proc sstr.column_two_parts_with_brackets_and_dots
as
begin
    exec parse_column_name_testcase '[a1.a2].[b1.b2]', null, 'dbo', 'a1.a2', 'b1.b2'
end

go

-- ===================================================
--                  Three Parts
-- ===================================================
create or alter proc sstr.column_three_parts_no_brackets
as
begin
    exec parse_column_name_testcase 'a.b.c', null, 'a', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part1_bracket_no_dot
as
begin
    exec parse_column_name_testcase '[a].b.c', null, 'a', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part2_bracket_no_dot
as
begin
    exec parse_column_name_testcase 'a.[b].c', null, 'a', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part3_bracket_no_dot
as
begin
    exec parse_column_name_testcase 'a.b.[c]', null, 'a', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part1_bracket_with_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].b.c', null, 'a1.a2', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part2_bracket_with_dot
as
begin
    exec parse_column_name_testcase 'a.[b1.b2].c', null, 'a', 'b1.b2', 'c'
end

go

create or alter proc sstr.column_three_parts_part3_bracket_with_dot
as
begin
    exec parse_column_name_testcase 'a.b.[c1.c2]', null, 'a', 'b', 'c1.c2'
end

go

create or alter proc sstr.column_three_parts_part12_bracket_no_dot
as
begin
    exec parse_column_name_testcase '[a].[b].c', null, 'a', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part13_bracket_no_dot
as
begin
    exec parse_column_name_testcase '[a].b.[c]', null, 'a', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part23_bracket_no_dot
as
begin
    exec parse_column_name_testcase 'a.[b].[c]', null, 'a', 'b', 'c'
end

go


create or alter proc sstr.column_three_parts_part1_bracket_with_dot_part2_bracket_no_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].[b].c', null, 'a1.a2', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part1_bracket_no_dot_part2_bracket_with_dot
as
begin
    exec parse_column_name_testcase '[a].[b1.b2].c', null, 'a', 'b1.b2', 'c'
end

go

create or alter proc sstr.column_three_parts_part12_bracket_with_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].[b1.b2].c', null, 'a1.a2', 'b1.b2', 'c'
end

go

create or alter proc sstr.column_three_parts_part1_bracket_with_dot_part3_bracket_no_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].b.[c]', null, 'a1.a2', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part1_bracket_no_dot_part3_bracket_with_dot
as
begin
    exec parse_column_name_testcase '[a].b.[c1.c2]', null, 'a', 'b', 'c1.c2'
end

go

create or alter proc sstr.column_three_parts_part13_bracket_with_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].b.[c1.c2]', null, 'a1.a2', 'b', 'c1.c2'
end

go

create or alter proc sstr.column_three_parts_part2_bracket_with_dot_part3_bracket_no_dot
as
begin
    exec parse_column_name_testcase 'a.[b1.b2].[c]', null, 'a', 'b1.b2', 'c'
end

go

create or alter proc sstr.column_three_parts_part2_bracket_no_dot_part3_bracket_with_dot
as
begin
    exec parse_column_name_testcase 'a.[b].[c1.c2]', null, 'a', 'b', 'c1.c2'
end

go

create or alter proc sstr.column_three_parts_part23_bracket_with_dot
as
begin
    exec parse_column_name_testcase 'a.[b1.b2].[c1.c2]', null, 'a', 'b1.b2', 'c1.c2'
end

go

create or alter proc sstr.column_three_parts_part123_bracket_no_dot
as
begin
    exec parse_column_name_testcase '[a].[b].[c]', null, 'a', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part123_bracket_part1_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].[b].[c]', null, 'a1.a2', 'b', 'c'
end

go

create or alter proc sstr.column_three_parts_part123_bracket_part2_dot
as
begin
    exec parse_column_name_testcase '[a].[b1.b2].[c]', null, 'a', 'b1.b2', 'c'
end

go

create or alter proc sstr.column_three_parts_part123_bracket_part3_dot
as
begin
    exec parse_column_name_testcase '[a].[b].[c1.c2]', null, 'a', 'b', 'c1.c2'
end

go

create or alter proc sstr.column_three_parts_part123_bracket_part12_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].[b1.b2].[c]', null, 'a1.a2', 'b1.b2', 'c'
end

go

create or alter proc sstr.column_three_parts_part123_bracket_part13_dot
as
begin
    exec parse_column_name_testcase '[a1.a2].[b].[c1.c2]', null, 'a1.a2', 'b', 'c1.c2'
end

go

create or alter proc sstr.column_three_parts_part123_bracket_part23_dot
as
begin
    exec parse_column_name_testcase '[a].[b1.b2].[c1.c2]', null, 'a', 'b1.b2', 'c1.c2'
end

go

create or alter proc sstr.column_four_parts_no_brackets_and_dots
as
begin
    exec parse_column_name_testcase 'a.b.c.d', 'a', 'b', 'c', 'd'
end

go

create or alter proc sstr.four_parts_part1234_bracket_no_dot
as
begin
    exec parse_column_name_testcase '[a].[b].[c].[d]', 'a', 'b', 'c', 'd'
end

go
