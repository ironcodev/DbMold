if exists (select * from sys.objects where object_id = object_id(N'[dbo].[parse_type_teardown]') and type in (N'P', N'PC'))
    exec dbo.parse_type_teardown
