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
REM     actcoll.sql
REM
REM <SQLDIR_GRP>COLL_MAINT</SQLDIR_GRP>
REM
REM Author:
REM     Vitaliy Mogilevskiy
REM     VMOGILEV
REM     (www.dbatoolz.com)
REM
REM Purpose:
REM     <SQLDIR_TXT>
REM     Displays control panel for COLLECTION Assignments
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     actcoll.sql
REM
REM Example:
REM     actcoll.sql
REM
REM
REM History:
REM     09-16-2002      VMOGILEV        Created
REM
REM

set pages 66
set lines 132

alter session set nls_date_format='MON-DD HH24:MI';

col der_stat	format a4 trunc heading "Stat"
col ca_id	format 999 heading "ID"
col target	format a14 trunc heading "Target"
col cp_code	format a25 trunc heading "Coll Code"
col stat	format a2  heading "ST"
col typ		format a3  heading "RTYP"
col int		format 999 heading "RINT"
col sch_t	format a12 heading "Scheduled"
col str_t	format a12 heading "Started"
col fin_t	format a12 heading "Finished"
col rt_sec	format 9999 heading "Sec"


SELECT
  DECODE(SIGN(DECODE(ca_phase_code,'T',0,'R',0,TRUNC(((SYSDATE-ca_start_time)/(1/24))*60))),
     1,'DOWN',DECODE(ca_phase_code,
                  'P','PEND',
                  'T','TERM',				  
                  'R','RUN',
                  'E','ERR',
                      'OK')) der_stat
,  ca_id
,  h_name||':'||s_name target
,  cp_code
,  ca_phase_code stat
,  ca_restart_type typ
,  ca_restart_interval int 
,  ca_start_time sch_t
,  ca_started_time str_t
,  ca_finished_time fin_t
,  ca_last_runtime_sec rt_sec
FROM coll_assigments ca
,    sids s
,    hosts h
,    coll_parameters cp
WHERE ca.s_id = s.s_id	  
AND   s.h_id = h.h_id
AND   ca.cp_id = cp.cp_id
ORDER BY target, cp_code
/

