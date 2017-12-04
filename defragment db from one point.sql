use master
go

create or alter proc sp_reindex
as
select
	stat.index_id
	, stat.object_id
	, DB_NAME() as DatabaseName
	, stat.avg_fragmentation_in_percent
into #stat
from sys.dm_db_index_physical_stats(db_id(), null, null, null, null) as stat
where 1 = 1
	and stat.avg_fragmentation_in_percent >= 20 
	and stat.page_count >= 100
	and stat.alloc_unit_type_desc = 'IN_ROW_DATA'

create table #crs
(
ObjectName nvarchar(256)
, IndexName nvarchar(500)
, index_id int
, avg_fragmentation_in_percent dec(6, 3)
)
declare @sql nvarchar(max) = 
'insert #crs
select distinct
	s.name + ''.'' + o.name as ObjectName
	, i.name as IndexName
	, i.index_id
	, stat.avg_fragmentation_in_percent
from #stat as stat
	join $db$.sys.objects as o on o.object_id = stat.object_id
	join $db$.sys.schemas as s on s.schema_id = o.schema_id
	left join $db$.sys.indexes as i on i.object_id = o.object_id and i.index_id = stat.index_id
order by ObjectName, i.index_id'
declare @dbname nvarchar(128) = (select top(1) DatabaseName from #stat)
set @sql = replace(@sql, '$db$', @dbname)
exec(@sql)

declare @fullObjectName nvarchar(500)
	, @fullIndexName nvarchar(500)
	, @fullIndexId int
	, @fullFrag dec(6, 3)
	, @defragSQL nvarchar(2000)
	, @startTime datetime2 = sysdatetime()

declare crs cursor local
for
select @dbname + '.' + ObjectName, IndexName, index_id, avg_fragmentation_in_percent from #crs
open crs
fetch crs into @fullObjectName, @fullIndexName, @fullIndexId, @fullFrag
while @@FETCH_STATUS = 0 and SYSDATETIME() < dateadd(hh, 1, @startTime)
 begin
	if @fullIndexId = 0		-- heap
		set @defragSQL = 'ALTER TABLE ' + @fullObjectName + ' REBUILD'

	if @fullIndexId = 1
	 begin
		delete #crs where @dbname + '.' + ObjectName = @fullObjectName and index_id > 1
		set @defragSQL = 'ALTER INDEX ' + @fullIndexName + ' ON ' + @fullObjectName
			+ iif(@fullFrag < 30, ' REORGANIZE', ' REBUILD')
		if @fullFrag < 30
			set @defragSQL += ' UPDATE STATISTICS ' + @fullObjectName 
	 end

	exec(@defragSQL)
	fetch crs into @fullObjectName, @fullIndexName, @fullIndexId, @fullFrag
 end
close crs
deallocate crs
go