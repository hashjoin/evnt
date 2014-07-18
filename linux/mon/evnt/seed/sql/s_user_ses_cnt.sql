REM
REM DBAToolZ NOTE:
REM	This script was obtained from DBAToolZ.com
REM	It's configured to work with SQL Directory (SQLDIR).
REM	SQLDIR is a utility that allows easy organization and
REM	execution of SQL*Plus scripts using user-friendly menu.
REM	Visit DBAToolZ.com for more details and free SQL scripts.
REM
REM 
REM File:
REM     s_user_ses_cnt.sql
REM
REM <SQLDIR_GRP>USER</SQLDIR_GRP>
REM 
REM Author:
REM     Vitaliy Mogilevskiy (vit100gain@earthlink.net)
REM 
REM Purpose:
REM     <SQLDIR_TXT>
REM	Displays count of all sessions
REM	groups by STATUS, MACHINE, MODULE / ACTION
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     s_user_ses_cnt.sql
REM 
REM Example:
REM     s_user_ses_cnt.sql
REM
REM
REM History:
REM     11-26-2001      VMOGILEV        Created
REM
REM

ttitle off
btitle off
clear col
clear breaks
break on report
compute sum of sess_cnt on report

col username format a10
col machine format a23
col action format a35 trunc

select count(*) sess_cnt
, status
, machine
, username
, module||' '||action action
from v$session 
group by status
,        machine
,        username
,        module||' '||action
/

