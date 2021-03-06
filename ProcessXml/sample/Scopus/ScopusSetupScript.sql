USE [Scopus]
GO
/****** Object:  Schema [config]    Script Date: 18/01/2016 4:28:39 p.m. ******/
CREATE SCHEMA [config]
GO
/****** Object:  Schema [log]    Script Date: 18/01/2016 4:28:39 p.m. ******/
CREATE SCHEMA [log]
GO
/****** Object:  Schema [stage]    Script Date: 18/01/2016 4:28:39 p.m. ******/
CREATE SCHEMA [stage]
GO
/****** Object:  Schema [stage_vw]    Script Date: 18/01/2016 4:28:39 p.m. ******/
CREATE SCHEMA [stage_vw]
GO
/****** Object:  StoredProcedure [dbo].[usp_CreateXmlTable]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		S Yang
-- Create date: 2015-09-02
-- Description:	create a xml table if not exists or drop/recreate it if asked
-- =============================================
CREATE PROCEDURE [dbo].[usp_CreateXmlTable]
	-- Add the parameters for the stored procedure here
	@tableName nvarchar(50), 
	@isDrop bit=0 -- 1: need drop; 0: don't drop
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @SQL_CreatTable nvarchar(500)

	--declare @sql_temp nvarchar(100) = 'select * from sys.objects where object_id = OBJECT_ID(N'''+@tableName+''')';
	--print @sql_temp

	if (@isDrop=1 and exists (select * from sys.objects where object_id = OBJECT_ID(N''+@tableName+'')))
	begin
		exec ('drop table '+@tableName)
	end

	if not exists (select * from sys.objects where object_id = OBJECT_ID(N''+@tableName+''))
	begin 
		set @SQL_CreatTable = 'create table '+@tableName
									+' ( [ID] [bigint] IDENTITY(1,1) NOT NULL,'
									+' [SourceFileName] [nvarchar](50) NOT NULL,'
									+' [XMLSource] [xml] NOT NULL,'
									+' [loadLogID] [int] NULL,'
									+' [parseLogID] [int] NULL,'
									+' [parseFlag] [bit] NULL,'
									+' CONSTRAINT [PK_'+substring(@tableName,CHARINDEX('.',@tableName)+1
													,LEN(@tableName)-CHARINDEX('.',@tableName)+1)
									+'] PRIMARY KEY CLUSTERED ([ID])'
									+' );'
		--print(@SQL_CreatTable)
		EXECUTE sp_executesql @SQL_CreatTable
	end

END


GO
/****** Object:  StoredProcedure [dbo].[usp_InsertItemXML]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		J Sellar
-- Create date: 2015-08-12
-- Description:	Imports ITEM XML and inserts into table
-- =============================================
CREATE PROCEDURE [dbo].[usp_InsertItemXML] 
	-- Add the parameters for the stored procedure here
	@filename nvarchar(50), 
	@fullpathname nvarchar(255),
	@loadLogID int,
	@tableName nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @sql NVARCHAR(MAX);
	DECLARE @result INT;

	SET @sql = 'INSERT INTO '+@tableName+'([SourceFileName], [XMLSource], [loadLogID])' + CHAR(10)
	SET @sql = @sql + 'SELECT ''' + @filename + ''', CONVERT(XML, BulkColumn) as XMLSource, '+ cast(@loadLogID as nvarchar(10)) + CHAR(10)
	SET @sql = @sql + 'FROM OPENROWSET(BULK '''+ @fullpathname + ''', SINGLE_BLOB) AS x;'

	EXEC @result=sp_sqlexec @sql;
	
	SELECT @result;
END


GO
/****** Object:  StoredProcedure [dbo].[usp_LoadHaskKeyTables]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Sunny Yang
-- Create date: 2015-08-21
-- Description:	Construct xQuery and parse xml contents
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadHaskKeyTables]
	-- Add the parameters for the stored procedure here
	@parseLogID int = 0
	,@truncateTables bit = 0 -- 1: truncate tables before loading; 0: no drop
AS

--declare @parseLogID int = 34

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
					


	------ log the entry
	declare @genLogID int
	insert into [log].[HashKeyGenLog] ([StartDT])
		--output Inserted.ID
		values (GETDATE());
	--select @@genLogID=SCOPE_IDENTITY();
	select @genLogID=IDENT_CURRENT('[log].[HashKeyGenLog]')	


	begin try
	
		------ get the @parseLogID for data processing	
		if @parseLogID <= 0
			select @parseLogID=MAX(ID) from [log].[XMLParseLog] 
			where [IsSuccess]=1


		--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
		
		begin tran hashKeyProcessBlock

			if @truncateTables=1
			begin
				truncate table [stage].[affiliation_hashkey]
				truncate table [stage].[author_affhashkey]
				truncate table [stage].[afforganisation_concat]
				truncate table [stage].[pubabstract_concat]
			end

			
			----- store haskey list for table affiliation
			insert into stage.affiliation_hashkey
				([AffID]
				,[AffiliationHashKey]
				,[genLogID])
			SELECT [ID]
				--,hashbytes('SHA1',
				--		case when [ScopusAffiliationID] is null
				--				then [ScopusElectronicIdentifier]+'_'+cast(isnull([ScopusDepartmentID],[nodePosition]) as varchar(30))
				--			else cast([ScopusAffiliationID] as varchar(30))+'_'+cast(isnull([ScopusDepartmentID],-1) as varchar(30)) 
				--		end) as AffiliationHashKey
				,hashbytes('SHA1',
						cast(isnull([ScopusAffiliationID],-1) as varchar(30))
								+'_'+cast(isnull([ScopusDepartmentID],-1) as varchar(30))
								+'_'+isnull([AffiliationCountry],0)
								+'_'+isnull([CityGroup],0)
						) as AffiliationHashKey
				,@genLogID
			FROM [stage].[affiliation]
			where [parseLogID]=@parseLogID
			

			----- store affhaskey list for table author
			insert into stage.author_hashkey
				([AuthorID]
				,[AuthorHashKey]
				,[AffiliationHashKey]
				,[genLogID])
			select au.ID
				--,hashbytes('SHA1',
				--		case when [ScopusAuthorID] is null
				--				then isnull([Surname],0)+'_'+isnull([Firstname],0)
				--						+'_'+isnull([PreferredSurname],0)+'_'+isnull([PreferredFirstname],0)
				--						+'_'+isnull([Initials],0)+'_'+isnull([PreferredInitials],0)
				--			else cast([ScopusAuthorID] as varchar(30)) 
				--		end) as AffiliationHashKey
				,hashbytes('SHA1',
						cast(isnull([ScopusAuthorID],-1) as varchar(30))
								+'_'+isnull([Surname],0)+'_'+isnull([Firstname],0)
								+'_'+isnull([PreferredSurname],0)+'_'+isnull([PreferredFirstname],0)
								+'_'+isnull([Initials],0)+'_'+isnull([PreferredInitials],0)
						) as AffiliationHashKey
				,ahk.AffiliationHashKey
				,@genLogID
			FROM [stage].[author] au
				left join [stage].[affiliation] af on au.ScopusElectronicIdentifier=af.ScopusElectronicIdentifier
					and au.parentNodePosition=af.parentNodePosition
				left join [stage].[affiliation_hashkey] ahk on af.ID=ahk.AffID
			where au.[parseLogID]=@parseLogID


			------- store affhaskey list for table afforganisation
			--insert into stage.afforganisation_2_affhashkey
			--(AffOrgID,AffiliationHashKey)
			--select ao.ID
			--	,ahk.AffiliationHashKey
			--FROM [Scopus].[stage].[afforganisation_2] ao
			--	left join [Scopus].[stage].[affiliation_2] af on ao.ScopusElectronicIdentifier=af.ScopusElectronicIdentifier
			--		and ao.[parentNodePosition]=af.[nodePosition]
			--	join [stage].[affiliation_2_hashkey] ahk on af.ID=ahk.AffID
			--where ao.[parseLogID]=@parseLogID

			--------- store concatenated organisation name and affhaskey list for table afforganisation
			--insert into stage.afforganisation_2_concat
			--	([OrganisationName]
			--	,[ScopusElectronicIdentifier]
			--	,[parentNodePosition]
			--	,[AffiliationHashKey]
			--	,[genLogID])
			--SELECT stuff((SELECT ','+ ao2.OrganisationName 
			--		FROM [Scopus].[stage].[afforganisation_2] ao2
			--		WHERE ao2.ScopusElectronicIdentifier = ao.ScopusElectronicIdentifier
			--			and ao2.parentNodePosition=ao.parentNodePosition
			--		FOR XML PATH('')
			--			,TYPE
			--		).value('.', 'varchar(max)') ,1,1,'') as [OrganisationName]
			--	,ao.[ScopusElectronicIdentifier]
			--	,ao.[parentNodePosition]
			--	,ahk.AffiliationHashKey
			--	,@genLogID
			--FROM [Scopus].[stage].[afforganisation_2] ao
			--	join [stage].[affiliation_2] af on ao.ScopusElectronicIdentifier=af.ScopusElectronicIdentifier
			--		and ao.[parentNodePosition]=af.[nodePosition]
			--	join [stage].[affiliation_2_hashkey] ahk on af.ID=ahk.AffID
			--where ao.[parseLogID]=@parseLogID
			
			------- store concatenated organisation name and affhaskey list for table afforganisation
			insert into stage.afforganisation_concat
				([OrganisationName]
				,[ScopusElectronicIdentifier]
				,[parentNodePosition]
				,[AffiliationHashKey]
				,[genLogID])
			SELECT t1.[OrganisationName]
				,t1.[ScopusElectronicIdentifier]
				,t1.[parentNodePosition]
				,ahk.AffiliationHashKey
				,@genLogID
			FROM 
			(SELECT distinct
					stuff((
						SELECT ','+ ao2.OrganisationName 
						FROM [Scopus].[stage].[afforganisation] ao2
						WHERE ao2.ScopusElectronicIdentifier = ao.ScopusElectronicIdentifier
							and ao2.parentNodePosition=ao.parentNodePosition
						FOR XML PATH('')
							,TYPE
						).value('.', 'nvarchar(max)')
						,1,1,'') 
						as [OrganisationName]
					,[ScopusElectronicIdentifier]
					,[parentNodePosition]
				FROM [Scopus].[stage].[afforganisation] ao
				where ao.[parseLogID] = @parseLogID) as t1
			join [stage].[affiliation] af on t1.ScopusElectronicIdentifier=af.ScopusElectronicIdentifier
				and t1.[parentNodePosition]=af.[nodePosition]
			join [stage].[affiliation_hashkey] ahk on af.ID=ahk.AffID



			--------- store concatenated abstract for the existing table pubabstract
			--insert into [stage].[pubabstract_concat]
			--	([Abstract]
			--	,[ScopusElectronicIdentifier]
			--	,[genLogID])
			--SELECT distinct
			--	(
			--		SELECT a2.[Abstract] + CHAR(13) + CHAR(10)
			--		FROM [stage].pubabstract a2
			--		WHERE a2.ScopusElectronicIdentifier = a.ScopusElectronicIdentifier
			--		FOR XML PATH('')
			--			,TYPE
			--		).value('.', 'nvarchar(max)') AS [Abstract]
			--	,a.[ScopusElectronicIdentifier]
			--	,@genLogID
			--FROM [stage].[pubabstract] a
			--where a.parseLogID = (select min(parseLogID) from [stage].[pubabstract])
			--	and not exists 
			--		(select 1 from [stage].[pubabstract_concat] ac where ac.ScopusElectronicIdentifier=a.ScopusElectronicIdentifier)

			------- store concatenated abstract for the existing table pubabstract
			insert into [stage].[pubabstract_concat]
				([Abstract]
				,[ScopusElectronicIdentifier]
				,[genLogID])
			SELECT distinct
				(
					SELECT a2.[Abstract] + CHAR(13) + CHAR(10)
					FROM [stage].pubabstract a2
					WHERE a2.ScopusElectronicIdentifier = a.ScopusElectronicIdentifier
					FOR XML PATH('')
						,TYPE
					).value('.', 'nvarchar(max)') AS [Abstract]
				,a.[ScopusElectronicIdentifier]
				,@genLogID
			FROM [stage].[pubabstract] a
			where a.parseLogID = @parseLogID


	
		commit tran hashKeyProcessBlock
		print('commit tran hashKeyProcessBlock')

		------- update the log entry with success
		update l set 
			l.EndDT=GETDATE()
			,l.IsSuccess=1
			,l.parseLogID=@parseLogID
		from [log].[HashKeyGenLog] l
		where l.ID=@genLogID;

	end try

	begin catch

		if (@@TRANCOUNT>0)
		begin
			rollback tran hashKeyProcessBlock
			print('rollback tran hashKeyProcessBlock')
		end
	
		DECLARE @ErrorMessage VARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;
		--DECLARE @ErrorNumber INT;
		--DECLARE @ErrorLine INT;
		SELECT 
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE()/*,
		@ErrorNumber = ERROR_NUMBER(),
		@ErrorLine = ERROR_LINE()*/;

		------- update the log entry with failure
		update l set 
			l.EndDT=GETDATE()
			,l.IsSuccess=0
			,l.parseLogID=@parseLogID
			,l.LogMsg=@ErrorMessage
		from [log].[HashKeyGenLog] l
		where l.ID=@genLogID;

		RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState/*,@ErrorNumber,@ErrorLine*/)

	end catch


