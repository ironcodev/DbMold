if exists (select * from sys.objects where object_id = object_id(N'[dbo].[create_default_teardown]') and type in (N'P', N'PC'))
    exec dbo.create_default_teardown
