-- $header install.sql v1.7 2013-Oct-21 VMOGILEVSKIY 

spool install_create_evnt.log

prompt 1 = management server repository
prompt 2 = default tablespace for evnt schema

WHENEVER SQLERROR EXIT FAILURE

CREATE USER evnt IDENTIFIED BY evnt
DEFAULT TABLESPACE &&2
TEMPORARY TABLESPACE TEMP;

GRANT CONNECT, RESOURCE TO evnt;
REVOKE UNLIMITED TABLESPACE FROM evnt;
ALTER USER evnt QUOTA UNLIMITED ON &&2;
GRANT ALTER SESSION TO evnt;
GRANT CREATE DATABASE LINK TO evnt;
GRANT CREATE TABLE TO evnt;
GRANT CREATE PUBLIC SYNONYM TO evnt;
grant execute on DBMS_LOCK to evnt;
grant create view to evnt;
grant CREATE SYNONYM to evnt;
spool off

connect evnt/evnt@&&1
prompt ... intalling repository objects
@./port/cdsddl.sql

spool install_code.log
prompt ... installing EVNT_UTIL_PKG_OUT table
@./port/custom_tabs.sql
prompt ... installing CREATE_DB_LINK
@./port/create_db_link_proc.sql
prompt ... installing DELETE_COMMIT
@./port/delete_commit_proc.sql
prompt ... installing EVENT_ASSIGMENTS_V
@./port/event_assigments_v.sql
prompt ... installing SID_CREDENTIALS_BIU
@./port/sid_credentials_bi_trig.sql
prompt ... installing REPORT_SHR_PRMS_BI
@./port/report_shr_prms_bi_trig.sql

prompt ... installing GLOB UTIL PKG
@./port/glob_util_pkgs.sql
@./port/glob_util_pkgb.sql

prompt ... installing COLL UTIL PKG
@./port/coll_util_pkgs.sql
@./port/coll_util_pkgb.sql 

prompt ... installing EVNT UTIL PKG
@./port/evnt_util_pkgs.sql
@./port/evnt_util_pkgb.sql 

prompt ... installing GLOB API PKG
@./port/glob_api_pkgs.sql
@./port/glob_api_pkgb.sql

prompt ... installing EVNT API PKG
@./port/evnt_api_pkgs.sql
@./port/evnt_api_pkgb.sql

prompt ... installing WEB UTIL TABS
@./port/web_seed.sql

prompt ... installing WEB STD PKG
@./port/web_std_pkgs.sql
@./port/web_std_pkgb.sql

prompt ... installing WEB NAV PKG
@./port/web_nav_pkgs.sql
@./port/web_nav_pkgb.sql

prompt ... installing GLOB WEB PKG
@./port/glob_web_pkgs.sql
@./port/glob_web_pkgb.sql

prompt ... installing EVNT WEB PKG
@./port/evnt_web_pkgs.sql
@./port/evnt_web_pkgb.sql

prompt ... installing COLL WEB PKG
@./port/coll_web_pkgs.sql
@./port/coll_web_pkgb.sql

declare
   l_job binary_integer;
begin
   begin
      select job
      into l_job
      from user_jobs
      where what like 'evnt_util_pkg.purge_obsolete%';
   exception
      when no_data_found then
         dbms_job.submit(l_job,'evnt_util_pkg.purge_obsolete;',sysdate,'sysdate+(12/24)');
   end;
end;
/

commit;


spool off
