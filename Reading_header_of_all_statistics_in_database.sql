use AdventureWorks
go

drop table if exists #stats	-- 2016
create table #stats
(
Name sysname
, Updated datetime
, Rows bigint
, Rows_Sampled bigint
, Steps tinyint
, Density float
, Avg_Key_Lehgth float
, String_Index nvarchar(3)
, Filter_Expr nvarchar(2000)
, Unfiltered_Rows bigint
)

declare @objName nvarchar(200), @statName nvarchar(1000), @sql nvarchar(2000)

declare crs cursor
for
select OBJECT_SCHEMA_NAME(s.object_id) + '.' + OBJECT_NAME(s.object_id) as FullObjectName
	, s.name as StatName
from sys.stats as s 
where OBJECT_SCHEMA_NAME(s.object_id) != 'sys'

open crs
fetch crs into @objName, @statName
while @@FETCH_STATUS = 0
 begin
	set @sql = 'DBCC SHOW_STATISTICS(''' + @objName + ''', ''' + @statName + ''') WITH STAT_HEADER, NO_INFOMSGS'
	insert #stats
	exec(@sql)
	fetch crs into @objName, @statName
 end
close crs
deallocate crs

select * from #stats