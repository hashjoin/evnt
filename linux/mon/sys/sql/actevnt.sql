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
REM     actevnt.sql
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
REM     Displays control panel for EVENT Assignments
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     actevnt.sql
REM
REM Example:
REM     actevnt.sql
REM
REM
REM History:
REM     09-16-2002      VMOGILEV        Created
REM
REM

set pages 66
set lines 132

col der_stat	format a5  heading "STAT"
col ea_id	format 999 heading "ID"
col target	format a14 trunc heading "Target"
col pend_cnt    format 9999 heading "PND"
col old_cnt    format 9999 heading "OLD"
col clr_cnt    format 9999 heading "CLR"
col rmt		format a4 heading "Rmt"
col efil	format a20 heading "Event File"
col ep_code	format a15 trunc heading "Threshold"
col int		format 99999 heading "INT|(MIN)"
col sch_t	format a12 heading "Scheduled"
col str_t	format a12 heading "Started"
col fin_t	format a12 heading "Finished"
col rt_sec	format 9999 heading "Sec"
col pl_code	format a10 trunc heading "Page List"

SELECT /*+ ORDERED */
  DECODE(SIGN(DECODE(ea_status,'I',0,'R',0,TRUNC(((SYSDATE-ea_start_time)/(1/24))*60))),
     1,'DOWN',DECODE(ea_status,
                  'A','SCHED',
                  'I','INACT',
                  'R','RUNIN',
                  'B','BROKN',
                      'OK')) der_stat
, ea.ea_id
--, ea.e_id
--, ea.ep_id
, h_name||DECODE(s_name,NULL,NULL,':')||s_name target
, NVL(pend.scnt,0) pend_cnt
, NVL(old.scnt,0) old_cnt
, NVL(cleared.scnt,0) clr_cnt
, ep_code
, pl_code
, ea_min_interval     int
, TO_CHAR(ea_start_time,'MON-DD HH24:MI') sch_t
--, TO_CHAR(ea_started_time,'MON-DD HH24:MI') str_t
, TO_CHAR(ea_finished_time,'MON-DD HH24:MI') fin_t
, ea_last_runtime_sec rt_sec
--, ea.h_id
--, ea.s_id
--, ea.sc_id
--, ea.pl_id
--, ea_status
, remote              rmt
--, e_code_base||'/'||
--     e_file_name      efil
--, ea_status           stat
--, ep_desc
FROM event_assigments_v ea
,    event_parameters ep
,    page_lists pl
,    (SELECT ea_id, count(*) scnt
      FROM   event_triggers
      WHERE  et_phase_status = 'P'
      AND    et_status != 'CLEARED'
      GROUP BY ea_id) pend
,    (SELECT ea_id, count(*) scnt
      FROM   event_triggers
      WHERE  et_phase_status = 'O'
      AND    et_status != 'CLEARED'
      GROUP BY ea_id) old
,    (SELECT ea_id, count(*) scnt
      FROM   event_triggers
      WHERE  et_phase_status = 'C'
      AND    et_status != 'CLEARED'
      GROUP BY ea_id) cleared
WHERE  ea.ep_id = ep.ep_id
AND    ea.pl_id = pl.pl_id
AND    ea.ea_id = pend.ea_id(+)
AND    ea.ea_id = old.ea_id(+)
AND    ea.ea_id = cleared.ea_id(+)
ORDER BY target,ep_code;

