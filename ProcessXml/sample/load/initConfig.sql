use [Scopus]

insert into [config].[XMLLoadConfig]
([FolderName]
      ,[TableName]
      ,[NumOfFiles])
values
('ANI-ITEM','dbo.ani_item',1);

insert into [config].[XMLLoadConfig]
([FolderName]
      ,[TableName]
      ,[NumOfFiles])
values
('ANI-CITEDBY','dbo.ani_citedby',1);


--insert into [config].[XMLLoadConfig]
--([FolderName]
--      ,[TableName]
--      ,[NumOfFiles])
--values
--('ANI-ITEM_test','dbo.ani_item_test',1);