END






GO
/****** Object:  StoredProcedure [dbo].[usp_ParseXML]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Sunny Yang
-- Create date: 2015-08-21
-- Description:	Construct xQuery and parse xml contents
-- =============================================
CREATE PROCEDURE [dbo].[usp_ParseXML]
	-- Add the parameters for the stored procedure here
	@rowNum INT = 6 -- indicate the number of rows of the source table(s) for loading
	,@tableNames VARCHAR(300) = 'ALL' -- select destination tables for loading
	,@dropTables bit = 0 -- 1: drop destination data tables before loading; 0: no drop
AS


------ log the entry
declare @parseLogID int
insert into [log].[XMLParseLog] ([StartDT])
	--output Inserted.ID
	values (GETDATE());
--select @parseLogID=SCOPE_IDENTITY();
select @parseLogID=IDENT_CURRENT('[log].[XMLParseLog]')


----- transform the parameter @tableNames into a list
DECLARE @xmlStr XML
DECLARE @tableList TABLE (tblname VARCHAR(300))
IF ISNULL(@tableNames,'ALL')='ALL'
	INSERT INTO @tableList
		SELECT DISTINCT [DestTable] FROM [config].[XMLParseConfig] where [enabled]=1;
ELSE
	BEGIN
		SELECT @xmlStr = cast('<M>' + replace(@tableNames, ',', '</M><M>') + '</M>' AS XML);
		INSERT INTO @tableList
			SELECT n.value('text()[1]', 'varchar(300)')
			FROM @xmlStr.nodes('/M') AS DUMMY (n);
	END

----- get a config dataset to use
if exists (select  * from tempdb.dbo.sysobjects o 
	where o.xtype in ('U') and o.id = object_id(N'tempdb..#tempXMLParseConfig')) 
drop table #tempXMLParseConfig;
select *
	into #tempXMLParseConfig
	from [config].[XMLParseConfig]
	where [enabled]=1;

----- declare a cursor for each destination table
----- ([DestTable], [SourceTable], [SourceXMLColumn], [SourceNodePath], [nodeAlias]) -> unique
DECLARE cur_List CURSOR
FOR
SELECT DISTINCT [DestTable]
	----- construct destination create columns schema
	,stuff((
			SELECT ', [' + [DestColumn] + ']'+' '+[DestColumnType]+' NULL'
			FROM #tempXMLParseConfig t1
			WHERE t1.DestTable = t2.DestTable
			FOR XML PATH('')
				,TYPE
			).value('.', 'varchar(1000)'), 1, 1, '') AS DestCreatedColumns
	----- construct destination columns string
	,stuff((
			SELECT ', [' + [DestColumn] + ']'
			FROM #tempXMLParseConfig t1
			WHERE t1.DestTable = t2.DestTable
			FOR XML PATH('')
				,TYPE
			).value('.', 'varchar(1000)'), 1, 1, '') AS DestColumns
	----- construct src query columns string
	,stuff((
			SELECT 
				case when [isPlainColumn]=1 then ', ' + [SourceQueryColumn] +' as ' + [DestColumn]
				else ', ' + [colNodeAlias] 
					+ '.value(''(' + [SourceQueryColumn] + ')[1]'',' + '''' + [DestColumnType] + ''')'
					+' as ' + [DestColumn] end
			FROM #tempXMLParseConfig t1
			WHERE t1.DestTable = t2.DestTable
			FOR XML PATH('')
				,TYPE
			).value('.', 'varchar(max)'), 1, 1, '') AS SrcQueryColumns
	----- get the src table
	, [SourceTable]
	----- construct src cross path
	, [SourceXMLColumn] + '.nodes(''' + [SourceNodePath] + ''') as xmlRoot(' + [nodeAlias] + ')' AS SrcCrossPath
FROM #tempXMLParseConfig t2
	JOIN @tableList l ON t2.DestTable = l.tblname
;


DECLARE @SQL_InsertTable VARCHAR(300)
	,@SQL_InsertCreateColumns VARCHAR(1000)
	,@SQL_InsertColumns VARCHAR(1000)
	,@SQL_SrcQueryColumns VARCHAR(max)
	,@SQL_SrcTableName VARCHAR(300)
	,@SQL_SrcTableDataset VARCHAR(500)
	,@SQL_SrcCrossPath VARCHAR(1000)
	,@SQL_NS VARCHAR(500) = ''
	,@SQL NVARCHAR(MAX)
	,@SQL_CreatDestTable NVARCHAR(2000)

-- a lsit of update table queries
declare @SQL_updateSrcTableList TABLE (updateSQL VARCHAR(1000))
declare cur_updateList cursor for select distinct * from @SQL_updateSrcTableList
declare @SQL_updateSql nvarchar(1000)


BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	begin try
		
		--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

		begin tran xmlProcessBlock

			OPEN cur_List

			FETCH NEXT
			FROM cur_List
			INTO @SQL_InsertTable
				,@SQL_InsertCreateColumns
				,@SQL_InsertColumns
				,@SQL_SrcQueryColumns
				,@SQL_SrcTableName
				,@SQL_SrcCrossPath

			WHILE @@FETCH_STATUS = 0
			BEGIN
				
				----Print(@SQL_InsertCreateColumns)
				--declare @tempSql varchar(100)
				--set @tempSql = 'select * from sys.objects where object_id = OBJECT_ID(N'''+@SQL_InsertTable+''')'
				--print(@tempSql)
				if (@dropTables=1 and exists (select * from sys.objects where object_id = OBJECT_ID(N''+@SQL_InsertTable+'')))
				begin
					exec ('drop table '+@SQL_InsertTable)
				end
				if not exists (select * from sys.objects where object_id = OBJECT_ID(N''+@SQL_InsertTable+''))
				begin 
					set @SQL_CreatDestTable = 'create table '+@SQL_InsertTable
												+' ( [ID] [bigint] IDENTITY(1,1) NOT NULL,'
												+@SQL_InsertCreateColumns
												+', [parseLogID] [int] NULL'
												+', CONSTRAINT [PK_'+substring(@SQL_InsertTable,CHARINDEX('.',@SQL_InsertTable)+1,LEN(@SQL_InsertTable)-CHARINDEX('.',@SQL_InsertTable)+1)
												+'_'+CAST(ROUND(RAND()*100000,0) as varchar(100))
												+'] PRIMARY KEY NONCLUSTERED ([ID])'
												+' );'
					--print(@SQL_CreatDestTable)
					EXECUTE sp_executesql @SQL_CreatDestTable
				end

				--print(@SQL_SrcQueryColumns)
				
				-- set the namespace
				if exists (select [XmlNameSpace] from [config].[XMLNameSpaceMapping] where [SourceTableName]=@SQL_SrcTableName)
					set @SQL_NS = (select top 1 [XmlNameSpace] from [config].[XMLNameSpaceMapping] where [SourceTableName]=@SQL_SrcTableName)
				else
					set @SQL_NS = ''
				
				-- construct the srouce table data set
				--set @SQL_SrcTableDataset = '(select top ('+cast(@rowNum as varchar(10))+') '
				--					+'[ID]
				--					  ,[SourceFileName]
				--					  ,[XMLSource]
				--					  ,[loadLogID]
				--					  ,[parseLogID]
				--					  ,[parseFlag]'
				--					+' from '+@SQL_SrcTableName
				--					+' where isnull([parseFlag],0)=0'
				--					+' order by ID asc) as src'
				set @SQL_SrcTableDataset = '(select [ID]
									  ,[SourceFileName]
									  ,[XMLSource]
									  ,[loadLogID]
									  ,[parseLogID]
									  ,[parseFlag]'
									+' from '+@SQL_SrcTableName
									+' where isnull([parseFlag],0)=0'
									+' order by [ID] asc OFFSET 0 ROWS FETCH NEXT '+cast(@rowNum as varchar(10))+' ROWS ONLY'
									+') as src'


				SET @SQL = @SQL_NS
					+ ' insert into '+ @SQL_InsertTable
					+ ' (' + @SQL_InsertColumns + ', [parseLogID] )'
					+ ' select ' + @SQL_SrcQueryColumns + ', '+cast(@parseLogID as varchar(20))
					+ ' from ' + @SQL_SrcTableDataset
					+ ' cross apply ' + @SQL_SrcCrossPath

				--SET ROWCOUNT @rowNum
				--PRINT (@SQL)
				EXECUTE sp_executesql @SQL
		
				-- insert the update sql into the update table list
				INSERT INTO @SQL_updateSrcTableList
				VALUES ('update src set src.parseFlag=1, src.parseLogID=' + cast(@parseLogID as varchar(20)) + ' from ' + @SQL_SrcTableDataset)
		

				FETCH NEXT
				FROM cur_List
				INTO @SQL_InsertTable
					,@SQL_InsertCreateColumns
					,@SQL_InsertColumns
					,@SQL_SrcQueryColumns
					,@SQL_SrcTableName
					,@SQL_SrcCrossPath

			END

			CLOSE cur_List
			DEALLOCATE cur_List


			-- exec the update sqls to update the source tables
			open cur_updateList
			fetch next from cur_updateList into @SQL_updateSql
			while @@FETCH_STATUS = 0
			begin
				--print(@SQL_updateSql)
				EXECUTE sp_executesql @SQL_updateSql
				fetch next from cur_updateList into @SQL_updateSql
			end
			close cur_updateList
			deallocate cur_updateList

		commit tran xmlProcessBlock
		print('commit tran xmlProcessBlock')	

		------- update the log entry with success
		update l set 
			l.EndDT=GETDATE()
			,l.IsSuccess=1
		from [log].[XMLParseLog] l
		where l.ID=@parseLogID;


	end try

	begin catch

		if (@@TRANCOUNT>0)
		begin
			rollback tran xmlProcessBlock
			print('rollback tran xmlProcessBlock')
		end
			
		if (select CURSOR_STATUS('global','cur_List'))>=0
		begin
			close cur_List
			deallocate cur_List
			print('deallocate cur_List')
		end	
			
		if (select CURSOR_STATUS('global','cur_updateList'))>=0
		begin
			close cur_updateList
			deallocate cur_updateList
			print('deallocate cur_updateList')
		end
		
		DECLARE @ErrorMessage VARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;
		--DECLARE @ErrorNumber INT;
		--DECLARE @ErrorLine INT;
		SELECT 
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE()/*,
		@ErrorNumber = ERROR_NUMBER(),
		@ErrorLine = ERROR_LINE()*/;

		------- update the log entry with failure
		update l set 
			l.EndDT=GETDATE()
			,l.IsSuccess=0
			,l.LogMsg=@ErrorMessage
		from [log].[XMLParseLog] l
		where l.ID=@parseLogID;

		RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState/*,@ErrorNumber,@ErrorLine*/)

	end catch


