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
REM     pndevnt.sql
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
REM     Displays history of EVENTS per TARGET
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     pndevnt.sql
REM
REM Example:
REM     pndevnt.sql
REM
REM
REM History:
REM     09-16-2002      VMOGILEV        Created
REM
REM

set lines 132
set pages 100
set trims on
set feed on

alter session set nls_date_format='MON-DD HH24:MI:SS';

col et_id format 999999999 heading "Trig Id"
col target  format a14 heading "Target"
col ep_Desc format a25 trunc heading "Event Desc"
col et_trigger_time heading "Triggered Time"
col et_status format a30 heading "Event"
col et_prev_et_id format 999999999 heading "PTrig ID"
col et_orig_et_id format 999999999 heading "OTrig ID"
col et_prev_status format a20 heading "PEvent"

SELECT /*+ ORDERED */
   et_attribute1||':'||et_attribute2 target
,  et_trigger_time
,  DECODE(et_status,'CLEARED',et_prev_status||' - CLEARED',et_status) et_status
--,  ep_desc
,  et_id
,  et_orig_et_id    
,  et_prev_et_id    
,  et_prev_status   
,  et_phase_status phase
,  et_mail_status  mail
FROM event_triggers et
,    event_parameters ep
,    event_assigments ea
WHERE et.ea_id = ea.ea_id
AND   ea.ep_id = ep.ep_id
AND   TRUNC(et.et_trigger_time) >= TRUNC(SYSDATE-&days_back)
AND   et_attribute1 = '&host'
ORDER BY et.et_trigger_time
/

prompt Getting Event OUTPUT ( $SYS_TOP/sql/outevnt.sql )
--@$SYS_TOP/sql/outevnt.sql
  

