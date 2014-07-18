select
   name
,  text
from user_source
where type = 'PACKAGE BODY'
and line = 1
and text not like '%wrapped%'
/

