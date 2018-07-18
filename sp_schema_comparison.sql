use master
go

create proc sp_compare_schema
	@sourceDatabase nvarchar(100) = null -- for example	= 'AdventureWorks'
	, @destinationDatabase nvarchar(100) -- for example = 'localhost.AdventureWorksCopy'
as

if @sourceDatabase is null
	set @sourceDatabase = DB_NAME()

if @destinationDatabase is null
 begin
	RAISERROR('@sourceDatabase parameter is missing', 16, 1)
	return
 end

-- temp structure cleansing and preparation on beginning
if  object_id('tempdb.dbo.#sourceSchema') is not null
	drop table #sourceSchema

if  object_id('tempdb.dbo.#destSchema') is not null
	drop table #destSchema

create table #sourceSchema
(
object_id bigint
, FullObjectName nvarchar(500)
, type_desc nvarchar(70)
, create_date datetime
, modify_date datetime
, parent_object_id bigint
-- , ParentObjectName nvarchar(500) null
, Lvl tinyint
)
create table #destSchema
(
object_id bigint
, FullObjectName nvarchar(500)
, type_desc nvarchar(70)
, create_date datetime
, modify_date datetime
, parent_object_id bigint
-- , ParentObjectName nvarchar(500) null
, Lvl tinyint
)

-- sql query stub
declare  @sql nvarchar(max) = 
'with ObjectHierarchy as
(
select o.object_id 
	, cast(s.name + ''.'' + o.name as nvarchar(500)) as FullObjectName
	, type_desc
	, create_date
	, modify_date
	, o.parent_object_id
	-- , CAST(NULL as nvarchar(500)) as ParentObjectName
	, 0 as Lvl
from %db%.sys.objects as o 
	join %db%.sys.schemas as s on o.schema_id = s.schema_id
where o.is_ms_shipped = 0
	and parent_object_id = 0
union all
select o.object_id 
	, cast(o.name as nvarchar(500)) as FullObjectName
	, o.type_desc
	, o.create_date
	, o.modify_date
	, o.parent_object_id
	-- , cast(ObjectHierarchy.FullObjectName as nvarchar(500)) as ParentObjectName
	, ObjectHierarchy.Lvl + 1
from %db%.sys.objects as o 
	join %db%.sys.schemas as s on o.schema_id = s.schema_id
	join ObjectHierarchy on ObjectHierarchy.object_id = o.parent_object_id
)
select * from ObjectHierarchy'

-- sql queries for source schema and dest. schema
declare @srcSql nvarchar(max) = (replace(replace(@sql, '%db%', @sourceDatabase), '%tbl%', '#sourceSchema'))
declare @dstSql nvarchar(max) = (replace(replace(@sql, '%db%', @destinationDatabase ), '%tbl%', '#destSchema'))

-- filling objects for comparison
--print @srcSql
insert #sourceSchema
exec(@srcSql)

insert #destSchema
exec(@dstSql)

select s.*
	, case when d.object_id is null then 'Missing' else 'Modified' end as DifferenceTypeDec
from #sourceSchema as s
	left join #destSchema as d on s.FullObjectName = d.FullObjectName
where d.object_id is null
	or d.modify_date < s.modify_date
go