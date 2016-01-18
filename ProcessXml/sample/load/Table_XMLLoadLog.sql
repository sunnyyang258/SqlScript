
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[log].[XMLLoadLog]') AND type in (N'U'))
	DROP TABLE [log].[XMLLoadLog]
GO

/****** Object:  Table [log].[XMLLoadLog]    Script Date: 2/09/2015 2:21:01 p.m. ******/
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