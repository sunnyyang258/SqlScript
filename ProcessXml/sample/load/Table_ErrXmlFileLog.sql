
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[log].[ErrXmlFileLog]') AND type in (N'U'))
	DROP TABLE [log].[ErrXmlFileLog]
GO

/****** Object:  Table [log].[ErrXmlFileLog]    Script Date: 2/09/2015 2:24:33 p.m. ******/
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


