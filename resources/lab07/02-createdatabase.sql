USE [Leaderboard]
GO

/****** Object:  Table [dbo].[Gamers]    Script Date: 5/9/2017 8:29:17 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Gamers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[GamerGuid] [uniqueidentifier] NOT NULL,
	[Nickname] [nvarchar](max) NULL,
 CONSTRAINT [PK_Gamers] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

/****** Object:  Table [dbo].[Scores]    Script Date: 5/9/2017 8:30:25 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Scores](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Game] [nvarchar](max) NULL,
	[GamerId] [int] NOT NULL,
	[Points] [int] NOT NULL,
 CONSTRAINT [PK_Scores] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

ALTER TABLE [dbo].[Scores]  WITH CHECK ADD  CONSTRAINT [FK_Scores_Gamers_GamerId] FOREIGN KEY([GamerId])
REFERENCES [dbo].[Gamers] ([Id])
ON DELETE CASCADE
GO

ALTER TABLE [dbo].[Scores] CHECK CONSTRAINT [FK_Scores_Gamers_GamerId]
GO

INSERT INTO [dbo].[Gamers]
           ([GamerGuid]
           ,[Nickname])
     VALUES
           (CONVERT(uniqueidentifier, 'AE019609-99E0-4EF5-85BB-AD90DC302E70'), 'LX360'),
           (CONVERT(uniqueidentifier, 'AE019609-99E0-4EF5-85BB-AD90DC302E71'), 'Geekg1rL'),
           (CONVERT(uniqueidentifier, 'AE019609-99E0-4EF5-85BB-AD90DC302E72'), 'PlayerOne')
GO