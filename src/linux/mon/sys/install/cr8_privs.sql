spool cr8_privs.log

set scan on

prompt 1 = repository tns alias
prompt 2 = evnt user password
prompt 3 = default tablespace

CREATE USER bgproc identified by justagate
DEFAULT TABLESPACE &3
TEMPORARY TABLESPACE temp;
GRANT CONNECT TO bgproc;
GRANT CREATE SYNONYM to bgproc;

CREATE USER webproc identified by welcome
DEFAULT TABLESPACE &3
TEMPORARY TABLESPACE temp;
GRANT CONNECT TO webproc;


-- bgpurge is the loopback account
-- used for DB_LINK back to monitoring
-- system for EVENT PURGE COLLECTIONS
--
CREATE USER bgpurge identified by justagate
DEFAULT TABLESPACE &3
TEMPORARY TABLESPACE temp;
GRANT CONNECT TO bgpurge;
GRANT CREATE VIEW TO bgpurge;
GRANT CREATE SYNONYM to bgpurge;

CREATE ROLE bgproc_role;
CREATE ROLE webproc_role;

GRANT bgproc_role TO bgproc;
GRANT webproc_role TO webproc;

connect evnt/&&2@&&1

GRANT SELECT ON glob_pend_assignments TO bgproc_role;
GRANT SELECT ON evnt_util_pkg_out TO bgproc_role;
GRANT SELECT ON event_parameters TO bgproc_role;
GRANT SELECT ON event_trigger_output TO bgproc_role;

-- these have to be direct SELECT privs
-- to allow for CREATE VIEW to work
-- otherwise it fails with ORA-00942
--
GRANT SELECT ON event_triggers TO bgpurge;
GRANT SELECT ON event_trigger_details TO bgpurge;
GRANT SELECT ON event_trigger_output TO bgpurge;
GRANT SELECT ON event_assigments TO bgpurge;
GRANT SELECT ON events TO bgpurge;


GRANT EXECUTE ON evnt_util_pkg TO bgproc_role;
GRANT EXECUTE ON coll_util_pkg TO bgproc_role;
GRANT EXECUTE ON glob_util_pkg TO bgproc_role;

GRANT EXECUTE ON web_nav_pkg TO webproc_role;
GRANT EXECUTE ON glob_web_pkg TO webproc_role;
GRANT EXECUTE ON evnt_web_pkg TO webproc_role;
GRANT EXECUTE ON coll_web_pkg TO webproc_role;
GRANT SELECT ON event_triggers_all_v TO webproc_role;

-- for WEBPROC_ROLE users we don't create
-- private synonyms to make user addition
-- simpler instead PUBLIC synonyms are used
--
CREATE PUBLIC SYNONYM glob_web_pkg FOR evnt.glob_web_pkg;
CREATE PUBLIC SYNONYM evnt_web_pkg FOR evnt.evnt_web_pkg;
CREATE PUBLIC SYNONYM coll_web_pkg FOR evnt.coll_web_pkg;
CREATE PUBLIC SYNONYM web_nav_pkg  FOR evnt.web_nav_pkg;
CREATE PUBLIC SYNONYM event_triggers_all_v FOR evnt.event_triggers_all_v;


connect bgproc/justagate@&&1
CREATE SYNONYM evnt_util_pkg_out     FOR evnt.evnt_util_pkg_out   ;
CREATE SYNONYM glob_pend_assignments FOR evnt.glob_pend_assignments;
CREATE SYNONYM event_parameters      FOR evnt.event_parameters    ;
CREATE SYNONYM event_trigger_output  FOR evnt.event_trigger_output;
CREATE SYNONYM evnt_util_pkg         FOR evnt.evnt_util_pkg       ;
CREATE SYNONYM coll_util_pkg         FOR evnt.coll_util_pkg       ;
CREATE SYNONYM glob_util_pkg         FOR evnt.glob_util_pkg       ;


connect bgpurge/justagate@&&1
CREATE SYNONYM event_triggers        FOR evnt.event_triggers       ;
CREATE SYNONYM event_trigger_details FOR evnt.event_trigger_details;     
CREATE SYNONYM event_trigger_output  FOR evnt.event_trigger_output ;
CREATE SYNONYM event_assigments      FOR evnt.event_assigments;
CREATE SYNONYM events                FOR evnt.events;

spool off