END




GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateParseLogFlagForDataVault]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Sunny Yang
-- Create date: 2015-12-30
-- Description:	Update the flag for data vault loading in the next run (for table [log].[ParseLogIDFlag] joining stage_vw views)
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateParseLogFlagForDataVault]

AS


BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	declare @ID int
			,@parseLogID1 int	-- for round1
			,@parseLogID2 int	-- for round2
			,@parseLogID1Max int
			,@parseLogID2Max int


	begin try
	
		/** Scopus on WIN1373

		SELECT min([parseLogID]), max([parseLogID]) --9 ~ 229
		  FROM [Scopus].[stage].[publication]
		;

		select  min([parseLogID]), max([parseLogID])  --503 ~ 721
		  FROM [Scopus].[stage].[pubsource]
		;


		select  min([parseLogID]), max([parseLogID])  --503 ~ 721; 271 ~ 488
		  FROM [Scopus].[stage].[pubabstract]
		;

		select  min([parseLogID]), max([parseLogID])  --503 ~ 721; 271 ~ 488
		  FROM [Scopus].[stage].[afforganisation]
		;
		
		*/

		--if exists (select 1 from [log].[ParseLogIDFlag] where [enabled]=1)
		--begin		
		--	select @parseLogID1 = max(isnull(PasrseLogID_1,0))+1
		--		,@parseLogID2 = max(isnull(PasrseLogID_2,0))+1
				
		--		,@parseLogID1Max = max(isnull(PasrseLogIDMax_1,0))
		--		,@parseLogID2Max = max(isnull(PasrseLogIDMax_2,0))
		--	from [log].[ParseLogIDFlag] where [enabled]=1
		--end
		--else
		--begin
		--	select @parseLogID1=min([parseLogID]) --
		--			,@parseLogID1Max=max([parseLogID])
		--		from [stage].[publication]
				
		--	select @parseLogID2=min([parseLogID]) --
		--			,@parseLogID2Max=max([parseLogID])
		--		from [stage].[afforganisation]
		--end


		/** 
		--234 ~ 452
		SELECT min([parseLogID]), max([parseLogID])
			FROM [Scopus].[stage].[author]
		;
		SELECT min([parseLogID]), max([parseLogID])
			 FROM [Scopus].[stage].[affiliation]
		;		
		*/

		if exists (select 1 from [log].[ParseLogIDFlag] where [enabled]=1)
		begin		
			select @parseLogID1 = max(isnull(PasrseLogID_1,0))+1
				,@parseLogID2 = max(isnull(PasrseLogID_2,0))+1
				,@parseLogID1Max = max(isnull(PasrseLogIDMax_1,0))
				,@parseLogID2Max = max(isnull(PasrseLogIDMax_2,0))
			from [log].[ParseLogIDFlag] where [enabled]=1
		end
		else
		begin
			select @parseLogID1=min([parseLogID]) 
					,@parseLogID1Max=max([parseLogID])
				from [stage].[affiliation]
				
			select @parseLogID2=min([parseLogID])
					,@parseLogID2Max=max([parseLogID])
				from [stage].[author]
		end

		--select @parseLogID1Max, @parseLogID2Max, @parseLogID1, @parseLogID2
		
		begin tran processBlock
		
			--while not exists (select 1 from [stage].[publication] where parseLogID=@parseLogID1)
			--		and @parseLogID1 <= @parseLogID1Max
			--	set @parseLogID1 = @parseLogID1+1

			--while not exists (select 1 from [stage].[afforganisation] where parseLogID=@parseLogID2)
			--		and @parseLogID2 <= @parseLogID2Max
			--	set @parseLogID2 = @parseLogID2+1


			while not exists (select 1 from [stage].[affiliation] where parseLogID=@parseLogID1)
					and @parseLogID1 <= @parseLogID1Max
				set @parseLogID1 = @parseLogID1+1

			while not exists (select 1 from [stage].[author] where parseLogID=@parseLogID2)
					and @parseLogID2 <= @parseLogID2Max
				set @parseLogID2 = @parseLogID2+1

			--select @parseLogID1Max, @parseLogID2Max, @parseLogID1, @parseLogID2
			
			if (@parseLogID1<=@parseLogID1Max or @parseLogID2<=@parseLogID2Max)
			begin
			insert into [log].[ParseLogIDFlag] (PasrseLogID_1, PasrseLogID_2, PasrseLogIDMax_1, PasrseLogIDMax_2, StartDT)
				values (@parseLogID1, @parseLogID2, @parseLogID1Max, @parseLogID2Max,GETDATE())
			
			--select @ID=IDENT_CURRENT('[log].[ParseLogIDFlag]')
			end

		commit tran processBlock

	end try

	begin catch

		if (@@TRANCOUNT>0)
		begin
			rollback tran processBlock
			print('rollback tran processBlock')
		end
	
		DECLARE @ErrorMessage VARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;
		--DECLARE @ErrorNumber INT;
		--DECLARE @ErrorLine INT;
		SELECT 
        @ErrorMessage = ERROR_MESSAGE(),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE()/*,
		@ErrorNumber = ERROR_NUMBER(),
		@ErrorLine = ERROR_LINE()*/;

		RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState/*,@ErrorNumber,@ErrorLine*/)

	end catch

	
	select max([ID]) as [ID]
			,@parseLogID1 as parseLogID1, @parseLogID1Max as parseLogID1Max
			,@parseLogID2 as parseLogID2, @parseLogID2Max as parseLogID2Max
		from [log].[ParseLogIDFlag] where [enabled]=1


