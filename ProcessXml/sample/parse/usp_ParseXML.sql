
if exists (select * from sys.objects where object_id = OBJECT_ID(N'[dbo].[usp_ParseXML]') and type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[usp_ParseXML];
GO

/****** Object:  StoredProcedure [dbo].[usp_ParseXML]    Script Date: 27/08/2015 10:38:15 a.m. ******/
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
	@rowNum INT = 5 -- indicate the number of rows of the source table(s) for loading
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
		
		SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

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
				--set @SQL_SrcTableDataset = '(select top ('+cast(@rowNum as varchar(10))+') * from '+@SQL_SrcTableName
				--					+' where isnull(parseFlag,0)=0'
				--					+' order by ID ASC) as src'
				set @SQL_SrcTableDataset = '(select [ID]
									  ,[SourceFileName]
									  ,[XMLSource]
									  ,[loadLogID]
									  ,[parseLogID]
									  ,[parseFlag]'
									+' from '+@SQL_SrcTableName
									+' where isnull(parseFlag,0)=0'
									+' order by ID ASC'
									+' OFFSET 0 ROWS FETCH NEXT '+cast(@rowNum as varchar(10))+' ROWS ONLY'
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