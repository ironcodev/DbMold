if exists (select * from sys.objects where object_id = object_id(N'[dbo].[table_info_teardown]') and type in (N'P', N'PC'))
    exec dbo.table_info_teardown
