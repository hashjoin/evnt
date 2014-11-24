/*
EXAMPLE:
   SQLPLUS> @cr8_monusr.sql syspwd TSTDB mon tools

TO CREATE "mon" user on all registered databases
use this script to build dynamic SQL:

select '@cr8musr.sql <sys_password> '||sc_tns_alias||' mon tools'
from sid_credentials
where lower(sc_username)='mon';

*/

set scan on
set verify on
set echo off

prompt 1=sys password
prompt 2=database name
prompt 3=monitoring user
prompt 4=tools tablespace


spool cr8_monusr.&&2..log
set echo on
connect sys/&1@&2
set echo off
CREATE USER &&3 IDENTIFIED BY justagate
DEFAULT TABLESPACE &&4
TEMPORARY TABLESPACE TEMP
QUOTA 500M ON &&4;


GRANT CONNECT, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO &&3 ;

GRANT SELECT ON v_$sort_segment   TO &&3 ;
GRANT SELECT ON v_$sort_usage     TO &&3 ;
GRANT SELECT ON v_$parameter      TO &&3 ;
GRANT SELECT ON v_$instance       TO &&3 ;
GRANT SELECT ON v_$loghist        TO &&3 ;
GRANT SELECT ON v_$session        TO &&3 ;
GRANT SELECT ON v_$process        TO &&3 ;
GRANT SELECT ON v_$sqltext        TO &&3 ;
GRANT SELECT ON v_$session_wait   TO &&3 ;
GRANT SELECT ON v_$session_event  TO &&3 ;
GRANT SELECT ON v_$locked_object  TO &&3 ;
GRANT SELECT ON v_$sysstat        TO &&3 ;
GRANT SELECT ON v_$lock           TO &&3 ;
GRANT SELECT ON v_$sesstat        TO &&3 ;
GRANT SELECT ON v_$statname       TO &&3 ;
GRANT SELECT ON v_$rollname       TO &&3 ;
GRANT SELECT ON v_$rollstat       TO &&3 ;
GRANT SELECT ON v_$waitstat       TO &&3 ;
GRANT SELECT ON v_$system_event   TO &&3 ;
GRANT SELECT ON v_$transaction    TO &&3 ;
GRANT SELECT ON v_$sqlarea        TO &&3 ;


GRANT SELECT ON v_$filestat       TO &&3 ;
GRANT SELECT ON v_$datafile       TO &&3 ;
GRANT SELECT ON ts$               TO &&3 ;
GRANT SELECT ON file$             TO &&3 ;

GRANT SELECT ON dba_users      TO &&3 ;
GRANT SELECT ON dba_objects    TO &&3 ;
GRANT SELECT ON dba_segments   TO &&3 ;
GRANT SELECT ON dba_free_space TO &&3 ;
GRANT SELECT ON dba_data_files TO &&3 ;
GRANT SELECT ON dba_tables     TO &&3 ;
GRANT SELECT ON dba_indexes    TO &&3 ;
GRANT SELECT ON dba_rollback_segs  TO &&3 ;



GRANT SELECT ON sys.obj$  TO &&3 ;
GRANT SELECT ON sys.user$ TO &&3 ;

spool off

undefine 1
undefine 2
undefine 3
undefine 4