END







GO
/****** Object:  UserDefinedFunction [dbo].[getSubString]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		S Yang
-- Create date: 2015-09-03
-- Description:	get substring
-- =============================================
CREATE FUNCTION [dbo].[getSubString] 
(
	-- Add the parameters for the function here
	@varStr nvarchar(50)
	, @varDividedStr varchar(20)
)
RETURNS nvarchar(50)
AS
BEGIN
	
	-- Return the result of the function
	RETURN SUBSTRING(@varStr,0, LEN(@varStr)-LEN(@varDividedStr)+1)

END

GO
/****** Object:  Table [config].[XMLLoadConfig]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [config].[XMLLoadConfig](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[FolderName] [nvarchar](50) NULL,
	[TableName] [nvarchar](50) NULL,
	[NumOfFiles] [int] NULL,
	[CreateDT] [datetime] NULL,
	[UpdateDT] [datetime] NULL,
	[enabled] [bit] NULL,
	[isTableReCreated] [bit] NULL,
 CONSTRAINT [PK_XMLLoadConfig] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [config].[XMLNameSpaceMapping]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [config].[XMLNameSpaceMapping](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[XmlType] [nvarchar](50) NULL,
	[XmlNameSpace] [varchar](500) NULL,
	[SourceTableName] [nvarchar](50) NULL,
	[CreateDT] [datetime] NULL,
	[UpdateDT] [datetime] NULL,
	[enabled] [bit] NULL,
 CONSTRAINT [PK_XMLNameSpaceMapping] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [config].[XMLParseConfig]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [config].[XMLParseConfig](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[SourceTable] [varchar](100) NULL,
	[SourceXMLColumn] [varchar](100) NULL,
	[SourceNodePath] [varchar](500) NULL,
	[SourceQueryColumn] [varchar](500) NULL,
	[DestTable] [varchar](100) NULL,
	[DestColumn] [varchar](100) NULL,
	[DestColumnType] [varchar](100) NULL,
	[nodeAlias] [varchar](100) NULL,
	[colNodeAlias] [varchar](100) NULL,
	[CreateDT] [datetime] NULL,
	[UpdateDT] [datetime] NULL,
	[enabled] [bit] NULL,
	[isPlainColumn] [bit] NULL,
 CONSTRAINT [PK_XMLParseConfig_20151126] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ani_citedby]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ani_citedby](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[SourceFileName] [nvarchar](50) NOT NULL,
	[XMLSource] [xml] NOT NULL,
	[loadLogID] [int] NULL,
	[parseLogID] [int] NULL,
	[parseFlag] [bit] NULL,
 CONSTRAINT [PK_ani_citedby] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ani_item]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ani_item](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[SourceFileName] [nvarchar](50) NOT NULL,
	[XMLSource] [xml] NOT NULL,
	[loadLogID] [int] NULL,
	[parseLogID] [int] NULL,
	[parseFlag] [bit] NULL,
 CONSTRAINT [PK_ani_item] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [log].[ErrXmlFileLog]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [log].[ErrXmlFileLog](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ZipFilePath] [nvarchar](255) NOT NULL,
	[XmlFileName] [nvarchar](50) NOT NULL,
	[InsertDate] [datetime2](7) NOT NULL,
	[LoadLogID] [int] NULL,
	[LogMsg] [varchar](1000) NULL,
 CONSTRAINT [PK_ErrXmlFileLog] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [log].[HashKeyGenLog]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [log].[HashKeyGenLog](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[parseLogID] [int] NULL,
	[StartDT] [datetime] NULL,
	[EndDT] [datetime] NULL,
	[IsSuccess] [bit] NULL,
	[LogMsg] [varchar](1000) NULL,
 CONSTRAINT [PK_HasKeyGenLog] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [log].[ParseLogIDFlag]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [log].[ParseLogIDFlag](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[PasrseLogID_1] [int] NULL,
	[PasrseLogID_2] [int] NULL,
	[PasrseLogID_3] [int] NULL,
	[PasrseLogIDMax_1] [int] NULL,
	[PasrseLogIDMax_2] [int] NULL,
	[PasrseLogIDMax_3] [int] NULL,
	[StartDT] [datetime] NULL,
	[EndDT] [datetime] NULL,
	[isFailed] [bit] NULL,
	[enabled] [bit] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [log].[XMLLoadLog]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [log].[XMLLoadLog](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ProcessedZipFileName] [nvarchar](50) NULL,
	[StartDT] [datetime] NULL,
	[EndDT] [datetime] NULL,
	[IsSuccess] [bit] NULL,
	[LogMsg] [varchar](1000) NULL,
 CONSTRAINT [PK_XMLLoadLog] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [log].[XMLParseLog]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [log].[XMLParseLog](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[StartDT] [datetime] NULL,
	[EndDT] [datetime] NULL,
	[IsSuccess] [bit] NULL,
	[LogMsg] [varchar](1000) NULL,
 CONSTRAINT [PK_XMLParseLog] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [stage].[affiliation]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[affiliation](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[ScopusAffiliationID] [bigint] NULL,
	[AffiliationCountry] [nchar](3) NULL,
	[ScopusDepartmentID] [bigint] NULL,
	[CityGroup] [nvarchar](500) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[nodePosition] [int] NULL,
	[parentNodePosition] [int] NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_affiliation_76846] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [stage].[affiliation_hashkey]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [stage].[affiliation_hashkey](
	[AffID] [bigint] NOT NULL,
	[AffiliationHashKey] [varbinary](20) NOT NULL,
	[genLogID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [stage].[afforganisation]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[afforganisation](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[OrganisationName] [nvarchar](500) NULL,
	[ScopusAffiliationID] [bigint] NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[nodePosition] [int] NULL,
	[parentNodePosition] [int] NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_afforganisation_20151218] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [stage].[afforganisation_concat]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [stage].[afforganisation_concat](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[OrganisationName] [nvarchar](max) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[parentNodePosition] [int] NULL,
	[AffiliationHashKey] [varbinary](20) NULL,
	[genLogID] [int] NULL,
 CONSTRAINT [PK_afforganisation_concat_1218] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [stage].[author]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[author](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[ScopusAuthorID] [bigint] NULL,
	[Surname] [nvarchar](20) NULL,
	[Firstname] [nvarchar](20) NULL,
	[PreferredSurname] [nvarchar](20) NULL,
	[PreferredFirstname] [nvarchar](20) NULL,
	[ScopusAffiliationID] [bigint] NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[Initials] [nvarchar](20) NULL,
	[PreferredInitials] [nvarchar](20) NULL,
	[nodePosition] [int] NULL,
	[parentNodePosition] [int] NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_author_13730] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [stage].[author_hashkey]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [stage].[author_hashkey](
	[AuthorID] [bigint] NOT NULL,
	[AuthorHashKey] [varbinary](20) NULL,
	[AffiliationHashKey] [varbinary](20) NULL,
	[genLogID] [int] NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [stage].[citedby]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[citedby](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[source_eid_withsuffix] [nvarchar](50) NULL,
	[citedby_eid] [nvarchar](25) NULL,
	[parseLogID] [int] NULL,
	[source_eid] [nvarchar](25) NULL,
 CONSTRAINT [PK_citedby] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [stage].[classification]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[classification](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[ScopusSourceID] [bigint] NULL,
	[AllScienceJournalClassification] [nvarchar](50) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_classification] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [stage].[pubabstract]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[pubabstract](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Abstract] [nvarchar](max) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_pubabstract_41566] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [stage].[pubabstract_concat]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[pubabstract_concat](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Abstract] [nvarchar](max) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[genLogID] [int] NULL,
 CONSTRAINT [PK_pubabstract_concat] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [stage].[pubauthorkeyword]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[pubauthorkeyword](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[AuthorKeyword] [nvarchar](500) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_pubauthorkeyword_3489] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [stage].[pubdoctype]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[pubdoctype](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[PublicationType] [nchar](2) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_pubdoctype] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [stage].[publication]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[publication](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[ScopusPublicationID] [int] NULL,
	[DOI] [nvarchar](30) NULL,
	[PublicationYear] [nvarchar](10) NULL,
	[ISSN] [nvarchar](10) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_publication] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [stage].[pubsource]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [stage].[pubsource](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[PublishedIn] [nchar](1) NULL,
	[ScopusSourceID] [bigint] NULL,
	[JournalOrCollectionName] [nvarchar](max) NULL,
	[ScopusElectronicIdentifier] [nvarchar](25) NULL,
	[parseLogID] [int] NULL,
 CONSTRAINT [PK_pubsource_20151216] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  View [stage_vw].[ParseLogFlag]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








CREATE View [stage_vw].[ParseLogFlag]
as 
SELECT max(isnull([PasrseLogID_1],0)) as [PasrseLogID_1]
		,max(isnull([PasrseLogID_2],0)) as [PasrseLogID_2]
  FROM [log].[ParseLogIDFlag]
  where [enabled]=1








GO
/****** Object:  View [stage_vw].[PublicationAffiliationAuthor]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








CREATE View [stage_vw].[PublicationAffiliationAuthor]
as 
SELECT distinct
	isnull(t1.ScopusElectronicIdentifier,t2.ScopusElectronicIdentifier) as ScopusElectronicIdentifier
	,t1.AffiliationHashKey
	,t2.AuthorHashKey
  FROM 
(select af.ScopusElectronicIdentifier
	,afk.AffiliationHashKey
from [stage].[affiliation] af
  join [stage_vw].[ParseLogFlag] f on af.parseLogID=f.PasrseLogID_1
  join [stage].[affiliation_hashkey] afk on af.ID=afk.AffID) as t1
full join
(select au.ScopusElectronicIdentifier
	,auk.AuthorHashKey
	,auk.AffiliationHashKey
from  [stage].[author] au
  join [stage_vw].[ParseLogFlag] f on au.parseLogID=f.PasrseLogID_2
  join [stage].[author_hashkey] auk on au.ID=auk.AuthorID) as t2
on t1.ScopusElectronicIdentifier=t2.ScopusElectronicIdentifier
	and t1.AffiliationHashKey=t2.AffiliationHashKey










GO
/****** Object:  View [stage_vw].[Publication]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





CREATE VIEW [stage_vw].[Publication]
AS
SELECT p.[ScopusElectronicIdentifier]
	,p.[ScopusPublicationID]
	,p.[DOI]
	,pa.[Abstract]
	,p.[PublicationYear]
	,pd.[PublicationType]
	,ps.[PublishedIn]
	,ps.[ScopusSourceID]
	,ps.[JournalOrCollectionName]
	,p.[ISSN]
FROM [stage].[publication] p
join [stage_vw].[ParseLogFlag] f on p.parseLogID=f.PasrseLogID_1
LEFT JOIN [stage].pubabstract_concat pa ON p.ScopusElectronicIdentifier = pa.ScopusElectronicIdentifier
LEFT JOIN [stage].pubdoctype pd ON p.ScopusElectronicIdentifier = pd.ScopusElectronicIdentifier
LEFT JOIN [stage].pubsource ps ON p.ScopusElectronicIdentifier = ps.ScopusElectronicIdentifier










GO
/****** Object:  View [stage_vw].[Affiliation]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







CREATE View [stage_vw].[Affiliation]
as 
SELECT distinct 
	a.[ScopusAffiliationID]
      ,a.[ScopusDepartmentID]
      ,a.[AffiliationCountry]
      ,a.[CityGroup]
	  ,ahk.AffiliationHashKey
  FROM [stage].[affiliation] a
  join [stage_vw].[ParseLogFlag] f on a.parseLogID=f.PasrseLogID_2
  join [stage].[affiliation_hashkey] ahk on a.ID=ahk.AffID
--where a.[ScopusAffiliationID] is not null









GO
/****** Object:  View [stage_vw].[Author]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






CREATE View [stage_vw].[Author]
as 
SELECT distinct [ScopusAuthorID]
      ,[Surname]
      ,[Firstname]
	  ,a.Initials
      ,[PreferredFirstname]
	  ,[PreferredSurname]
	  ,a.PreferredInitials
	  ,k.AuthorHashKey
  FROM [stage].[author] a
  join [stage_vw].[ParseLogFlag] f on a.parseLogID=f.PasrseLogID_2
  join [stage].[author_hashkey] k on a.ID=k.AuthorID







GO
/****** Object:  View [stage_vw].[AffiliationAuthor]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO










CREATE View [stage_vw].[AffiliationAuthor]
as 
SELECT distinct auk.AuthorHashKey
	,auk.AffiliationHashKey
from  [stage].[author_hashkey] auk
	join [stage].[author] a on auk.AuthorID=a.ID
	join [stage_vw].[ParseLogFlag] f on a.parseLogID=f.PasrseLogID_2
where auk.AffiliationHashKey is not null
--and auk.AuthorHashKey is not null
 









GO
/****** Object:  View [stage_vw].[AffiliationOrganisation]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO









CREATE View [stage_vw].[AffiliationOrganisation]
as 
SELECT distinct 
		--[OrganisationName]
		hashbytes('SHA1',upper([OrganisationName])) as OrganisationNameHashKey
		,[AffiliationHashKey]
  FROM [stage].[afforganisation_concat] o
  join [log].[HashKeyGenLog] l on o.genLogID=l.ID
  join [stage_vw].[ParseLogFlag] f on l.parseLogID=f.PasrseLogID_2
  where [AffiliationHashKey] is not null











GO
/****** Object:  View [stage_vw].[Citations]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







CREATE View [stage_vw].[Citations]
as 
SELECT distinct p1.ScopusElectronicIdentifier as CitedScopusPublicationEID
		,p1.ScopusPublicationID as CitedScopusPublicationID
		,p1.PublicationYear as CitedPublicationYear
  FROM [stage].[citedby] ci
  join [stage_vw].[ParseLogFlag] f on ci.parseLogID=f.PasrseLogID_1
  join [stage].[publication] p1 on ci.[source_eid]=p1.ScopusElectronicIdentifier









GO
/****** Object:  View [stage_vw].[PublicationAffiliation]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








CREATE View [stage_vw].[PublicationAffiliation]
as 
SELECT distinct
	afk.AffiliationHashKey
	,af.ScopusElectronicIdentifier
from [stage].[affiliation] af 
	join [stage_vw].[ParseLogFlag] f on af.parseLogID=f.PasrseLogID_2
	join [stage].[affiliation_hashkey] afk on af.ID=afk.AffID






GO
/****** Object:  View [stage_vw].[PublicationAuthor]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO









CREATE View [stage_vw].[PublicationAuthor]
as 
SELECT distinct auk.AuthorHashKey
	--,auk.AffiliationHashKey
	,au.ScopusElectronicIdentifier
from  [stage].[author] au
	join [stage_vw].[ParseLogFlag] f on au.parseLogID=f.PasrseLogID_2
	join [stage].[author_hashkey] auk on au.ID=auk.AuthorID








GO
/****** Object:  View [stage_vw].[PublicationAuthorKeyword]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







CREATE view [stage_vw].[PublicationAuthorKeyword]
as 
SELECT distinct 
		--[AuthorKeyword]
		hashbytes('SHA1',upper([AuthorKeyword])) as AuthorKeywordHashKey
		,[ScopusElectronicIdentifier]
  FROM [stage].[pubauthorkeyword] k
  join [stage_vw].[ParseLogFlag] f on k.parseLogID=f.PasrseLogID_2







GO
/****** Object:  View [stage_vw].[PublicationCitations]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








CREATE View [stage_vw].[PublicationCitations]
as 
SELECT distinct p1.ScopusElectronicIdentifier as CitedScopusPublicationEID
		,p2.ScopusElectronicIdentifier as CitingScopusPublicationEID
  FROM [stage].[citedby] ci
  join [stage_vw].[ParseLogFlag] f on ci.parseLogID=f.PasrseLogID_1
  join [stage].[publication] p1 on ci.source_eid = p1.ScopusElectronicIdentifier
  join [stage].[publication] p2 on ci.citedby_eid = p2.ScopusElectronicIdentifier

--[source_eid] --9383
--[citedby_eid] --160,656





GO
/****** Object:  View [stage_vw].[PublicationClassification]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO









CREATE View [stage_vw].[PublicationClassification]
as
SELECT distinct [ScopusElectronicIdentifier]
	,[AllScienceJournalClassification] as [ASJCCode]
  FROM [stage].[classification] c
  join [stage_vw].[ParseLogFlag] f on c.parseLogID=f.PasrseLogID_1
--where [AllScienceJournalClassification] is not null











GO
/****** Object:  View [stage_vw].[AuthorKeyword]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








CREATE view [stage_vw].[AuthorKeyword]
as 
SELECT distinct upper([AuthorKeyword]) as [AuthorKeyword]
		,hashbytes('SHA1',upper([AuthorKeyword])) as AuthorKeywordHashKey
  FROM [Scopus].[stage].[pubauthorkeyword] a
  join [stage_vw].[ParseLogFlag] f on a.parseLogID=f.PasrseLogID_2








GO
/****** Object:  View [stage_vw].[Organisation]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








CREATE View [stage_vw].[Organisation]
as 
SELECT distinct upper([OrganisationName]) as [OrganisationName]
		,hashbytes('SHA1',upper([OrganisationName])) as OrganisationNameHashKey
  FROM [stage].[afforganisation_concat] o
  join [log].[HashKeyGenLog] l on o.genLogID=l.ID
  join [stage_vw].[ParseLogFlag] f on l.parseLogID=f.PasrseLogID_2















GO
/****** Object:  View [stage_vw].[ASJCClassification]    Script Date: 18/01/2016 4:28:39 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






CREATE View [stage_vw].[ASJCClassification]
as
SELECT distinct [AllScienceJournalClassification] as [ASJCCode]
  FROM [stage].[classification]








GO
ALTER TABLE [config].[XMLLoadConfig] ADD  DEFAULT (getdate()) FOR [CreateDT]
GO
ALTER TABLE [config].[XMLLoadConfig] ADD  DEFAULT ((1)) FOR [enabled]
GO
ALTER TABLE [config].[XMLLoadConfig] ADD  DEFAULT ((0)) FOR [isTableReCreated]
GO
ALTER TABLE [config].[XMLNameSpaceMapping] ADD  DEFAULT (getdate()) FOR [CreateDT]
GO
ALTER TABLE [config].[XMLNameSpaceMapping] ADD  DEFAULT ((1)) FOR [enabled]
GO
ALTER TABLE [config].[XMLParseConfig] ADD  DEFAULT ('varchar(100)') FOR [DestColumnType]
GO
ALTER TABLE [config].[XMLParseConfig] ADD  DEFAULT (getdate()) FOR [CreateDT]
GO
ALTER TABLE [config].[XMLParseConfig] ADD  DEFAULT ((1)) FOR [enabled]
GO
ALTER TABLE [config].[XMLParseConfig] ADD  DEFAULT ((0)) FOR [isPlainColumn]
GO
ALTER TABLE [log].[ParseLogIDFlag] ADD  DEFAULT ((0)) FOR [isFailed]
GO
ALTER TABLE [log].[ParseLogIDFlag] ADD  DEFAULT ((1)) FOR [enabled]
GO
