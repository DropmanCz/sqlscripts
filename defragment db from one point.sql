use master
go

create or alter proc sp_reindex
    @minPageCount int = 100             -- eliminates tables which are too small
    , @minFragmentationInPercent int = 10   -- sets the minimum value of AVG fragmentation in percent
    , @dbIds NVARCHAR(1000) = NULL      -- if executed for more databases, set it as a commma separated list of DBs (i.e. '7, 8, 9')
                                        -- if just one database should be defragmented, leave it NULL and execute the procedure within the context of the database
    , @reindexAllUserDbs bit = 0        -- if all user databases need to be defragmented, set it to 1
as
set nocount on
create table #dbs (database_id int)

if @dbIds is NULL
 begin
    if @reindexAllUserDbs = 1
        insert #dbs
        select database_id
        from sys.databases 
        where 
            state_desc = 'ONLINE'
            and database_id > 4 and database_id < 32767
    ELSE
        insert #dbs values (DB_ID())
 end
ELSE
    insert #dbs
    select value from string_split(@dbIds, ',')
select
	stat.index_id
    , stat.object_id
    , QUOTENAME(DB_NAME(stat.database_id)) as DatabaseName
	, CONCAT(
        QUOTENAME(DB_NAME(stat.database_id)), '.'
        , QUOTENAME(OBJECT_SCHEMA_NAME(stat.object_id, stat.database_id)), '.'
	    , QUOTENAME(OBJECT_NAME(stat.object_id, stat.database_id))) as FullObjectName
    , stat.avg_fragmentation_in_percent
into #stat
from #dbs 
    cross apply sys.dm_db_index_physical_stats(database_id, null, null, null, null) as stat
where 1 = 1
	and stat.avg_fragmentation_in_percent >= @minFragmentationInPercent
	and stat.page_count >= @minPageCount
	and stat.alloc_unit_type_desc = 'IN_ROW_DATA'

create table #crs
(
DbName nvarchar(255)
, FullObjectName nvarchar(256)
, IndexName nvarchar(500)
, index_id int
, avg_fragmentation_in_percent dec(6, 3)
)
declare @sql nvarchar(max) = 
'insert #crs
select distinct
	stat.DatabaseName
    , stat.FullObjectName
    , i.name as IndexName
    , stat.index_id
	, stat.avg_fragmentation_in_percent
from #stat as stat
	left join $db$.sys.indexes as i on i.object_id = stat.object_id and i.index_id = stat.index_id
where stat.DatabaseName = ''$db$''
order by FullObjectName, stat.index_id'
    , @dbname nvarchar(128)
    , @sqlDef nvarchar(max)

declare crsDb cursor 
for
select distinct DatabaseName from #stat
open crsDb
fetch crsDb into @dbName
while @@FETCH_STATUS = 0
 BEGIN
    set @sqlDef = replace(@sql, '$db$', @dbname)
    exec(@sqlDef)
    fetch crsDb into @dbName
 END
CLOSE crsDb
DEALLOCATE crsDb

declare @fullObjectName nvarchar(500)
	, @fullIndexName nvarchar(500)
	, @fullIndexId int
	, @fullFrag dec(6, 3)
	, @defragSQL nvarchar(2000)
	, @startTime datetime2 = sysdatetime()

declare crs cursor local
for
select FullObjectName, IndexName, index_id, avg_fragmentation_in_percent from #crs
open crs
fetch crs into @fullObjectName, @fullIndexName, @fullIndexId, @fullFrag
while @@FETCH_STATUS = 0 and SYSDATETIME() < dateadd(hh, 1, @startTime)
 begin
	if @fullIndexId = 0		-- heap
		set @defragSQL = 'ALTER TABLE ' + @fullObjectName + ' REBUILD'
	else
	 begin
		set @defragSQL = 'ALTER INDEX ' + @fullIndexName + ' ON ' + @fullObjectName
			+ iif(@fullFrag < 30, ' REORGANIZE', ' REBUILD')
		if @fullFrag < 30
			set @defragSQL += ' UPDATE STATISTICS ' + @fullObjectName 
	 end

    -- print @defragSQL
	exec(@defragSQL)
	fetch crs into @fullObjectName, @fullIndexName, @fullIndexId, @fullFrag
 end
close crs
deallocate crs
go