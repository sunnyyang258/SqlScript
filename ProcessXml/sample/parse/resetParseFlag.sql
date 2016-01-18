

--update a set a.[parseFlag]=0
select count(1)
from [Scopus].[dbo].[ani_item] a
where a.[parseFlag]=1
;


--update c set c.[parseFlag]=0
select count(1)
from [Scopus].[dbo].[ani_citedby] c
where c.[parseFlag]=1
;