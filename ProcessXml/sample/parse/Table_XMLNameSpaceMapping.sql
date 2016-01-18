
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[config].[XMLNameSpaceMapping]') AND type in (N'U'))
	DROP TABLE [config].[XMLNameSpaceMapping]
GO

/****** Object:  Table [config].[XMLNameSpaceMapping]    Script Date: 3/09/2015 3:53:10 p.m. ******/
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

ALTER TABLE [config].[XMLNameSpaceMapping] ADD  DEFAULT (getdate()) FOR [CreateDT]
GO

ALTER TABLE [config].[XMLNameSpaceMapping] ADD  DEFAULT ((1)) FOR [enabled]
GO
