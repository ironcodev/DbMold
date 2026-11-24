if exists (select * from sys.objects where object_id = object_id(N'[dbo].[parse_column_list_teardown]') and type in (N'P', N'PC'))
    exec dbo.parse_column_list_teardown
