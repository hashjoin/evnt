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
REM     cldevnt.sql
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
REM     Displays closed EVENTS
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     cldevnt.sql
REM
REM Example:
REM     cldevnt.sql
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

col et_id format 99999 heading "Trig Id"
col target  format a14 heading "Target"
col ep_Desc format a25 trunc heading "Event Desc"
col cleared_by format a15 trunc heading "Cleared By"
col et_trigger_time heading "Triggered Time"
col et_status format a20 heading "Event"
col et_prev_et_id format 99999 heading "PTrig ID"
col et_orig_et_id format 99999 heading "OTrig ID"
col et_clr_et_id format 99999 heading "CTrig ID"

SELECT /*+ ORDERED */
   et_attribute1||':'||et_attribute2 target
,  et_trigger_time
,  et_status        
,  ep_desc
,  et.modified_by cleared_by
,  et_id
,  et_orig_et_id    
,  et_clr_et_id    
,  et_prev_et_id    
,  et_phase_status phase
,  et_mail_status  mail
FROM event_triggers et
,    event_parameters ep
,    event_assigments ea
WHERE et.et_phase_status='C'
AND   et.ea_id = ea.ea_id
AND   ea.ep_id = ep.ep_id
ORDER BY et_trigger_time
/

prompt Getting Event OUTPUT ( $SYS_TOP/sql/outevnt.sql )

@$SYS_TOP/sql/outevnt.sql
   
