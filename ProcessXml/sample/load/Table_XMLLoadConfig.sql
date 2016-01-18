
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[config].[XMLLoadConfig]') AND type in (N'U'))
	DROP TABLE [config].[XMLLoadConfig]
GO

/****** Object:  Table [config].[XMLLoadConfig]    Script Date: 2/09/2015 2:16:35 p.m. ******/
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

ALTER TABLE [config].[XMLLoadConfig] ADD  DEFAULT (getdate()) FOR [CreateDT]
GO

ALTER TABLE [config].[XMLLoadConfig] ADD  DEFAULT ((1)) FOR [enabled]
GO

ALTER TABLE [config].[XMLLoadConfig] ADD  DEFAULT ((0)) FOR [isTableReCreated]
GO


