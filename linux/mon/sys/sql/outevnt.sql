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
REM     outevnt.sql
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
REM     Displays EVENT output and trigger ATTRIBUTES
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     outevnt.sql
REM
REM Example:
REM     outevnt.sql
REM
REM
REM History:
REM     09-16-2002      VMOGILEV        Created
REM
REM


prompt 
prompt Details:
prompt 

set verify off
set feed off
set pages 0
set lines 132
set trims on

clear col
col s_order noprint
col trig_id noprint
col line_id noprint


select s_order, trig_id, line_id, OUTPUT_LINE 
from event_trig_outdet_all_v
where TRIG_ID = &trigger_id
/

