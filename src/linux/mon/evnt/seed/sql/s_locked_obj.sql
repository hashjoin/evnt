-- $header s_locked_obj.sql v1.5 2014-MAR-13 VMOGILEVSKIY 
--   2013-Nov-19	v1.2	VMOGILEVSKIY	Added CLIENT_INFO
--   2013-Nov-22	v1.3	VMOGILEVSKIY	Switched to separate batch_id for LOCKS and SESS (see mon_refresh_proc)
--   2013-Dec-19	v1.4	VMOGILEVSKIY	Switched to secs on ctime (used to to ctime/60)
--   2014-Mar-13	v1.5	VMOGILEVSKIY	Switched to CLIENT_IDENTIFIER

/*
called by drilllock.sh

$EVNT_TOP/seed/sql/s_locked_obj.sql :l_lock_batch_id :l_sess_batch_id

*/

ttitle off
clear col
set verify off
set serveroutput on size 1000000   
set echo off
set lines 132
set trims on


set feed on
set term on

prompt blocked objects from GV$LOCK and SYS.OBJ$
set lines 132
col BLOCKED_OBJ format a35 trunc

select /*+ ORDERED */
    l.inst_id
,   l.sid
,   l.lmode
,   TRUNC(l.ctime) secs_blocked
,   u.name||'.'||o.NAME blocked_obj
from (select *
      from gv_lock_mon
      where type='TM'
        and block!=0) l
,     sys.obj$ o
,     sys.user$ u
where o.obj# = l.ID1
and   o.OWNER# = u.user#
and   l.ctime > 10
and   l.sid >= 1
and   l.batch_id = &&1;


prompt blocked sessions from GV$LOCK

select /*+ ORDERED */
   blocker.inst_id
,  blocker.sid blocker_sid
,  blocked.inst_id
,  blocked.sid blocked_sid
,  TRUNC(blocked.ctime) secs_blocked
,  blocked.request
from (select *
      from gv_lock_mon
      where block != 0
      and type = 'TX'
      and batch_id = &&1) blocker
,    gv_lock_mon        blocked
where blocked.type='TX' 
and blocked.block = 0
and blocked.id1 = blocker.id1
and blocked.batch_id = blocker.batch_id;

prompt blocked session details from GV$SESSION and GV$SQLTEXT

clear col
clear breaks
set lines 80
set trims on
set pages 9000
col sql_text format a70 word_wrapped
col inst_id format a10 noprint new_value n_inst_id
col sid format a10 noprint new_value n_sid
col serial format a10 noprint new_value n_serial
col username format a20 noprint new_value n_username
col machine format a20 noprint new_value n_machine
col osuser format a20 noprint new_value n_osuser
col process format a20 noprint new_value n_process
col action format a45 noprint new_value n_action
col SQL_ID format a13 noprint new_value n_SQL_ID
col PREV_SQL_ID format a13 noprint new_value n_PREV_SQL_ID
col display_sql_id format a13 noprint new_value n_display_sql_id
col CLIENT_IDENTIFIER format a64 noprint new_value n_CLIENT_IDENTIFIER


break on sid on serial on username on process on machine on action skip page

ttitle -
       "Instance........ : "  n_inst_id -
      skip 1 -
       "Sid ............ : "  n_sid -
      skip 1 -
       "Serial ......... : "  n_serial -
      skip 1 -
       "Username ....... : "  n_username -
      skip 1 -
       "SQL Id ......... : "  n_SQL_ID -
      skip 1 -
       "Prev SQL Id .... : "  n_PREV_SQL_ID -
      skip 1 -
       "Displayed SQL Id : "  n_display_sql_id -
      skip 1 -
       "Client Id ...... : "  n_CLIENT_IDENTIFIER -
      skip 1 -
       "Machine ........ : "  n_machine -
      skip 1 -
       "OSuser ......... : "  n_osuser -
      skip 1 -
       "Process ........ : "  n_process -
      skip 1 -
       "Action ......... : "  n_action -

select /*+ ORDERED */
   ses.inst_id,sid,serial# serial,username,machine,osuser,process,module||' '||action action,sql_text,
   nvl(ses.SQL_ID,'null') SQL_ID,
   nvl(ses.PREV_SQL_ID,'null') PREV_SQL_ID,
   nvl(txt.SQL_ID,'null') display_sql_id,
   nvl(ses.CLIENT_IDENTIFIER,'null') CLIENT_IDENTIFIER
--from gv$session ses, gv$sqltext txt
from gv_session ses, gv$sqltext_with_newlines txt
where txt.address(+) = ses.sql_address_mon
and   txt.hash_value(+) = ses.sql_hash_value_mon
and   txt.inst_id(+) = ses.inst_id
--and   txt.batch_id = ses.batch_id
and   ses.batch_id = &&2
and   (ses.inst_id,ses.sid) 
            IN (select /*+ ORDERED */
                --   blocker.inst_id
                --,  blocker.sid blocker_sid
                   blocked.inst_id
                ,  blocked.sid blocked_sid
                from (select *
                      from gv_lock_mon
                      where block != 0
                      and type = 'TX'
                      and batch_id = &&1) blocker
                ,    gv_lock_mon        blocked
                where blocked.type='TX'
                and blocked.block = 0
                and blocked.id1 = blocker.id1
		and blocked.batch_id = blocker.batch_id)
order by inst_id,sid,piece;


prompt blocker session details from GV$SESSION and GV$SQLTEXT (current or previous SQL)

select /*+ ORDERED */
   ses.inst_id,sid,serial# serial,username,machine,osuser,process,module||' '||action action,sql_text,
   nvl(ses.SQL_ID,'null') SQL_ID,
   nvl(ses.PREV_SQL_ID,'null') PREV_SQL_ID,
   nvl(txt.SQL_ID,'null') display_sql_id,
   nvl(ses.CLIENT_IDENTIFIER,'null') CLIENT_IDENTIFIER
--from gv$session ses, gv$sqltext txt
from gv_session ses, gv$sqltext_with_newlines txt
where txt.address(+) = ses.sql_address_mon
and   txt.hash_value(+) = ses.sql_hash_value_mon
and   txt.inst_id(+) = ses.inst_id
--and   txt.batch_id = ses.batch_id
and   ses.batch_id = &&2
and   (ses.inst_id,ses.sid)
            IN (select /*+ ORDERED */
                   blocker.inst_id
                ,  blocker.sid blocker_sid
                --   blocked.inst_id
                --,  blocked.sid blocked_sid
                from (select * 
                      from gv_lock_mon
                      where block != 0
                      and type = 'TX'
                      and batch_id = &&1) blocker
                ,    gv_lock_mon        blocked
                where blocked.type='TX'
                and blocked.block = 0
                and blocked.id1 = blocker.id1
                and blocked.batch_id = blocker.batch_id)
order by inst_id,sid,piece;

