REM
REM DBAToolZ NOTE:
REM	This script was obtained from DBAToolZ.com
REM	It's configured to work with SQL Directory (SQLDIR).
REM	SQLDIR is a utility that allows easy organization and
REM	execution of SQL*Plus scripts using user-friendly menu.
REM	Visit DBAToolZ.com for more details and free SQL scripts.
REM
REM
REM     Copyright (c) 1998 DBAToolZ.com All rights reserved.
REM 
REM File:
REM 	x_dir.sql
REM
REM <SQLDIR_GRP>DBATOOLZ</SQLDIR_GRP>
REM 
REM Author:
REM 	Vitaliy Mogilevskiy (www.dbatoolz.com)
REM 
REM Purpose:
REM	<SQLDIR_TXT>
REM	SQLDIR menu driver.  Do not modify this script!
REM	</SQLDIR_TXT>
REM
REM Usage:
REM	x_dir.sql
REM 
REM Example:
REM	x_dir.sql
REM
REM
REM History:
REM	08-01-1998	VMOGILEV	Created
REM
REM

-- to avoid ORA-2085
alter session set global_names=false;

@u_prompt.sql
@x_banner.sql

-- Display the menu
-- ****************
-- clear screen
btitle off
ttitle off
clear breaks
clear col
set lines 132
set pages 100
set head on
set feedback off
set echo off
col grp_id         format 99  heading "ID"
col group_name     format a45 heading "Group Name"
col num_of_scripts format 999 heading "Cnt"


SELECT DECODE(map.grp_id,-1,0,map.grp_id) grp_id
,      RPAD(NVL(grp.grp_desc,grp.grp_name)||' ',45,'.') group_name
,      count(*) num_of_scripts
FROM   sqldir_groups grp
,      sqldir_mapping map
WHERE  map.grp_id = grp.grp_id
GROUP BY
       map.grp_id
,      NVL(grp.grp_desc,grp.grp_name);

-- Take user choice and build where_clause parameter
-- ************************************************

accept group_no char prompt "Enter Group Id or to search Enter [s SEARCH_STRING] : "


-- Display user picked group of scripts
-- ************************************

clear screen
clear breaks
clear col
set pages 9999
set lines 132
set verify off
set feedback off
set wrap on
col script_id    format 999  heading "Id"
col script_name  format a35  heading "Script Name"
col script_desc  format a80  heading "Script Description"
col dummy        noprint new_value m_dummy

break on dummy skip page
ttitle  -
         "************** " m_dummy " **************" -

SELECT map.script_id
,      scr.script_name
,      scr.script_desc
,      DECODE(SUBSTR('&&group_no',1,1),'s','Search results',NVL(grp.grp_desc,grp.grp_name)) dummy
FROM   sqldir_groups grp
,      sqldir_scripts scr
,      sqldir_mapping map
WHERE  map.grp_id = DECODE(SUBSTR('&&group_no',1,1),'s','-1','&&group_no')
AND    ( 
         DECODE(SUBSTR('&&group_no',1,1),'s',UPPER(scr.script_desc),'x') LIKE DECODE(SUBSTR('&&group_no',1,1),'s','%'||SUBSTR(UPPER('&&group_no'),3)||'%','x')
         OR
         DECODE(SUBSTR('&&group_no',1,1),'s',UPPER(scr.script_name),'x') LIKE DECODE(SUBSTR('&&group_no',1,1),'s','%'||SUBSTR(UPPER('&&group_no'),3)||'%','x')
       )
AND    map.script_id = scr.script_id
AND    map.grp_id = grp.grp_id;


-- The following portion will determine if user wants to run any of the scripts
-- ****************************************************************************
set term on

accept answer prompt "Enter Script Id To Execute [Enter - Main Menu, Ctl-C - Exit]:"

clear screen
clear col
set echo off
set heading off
set pagesize 0
set linesize 110
set feedback off
-- Set Term off

col run_script new_value run noprint

-- first set "run" to x_dir.sql
-- incase it's an ENTER
SELECT 'x_dir.sql' run_script
FROM   dual;


SELECT script_name run_script
FROM   sqldir_scripts
WHERE  script_id = TO_NUMBER('&answer');


clear screen

SELECT 'You are running script: &&run '
FROM   dual;

set term on
set feedback on
set head on
set pages 100
set verify on
ttitle off
clear col

@&&run

undefine run


