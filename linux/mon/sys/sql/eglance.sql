REM
REM DBAToolZ NOTE:
REM     This script is configured to work with SQL Directory (SQLDIR).
REM     SQLDIR is a utility that allows easy organization and
REM     execution of SQL*Plus scripts using user-friendly menu.
REM     Visit DBAToolZ.com for more details and free SQL scripts.
REM
REM
REM     Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
REM
REM File:
REM     eglance.sql
REM
REM <SQLDIR_GRP>EVNT_MAINT</SQLDIR_GRP>
REM
REM Author:
REM     Vitaliy Mogilevskiy
REM     VMOGILEV
REM     (www.dbatoolz.com)
REM
REM Purpose:
REM     <SQLDIR_TXT>
REM     glance overview of running, scheduled, broken 
REM     and behind schedule EVENTS
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     eglance.sql
REM
REM Example:
REM     eglance.sql
REM
REM
REM History:
REM     06-25-2003      VMOGILEV        Created
REM
REM


set trims on

select
    decode(ea_status,
       'R','running',
       'I','inactive',
       'A','pending',
       'B','failed',
       'l','scheduled (local agent)',
       'r','scheduled (remote agent)') typ
,   count(*) cnt
from event_assigments 
group by ea_status
union all
select 
   'behind schedule' typ
,   count(*) cnt
from event_assigments
where ea_status = 'A'
and SYSDATE >= ea_start_time+2/24/60
union all
select 
   'stale [running > 15 min]' typ
,   count(*) cnt
from event_assigments
where ea_status = 'R'
and  SYSDATE - ea_started_time >= 15/24/60
/

alter session set nls_date_format='RRRR-MON-DD HH24:MI';

set lines 132
col remote format a7 heading "Remote?"
col event format a20 heading "Event"
col target format a20 heading "Target"
col stat format a25 heading "Status"
col sta_time heading "Status - Time"

select
     ea_id
,    '$'||e_code_base||'/'||e_file_name event
,    remote
,    h_name||decode(s_name,null,null,':'||s_name) target    
,    decode(ea_status,
       'R','running',
       'B','failed',
       'l','scheduled (local agent)',
       'r','scheduled (remote agent)') stat
,    decode(ea_status,
       'R',ea_started_time,
       'B',ea_finished_time,
       'l',ea_start_time,
       'r',ea_start_time) sta_time
from event_assigments_v
where ea_status IN ('R','B','l','r')
union all
select 
     ea_id
,   '$'||e_code_base||'/'||e_file_name event
,    remote
,    h_name||decode(s_name,null,null,':'||s_name) target    
,    'behind schedule' typ
,    ea_start_time sta_time
from event_assigments_v
where ea_status = 'A'
and SYSDATE >= ea_start_time+2/24/60
union all
select 
     ea_id
,    '$'||e_code_base||'/'||e_file_name event
,    remote
,    h_name||decode(s_name,null,null,':'||s_name) target    
,    'stale [running > 15 min]' typ
,    ea_start_time sta_time
from event_assigments_v
where ea_status = 'R'
and  SYSDATE - ea_started_time >= 15/24/60
order by 3,2
/

