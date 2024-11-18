/*DB PERMISSIONS*/
-- parametr s nazvem db user accountu
declare @userName nvarchar(100) = '<add user name here>'

-- uzivatel a jeho clenstvi ve vsech DB rolich
-- -- Pozn.: pro fixed db roles nejsou videt permissions, protoze nejsou nikde explicitne vypsane
;with db_principal as
(
    select principal_id, name, type_desc from sys.database_principals where name = @userName
    union ALL
    select drm.role_principal_id, dp.name, dp.type_desc 
    from sys.database_role_members as drm
        join db_principal on drm.member_principal_id = db_principal.principal_id
        join sys.database_principals as dp on dp.principal_id = drm.role_principal_id
)
select
    db_principal.name as principal_name
    , db_principal.type_desc
    , class_desc
    -- , major_id
    -- , minor_id
    , case class_desc
        when 'OBJECT_OR_COLUMN' then 
                CONCAT(OBJECT_SCHEMA_NAME(major_id), '.', OBJECT_NAME(major_id), (select '.' + name from sys.all_columns where object_id = major_id and column_id = minor_id))
        when 'SCHEMA' then SCHEMA_NAME(major_id)
        when 'DATABASE' then DB_NAME()
        else NULL
      end as entity_name
    , permission_name
    , state_desc
from db_principal
    left join sys.database_permissions as dp on db_principal.principal_id = dp.grantee_principal_id