CREATE OR ALTER FUNCTION $(SchemaName).column_xml_info
(
    @column $(SchemaName).object_name
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        [is_xml]                          ,
        [is_xml_document]                 ,
        [xml_schema_collection_id]        ,
        [xml_schema_collection_name]      ,
        [xml_schema_collection_schema_id] ,
        [xml_schema_collection_schema_name]
    FROM $(SchemaName).column_info(@column)
);
GO