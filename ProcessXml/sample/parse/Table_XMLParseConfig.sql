
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[config].[XMLParseConfig]') AND type in (N'U'))
	DROP TABLE [config].[XMLParseConfig]
GO

/****** Object:  Table [config].[XMLParseConfig]    Script Date: 27/08/2015 10:48:20 a.m. ******/
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
	[CreateDT] datetime null,
	[UpdateDT] datetime null,
	[enabled] [bit] NULL,
	[isPlainColumn] [bit] NULL,
 CONSTRAINT [PK_XMLParseConfig] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

ALTER TABLE [config].[XMLParseConfig] ADD  DEFAULT ('varchar(100)') FOR [DestColumnType]
GO

ALTER TABLE [config].[XMLParseConfig] ADD  DEFAULT GETDATE() FOR [CreateDT]
GO

ALTER TABLE [config].[XMLParseConfig] ADD  DEFAULT ((1)) FOR [enabled]
GO

ALTER TABLE [config].[XMLParseConfig] ADD  DEFAULT ((0)) FOR [isPlainColumn]
GO