select tablespace_name||','||bytes
from user_free_space
where tablespace_name='&1'
and bytes >= &2
/

