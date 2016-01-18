

/****** Object:  UserDefinedFunction [dbo].[getSubString]    Script Date: 4/09/2015 10:24:03 a.m. ******/
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
