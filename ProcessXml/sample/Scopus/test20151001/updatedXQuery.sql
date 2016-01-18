
;WITH XMLNAMESPACES ('http://www.elsevier.com/xml/xocs/dtd' as xocs
					,'http://www.elsevier.com/xml/ani/common' as ce 
					,'http://www.elsevier.com/xml/ani/ait' as ait
					,'http://www.elsevier.com/xml/cto/dtd' as cto
					)
SELECT XMLSource.value('(xocs:doc/xocs:item/item/bibrecord/head/source/@srcid)[1]', 'bigint') AS ScopusSourceID
	,nClassification.value('(text())[1]', 'nvarchar(50)') AS AllScienceJournalClassification
	--,XMLSource.value('(xocs:doc/xocs:item/item/bibrecord/head/enhancement/classificationgroup/classifications/@type)[1]', 'nvarchar(50)') AS ClassificationsType
	,nClassification.value('(../@type)[1]', 'nvarchar(50)') AS ClassificationsType
	,XMLSource.value('(xocs:doc/xocs:meta/xocs:eid/text())[1]', 'nvarchar(25)') AS ScopusPublicationEID
	,1027
FROM (
	SELECT [ID]
		,[SourceFileName]
		,[XMLSource]
		,[loadLogID]
		,[parseLogID]
		,[parseFlag]
	FROM dbo.ani_item
	WHERE isnull([parseFlag], 0) = 0
	ORDER BY ID ASC OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY
	) AS src
--CROSS APPLY XMLSource.nodes('xocs:doc/xocs:item/item/bibrecord/head/enhancement/classificationgroup/classifications[@type="ASJC"]/classification') AS xmlRoot(nClassification)
CROSS APPLY XMLSource.nodes('xocs:doc/xocs:item/item/bibrecord/head/enhancement/classificationgroup/classifications/classification') AS xmlRoot(nClassification)




;WITH XMLNAMESPACES ('http://www.elsevier.com/xml/xocs/dtd' as xocs
					,'http://www.elsevier.com/xml/ani/common' as ce 
					,'http://www.elsevier.com/xml/ani/ait' as ait
					,'http://www.elsevier.com/xml/cto/dtd' as cto
					) 
SELECT nAuthor.value('(@auid)[1]', 'bigint') AS ScopusAuthorID
	,nAuthor.value('(ce:surname/text())[1]', 'nvarchar(20)') AS Surname
	,nAuthor.value('(ce:given-name/text())[1]', 'nvarchar(20)') AS Firstname
	,nAuthor.value('(preferred-name/ce:surname/text())[1]', 'nvarchar(20)') AS PrefSurname
	,nAuthor.value('(preferred-name/ce:given-name/text())[1]', 'nvarchar(20)') AS PrefFirstname
	--,XMLSource.value('(xocs:doc/xocs:item/item/bibrecord/head/author-group/affiliation/@afid)[1]', 'bigint') AS ScopusAffiliationID
	,nAuthor.value('(../affiliation/@afid)[1]', 'bigint') AS ScopusAffiliationID
	,XMLSource.value('(xocs:doc/xocs:meta/xocs:eid/text())[1]', 'nvarchar(25)') AS ScopusPublicationEID
	,1027
FROM (
	SELECT [ID]
		,[SourceFileName]
		,[XMLSource]
		,[loadLogID]
		,[parseLogID]
		,[parseFlag]
	FROM dbo.ani_item
	WHERE isnull([parseFlag], 0) = 0
	ORDER BY ID ASC OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY
	) AS src
CROSS APPLY XMLSource.nodes('xocs:doc/xocs:item/item/bibrecord/head/author-group/author') AS xmlRoot(nAuthor)




