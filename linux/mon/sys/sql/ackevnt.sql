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
REM     ackevnt.sql
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
REM     Acknowledge single or all EVENTS
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     ackevnt.sql
REM
REM Example:
REM     ackevnt.sql
REM
REM
REM History:
REM     10-25-2002      VMOGILEV        Created
REM
REM

set lines 132

col id format 9999999 heading "Id"
col target format a15 heading "Target"
col trigger_time format a20 heading "Time"
col et_status format a25 heading "Event-Status"
col phase format a8 heading "Event-Phase"

SELECT
   et_id id 
,  target
,  TO_CHAR(et_trigger_time,'MON-DD HH24:MI:SS') trigger_time
,  DECODE(et_status,'CLEARED',et_status||' '||et_prev_status,et_status) et_status
,  DECODE(phase,'P','Pending','C','Closed') phase
FROM event_triggers_all_v
WHERE et_ack_flag='Y'
AND et_ack_date IS NULL
ORDER BY target, et_trigger_time
/

set verify off

accept 1 number prompt "Enter Event ID to Acknowledge [Enter for all]: "

set serveroutput on size 100000
set feed off

VARIABLE all_trigs NUMBER;

BEGIN
   :all_trigs := &&1 ;

   --dbms_output.put_line('ALL TRIGS='||:all_trigs);

   IF :all_trigs = 0 THEN
      evnt_web_pkg.ack_all_trigs('TXT');
   ELSE
      evnt_web_pkg.ack_one_trig(&&1,'TXT');
   END IF;
END;
/

commit;

set feed on
set verify on
undefine 1



