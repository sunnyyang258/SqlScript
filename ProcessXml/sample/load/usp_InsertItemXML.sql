
if exists (select * from sys.objects where object_id = OBJECT_ID(N'[dbo].[usp_InsertItemXML]') and type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[usp_InsertItemXML];
GO

/****** Object:  StoredProcedure [dbo].[usp_InsertItemXML]    Script Date: 28/08/2015 10:12:36 a.m. ******/
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


