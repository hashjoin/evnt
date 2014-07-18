/*

You can create dynamic sql to refresh all grants from 
repository:

select '@cr8musra.sql '||sc_username||' '||sc_password||' <apps_password> '||sc_tns_alias
from sid_credentials
where lower(sc_username)='mon';

*/

spool cr8_monusr_apps.log
set echo on
connect apps/&&3@&&4
set echo off
GRANT SELECT ON fnd_logins                     TO &&1 ;
GRANT SELECT ON fnd_user                       TO &&1 ;
GRANT SELECT ON fnd_concurrent_requests        TO &&1 ;
GRANT SELECT ON fnd_concurrent_programs_tl     TO &&1 ;
GRANT SELECT ON fnd_concurrent_programs        TO &&1 ;
GRANT SELECT ON fnd_concurrent_requests        TO &&1 ;
GRANT SELECT ON fnd_concurrent_worker_requests TO &&1 ;
GRANT SELECT ON fnd_concurrent_processes       TO &&1 ;

set echo on
connect &&1/&&2@&&4
set echo off
CREATE SYNONYM fnd_logins                     FOR apps.fnd_logins                    ;
CREATE SYNONYM fnd_user                       FOR apps.fnd_user                      ;
CREATE SYNONYM fnd_concurrent_requests        FOR apps.fnd_concurrent_requests       ;
CREATE SYNONYM fnd_concurrent_programs_tl     FOR apps.fnd_concurrent_programs_tl    ;
CREATE SYNONYM fnd_concurrent_programs        FOR apps.fnd_concurrent_programs       ;
CREATE SYNONYM fnd_concurrent_worker_requests FOR apps.fnd_concurrent_worker_requests;
CREATE SYNONYM fnd_concurrent_processes       FOR apps.fnd_concurrent_processes      ;
show user
spool off

undefine 1
undefine 2
undefine 3
undefine 4

