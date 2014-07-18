set lines 85
set pages 60
col default_tablespace format a15 heading "DEFAULT TS"
col temporary_tablespace format a15 heading "TEMP TS"

ttit "USERS with default ts=SYSTEM"

select username, default_tablespace, temporary_tablespace, 
       to_char(created,'RRRR-MON-DD HH24:MI:SS') created
from dba_users
where default_tablespace='SYSTEM'
/

