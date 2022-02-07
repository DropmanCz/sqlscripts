declare @hledanaHodnota NVARCHAR(100) = 'Red'

declare @sql nvarchar(1000)
declare crs cursor for
with metadata as
(
select
    CONCAT(OBJECT_SCHEMA_NAME(t.object_id), '.', t.name) as full_table_name 
    , STRING_AGG( concat('[', c.name, ']', ' LIKE ''%', @hledanaHodnota, '%'''), ' OR ') as complex_predicate
from sys.tables as t
    join sys.columns as c on t.object_id = c.object_id
where c.system_type_id in (231, 35, 99, 167, 175, 239)
GROUP BY CONCAT(OBJECT_SCHEMA_NAME(t.object_id), '.', t.name)
)
select 
'IF EXISTS(SELECT * FROM ' + full_table_name + ' WHERE ' + complex_predicate + ') PRINT ''' + full_table_name + ''''
from metadata

open crs
fetch crs into @sql
while @@FETCH_STATUS = 0
 BEGIN
    -- print(@sql)
    EXEC(@sql)
    fetch crs into @sql
 END
 close crs
 deallocate crs