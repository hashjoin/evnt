/*
EXAMPLE:

NOTE: must be run on the host due to AS SYSDBA connect clause

   HOST> sqlplus "system as sysdba" @cr8musr_9i.sql mon tools

*/

set scan on
set verify on
set echo off

prompt 1=monitoring user
prompt 2=tools tablespace


spool cr8musr_9i.log
set echo on
set echo off
CREATE USER &&1 IDENTIFIED BY justagate
DEFAULT TABLESPACE &&2
TEMPORARY TABLESPACE TEMP
QUOTA 500M ON &&2;


GRANT CONNECT, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO &&1 ;

GRANT SELECT ON v_$sort_segment   TO &&1 ;
GRANT SELECT ON v_$sort_usage     TO &&1 ;
GRANT SELECT ON v_$parameter      TO &&1 ;
GRANT SELECT ON v_$instance       TO &&1 ;
GRANT SELECT ON v_$loghist        TO &&1 ;
GRANT SELECT ON v_$session        TO &&1 ;
GRANT SELECT ON v_$process        TO &&1 ;
GRANT SELECT ON v_$sqltext        TO &&1 ;
GRANT SELECT ON v_$session_wait   TO &&1 ;
GRANT SELECT ON v_$session_event  TO &&1 ;
GRANT SELECT ON v_$locked_object  TO &&1 ;
GRANT SELECT ON v_$sysstat        TO &&1 ;
GRANT SELECT ON v_$lock           TO &&1 ;
GRANT SELECT ON v_$sesstat        TO &&1 ;
GRANT SELECT ON v_$statname       TO &&1 ;
GRANT SELECT ON v_$rollname       TO &&1 ;
GRANT SELECT ON v_$rollstat       TO &&1 ;
GRANT SELECT ON v_$waitstat       TO &&1 ;
GRANT SELECT ON v_$system_event   TO &&1 ;
GRANT SELECT ON v_$transaction    TO &&1 ;
GRANT SELECT ON v_$sqlarea        TO &&1 ;


GRANT SELECT ON v_$filestat       TO &&1 ;
GRANT SELECT ON v_$datafile       TO &&1 ;
GRANT SELECT ON ts$               TO &&1 ;
GRANT SELECT ON file$             TO &&1 ;

GRANT SELECT ON dba_users      TO &&1 ;
GRANT SELECT ON dba_objects    TO &&1 ;
GRANT SELECT ON dba_segments   TO &&1 ;
GRANT SELECT ON dba_free_space TO &&1 ;
GRANT SELECT ON dba_data_files TO &&1 ;
GRANT SELECT ON dba_tables     TO &&1 ;
GRANT SELECT ON dba_indexes    TO &&1 ;
GRANT SELECT ON dba_rollback_segs  TO &&1 ;



GRANT SELECT ON sys.obj$  TO &&1 ;
GRANT SELECT ON sys.user$ TO &&1 ;

spool off

undefine 1
undefine 2

