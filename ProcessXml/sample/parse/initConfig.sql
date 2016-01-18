
insert into [config].[XMLParseConfig]
([SourceTable]
      ,[SourceXMLColumn]
      ,[SourceNodePath]
      ,[SourceQueryColumn]
      ,[DestTable]
      ,[DestColumn]
      ,[DestColumnType]
      ,[nodeAlias]
      ,[colNodeAlias]
	  ,[isPlainColumn])
values
('dbo.ani_citedby'
,'XMLSource'
,'cited-by/citing-doc/eid'
,'SourceFileName'
,'dbo.citedby'
,'source_key'
,'nvarchar(50)'
,'nCitedby'
,NULL
,1
);


insert into [config].[XMLParseConfig]
([SourceTable]
      ,[SourceXMLColumn]
      ,[SourceNodePath]
      ,[SourceQueryColumn]
      ,[DestTable]
      ,[DestColumn]
      ,[DestColumnType]
      ,[nodeAlias]
      ,[colNodeAlias])
values
('dbo.ani_citedby'
,'XMLSource'
,'cited-by/citing-doc/eid'
,'text()'
,'dbo.citedby'
,'citedby_eid'
,'nvarchar(25)'
,'nCitedby'
,'nCitedby'
);



------ init namespace mapping table if required
insert into [config].[XMLNameSpaceMapping]
	([XmlType]
      ,[XmlNameSpace]
      ,[SourceTableName])
values
	('ANI_ITEM'
	,';WITH XMLNAMESPACES (''http://www.elsevier.com/xml/xocs/dtd'' as xocs
					,''http://www.elsevier.com/xml/ani/common'' as ce 
					,''http://www.elsevier.com/xml/ani/ait'' as ait
					,''http://www.elsevier.com/xml/cto/dtd'' as cto
					)'
	,'dbo.ani_item')
;

------ for testing
--insert into [config].[XMLNameSpaceMapping]
--	([XmlType]
--      ,[XmlNameSpace]
--      ,[SourceTableName])
--values
--	('ANI_ITEM_test'
--	,';WITH XMLNAMESPACES (''http://www.elsevier.com/xml/xocs/dtd'' as xocs
--					,''http://www.elsevier.com/xml/ani/common'' as ce 
--					,''http://www.elsevier.com/xml/ani/ait'' as ait
--					,''http://www.elsevier.com/xml/cto/dtd'' as cto
--					)'
--	,'dbo.ani_item_test')
--;

--insert into [Scopus].[config].[XMLParseConfig]
--([SourceTable]
--      ,[SourceXMLColumn]
--      ,[SourceNodePath]
--      ,[SourceQueryColumn]
--      ,[DestTable]
--      ,[DestColumn]
--      ,[DestColumnType]
--      ,[nodeAlias]
--      ,[colNodeAlias])
--select 'dbo.ani_item_test'
--      ,[SourceXMLColumn]
--      ,[SourceNodePath]
--      ,[SourceQueryColumn]
--      ,'dbo.meta_test'
--      ,[DestColumn]
--      ,[DestColumnType]
--      ,[nodeAlias]
--      ,[colNodeAlias]
--  FROM [Scopus].[config].[XMLParseConfig]
--  where DestTable='dbo.meta'
--;
