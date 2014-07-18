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
REM 	s_db_sorts.sql
REM
REM <SQLDIR_GRP>STATS MOST USER</SQLDIR_GRP>
REM 
REM Author:
REM 	Vitaliy Mogilevskiy 
REM	VMOGILEV
REM	(vit100gain@earthlink.net)
REM 
REM Purpose:
REM	<SQLDIR_TXT>
REM	Reports ALL sorts in the database
REM	Works with 8i TEMP tablespaces
REM	</SQLDIR_TXT>
REM	
REM Usage:
REM	s_db_sorts.sql
REM 
REM Example:
REM	s_db_sorts.sql
REM
REM
REM History:
REM	08-01-1998	VMOGILEV	Created
REM
REM


prompt CURRENT ACTIVE SORTS
prompt =====================
prompt from (v$sort_segment)
prompt      (v$session)
prompt =====================

col tablespace_name format a10
col username        format a10
set lines 132
set trims on

select vsg.tablespace_name
,      du.username
,      vsg.total_extents
,      vsg.used_extents
,      vsg.extent_hits
,      vsg.max_used_blocks
,      vsg.max_sort_blocks
from   v$sort_segment   vsg
,      dba_users        du
where  vsg.current_users = du.user_id
/



prompt CURRENT SORT SEGMENTS
prompt =====================
prompt from (v$sort_segment)
prompt =====================

set pages 0
set feedback off
set verify off
col block_size noprint new_value x

select value/1024 block_size, 'Getting DB_BLOCK_SIZE ...'
from v$parameter
where name='db_block_size';


set lines 132
set feedback on
set pages 60
set trims on

SELECT tablespace_name
,      extent_size*&&x                ext_size_KB
,      total_extents*extent_size*&&x  tot_tmp_KB
,      used_extents*extent_size*&&x   used_KB
,      free_extents*extent_size*&&x   free_KB
,      max_used_size*extent_size*&&x  max_used_KB
FROM v$sort_segment;





prompt SORT usage
prompt ===================
prompt from (v$sort_usage)
prompt ===================

col sid_serial format a10 Heading "Sid,Serial"
col machine format a20 trunc
col program format a15 trunc
col kb format 9999999 heading "KB"
col tablespace format a7 trunc heading "TS name"
col extents format 99999 Heading "Ext"
col idle format a8 heading "Idle"


    SELECT s.username, s.sid||','||s.serial# sid_serial, TO_CHAR(s.logon_time,'mon-dd hh24:mi') logon_time, 
           floor(last_call_et/3600)||':'||
              floor(mod(last_call_et,3600)/60)||':'||
              mod(mod(last_call_et,3600),60) IDLE,
           s.machine, s.program,    
           s.status, u.tablespace, u.contents, u.extents, u.blocks*&&x KB
       FROM v$session s, v$sort_usage u
       WHERE s.saddr=u.session_addr;
