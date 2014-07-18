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
REM <SQLDIR_GRP>GLOB_MAINT</SQLDIR_GRP>
REM
REM Author:
REM     Vitaliy Mogilevskiy
REM     VMOGILEV
REM     (www.dbatoolz.com)
REM
REM Purpose:
REM     <SQLDIR_TXT>
REM     Creates new administrator database account, grants
REM     necessary privileges to run web-based applications
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
REM     02-21-2003      VMOGILEV        removed creation of priv synonyms
REM					since we switched to pub syn model
REM
REM

prompt 1=admin
prompt 2=SYSTEM's password
prompt default password=&&1

connect system/&2
CREATE USER &&1 identified by &&1
DEFAULT TABLESPACE tools
TEMPORARY TABLESPACE temp;
GRANT CONNECT TO &&1;

GRANT webproc_role TO &&1;

undefine 1
undefine 2
exit


