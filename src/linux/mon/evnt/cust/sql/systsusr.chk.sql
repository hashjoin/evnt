select username||','||default_tablespace||','||temporary_tablespace||','|| 
       to_char(created,'RRRR-MON-DD HH24:MI:SS')
from dba_users
where default_tablespace='SYSTEM'
/

