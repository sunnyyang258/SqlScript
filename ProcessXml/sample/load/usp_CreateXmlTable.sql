
if exists (select * from sys.objects where object_id = OBJECT_ID(N'[dbo].[usp_CreateXmlTable]') and type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[usp_CreateXmlTable];
GO

/****** Object:  StoredProcedure [dbo].[usp_CreateXmlTable]    Script Date: 2/09/2015 2:15:05 p.m. ******/
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