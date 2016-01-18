/****** Object:  Table [log].[XMLParseLog]    Script Date: 27/08/2015 10:49:16 a.m. ******/
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[log].[XMLParseLog]') AND type in (N'U'))
	DROP TABLE [log].[XMLParseLog]
GO

/****** Object:  Table [log].[XMLParseLog]    Script Date: 27/08/2015 10:49:16 a.m. ******/
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
