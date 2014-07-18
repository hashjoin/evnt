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
REM 	u_prompt.sql
REM
REM <SQLDIR_GRP>UTIL</SQLDIR_GRP>
REM 
REM Author:
REM 	Vitaliy Mogilevskiy 
REM	VMOGILEV
REM	(www.dbatoolz.com)
REM 
REM Purpose:
REM	<SQLDIR_TXT>
REM	Chages SQL Prompt to "USER@INSTANCE_NAME:HOST_NAME> "
REM	</SQLDIR_TXT>
REM	
REM Usage:
REM	u_prompt.sql
REM 
REM Example:
REM	u_prompt.sql
REM
REM
REM History:
REM	08-01-1998	VMOGILEV	Created
REM
REM

set echo off
set termout off
column new_prompt new_value prmpt

-- First dump "USER> " to new_prompt
-- in case V$INSTANCE is not available
select
   USER||'> ' new_prompt
from dual;


-- now try to set new_prompt
-- to the "right" format
select
   user||'@'||INSTANCE_NAME||':'||HOST_NAME||'> ' new_prompt
from v$instance;
      
--set scan off

set sqlprompt "&&prmpt"

undef prmpt

set termout on
set time on


