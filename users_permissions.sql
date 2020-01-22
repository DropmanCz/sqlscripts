select
	--dp.name as user_name
	p.class_desc
	, p.permission_name
	, s.name as schema_name
	, concat(OBJECT_SCHEMA_NAME(o.object_id), '.', o.name) as full_object_name
	--, p.*
from sys.database_principals as dp
	join sys.database_permissions as p on dp.principal_id = p.grantee_principal_id
	left join sys.schemas as s on p.major_id = s.schema_id and p.class_desc = 'SCHEMA'
	left join sys.all_objects as o on p.major_id = o.object_id and p.class_desc = 'OBJECT_OR_COLUMN'
where dp.name = 'WocoDwhTest'
	and p.state_desc = 'GRANT'
	and p.class_desc != 'DATABASE'
