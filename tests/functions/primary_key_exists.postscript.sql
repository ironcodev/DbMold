if exists (select * from sys.objects where object_id = object_id(N'[dbo].[primary_key_exists_teardown]') and type in (N'P', N'PC'))
    exec dbo.primary_key_exists_teardown
