if exists (select * from sys.objects where object_id = object_id(N'[dbo].[foreign_key_exists_teardown]') and type in (N'P', N'PC'))
    exec dbo.foreign_key_exists_teardown
