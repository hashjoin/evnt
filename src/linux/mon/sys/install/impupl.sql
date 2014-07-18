set echo ON

INSERT INTO reports 
SELECT 
       reports_s.NEXTVAL
,      SYSDATE
,      NULL
,      NULL
,      -1
,      r_type
,      r_code
,      r_name
,      r_desc
,      r_sql
FROM x_reports
WHERE r_code NOT IN (SELECT r_code FROM reports)
/

INSERT INTO report_shr_prms
SELECT
       report_shr_prms_s.NEXTVAL
,      SYSDATE
,      NULL
,      NULL
,      -1
,      rsp_code
,      rsp_name
,      rsp_type
,      rsp_list_sql
FROM x_report_shr_prms
WHERE rsp_code NOT IN (SELECT rsp_code FROM report_shr_prms)
/

INSERT INTO page_lists
SELECT
   page_lists_s.NEXTVAL
,  SYSDATE
,  NULL
,  NULL
,  -1
,  pl_code
,  pl_desc
,  pl_ack_required
FROM x_page_lists
WHERE pl_code NOT IN (SELECT pl_code FROM page_lists)
/


INSERT INTO admins
SELECT
   admins_s.NEXTVAL
,  SYSDATE
,  NULL
,  NULL
,  -1
,  a_name
,  a_desc
FROM x_admins
WHERE a_name NOT IN (SELECT a_name FROM admins)
/

INSERT INTO admin_emails
SELECT
   admin_emails_s.NEXTVAL
,  SYSDATE
,  NULL
,  NULL
,  -1
,  a.a_id
,  ae_email
,  ae_append_logfile
,  ae_desc
FROM x_admin_emails ae
,    admins a
WHERE ae.a_name = a.a_name
AND   (a.a_id, ae.ae_email, ae.ae_desc) NOT IN (SELECT a_id, ae_email, ae_desc FROM admin_emails)
/

INSERT INTO page_list_definitions
SELECT
   page_list_definitions_s.NEXTVAL
,  SYSDATE
,  NULL
,  NULL
,  -1
,  pl.pl_id
,  a.a_id
,  ae.ae_id
,  pld_status
FROM x_page_list_definitions pld
,    admin_emails ae
,    admins a
,    page_lists pl
WHERE pld.pl_code = pl.pl_code
AND   pld.ae_email = ae.ae_email
AND   pld.ae_desc = ae.ae_desc
AND   pld.a_name = a.a_name
AND   ae.a_id = a.a_id
AND   (pl.pl_id, a.a_id, ae.ae_id) NOT IN (SELECT pl_id, a_id, ae_id FROM page_list_definitions)
/




INSERT INTO collections
SELECT
   collections_s.NEXTVAL
,  SYSDATE
,  NULL
,  NULL
,  -1
,  c_code
,  c_desc
FROM x_collections
WHERE c_code NOT IN (SELECT c_code FROM collections)
/

INSERT INTO coll_parameters
SELECT
   coll_parameters_s.NEXTVAL
,  c.c_id
,  SYSDATE
,  NULL
,  NULL
,  -1
,  cp_code
,  cp_pull_sql
,  cp_purge_flag
,  cp_archive_flag
,  DECODE(cp_pull_ts_name,NULL,NULL,(select tablespace_name from user_tables where table_name = 'COLL_PARAMETERS')) cp_pull_ts_name
,  cp_purge_proc_name
,  cp_desc
FROM x_coll_parameters cp
,    collections c
WHERE cp.c_code = c.c_code
AND cp_code NOT IN (SELECT cp_code FROM coll_parameters)
/


INSERT INTO event_parameters
SELECT
   event_parameters_s.NEXTVAL
,  e.e_id
,  SYSDATE
,  NULL
,  NULL
,  -1
,  ep_code
,  NVL(cp_id,-1)
,  ep_hold_level
,  ep_desc
FROM x_event_parameters ep
,    coll_parameters cp
,    events e
WHERE ep.e_code = e.e_code
AND ep.cp_code = cp.cp_code(+)
AND (e.e_id, ep_code) NOT IN (SELECT e_id, ep_code FROM event_parameters)
/


INSERT INTO event_parameter_values
SELECT
   event_parameter_values_s.NEXTVAL
,  SYSDATE
,  NULL
,  NULL
,  -1
,  e.e_id
,  ep.ep_id
,  epv_name
,  epv_value
,  epv_status
FROM x_event_parameter_values epv
,    event_parameters ep
,    events e
WHERE epv.e_code = e.e_code
AND   epv.ep_code = ep.ep_code
AND   ep.e_id = e.e_id
AND   (e.e_id, ep.ep_id, epv_name) NOT IN (SELECT e_id, ep_id, epv_name FROM event_parameter_values)
/



-- post import CA creation
INSERT INTO coll_assigments(
   ca_id
,  date_created
,  date_modified
,  modified_by
,  created_by
,  cp_id
,  c_id
,  s_id
,  sc_id
,  pl_id
,  ca_phase_code
,  ca_start_time
,  ca_restart_type
,  ca_restart_interval)
SELECT coll_assigments_s.NEXTVAL
,      SYSDATE
,      NULL
,      NULL
,      '-1'
,      cp.cp_id
,      cp.c_id
,      s.s_id
,      sc.sc_id
,      pl.pl_id
,      'P'
,      SYSDATE
,      'HH'
,      24
FROM coll_parameters cp
,    sids s
,    sid_credentials sc
,    page_lists pl
WHERE cp_code = 'EPRG_MARK'
AND   s_name = UPPER('&&1')
AND   sc_username = 'bgpurge'
AND   pl_code = 'NONE'
AND   s.s_id = sc.s_id
AND   (cp.c_id, cp.cp_id, s.s_id, 'HH', 24, 'N', -1) NOT IN
         (SELECT c_id, cp_id, s_id, ca_restart_type, ca_restart_interval, ca_evnt_flag, ca_evnt_ea_id
          FROM coll_assigments)
/


INSERT INTO coll_assigments(
   ca_id
,  date_created
,  date_modified
,  modified_by
,  created_by
,  cp_id
,  c_id
,  s_id
,  sc_id
,  pl_id
,  ca_phase_code
,  ca_start_time
,  ca_restart_type
,  ca_restart_interval)
SELECT coll_assigments_s.NEXTVAL
,      SYSDATE
,      NULL
,      NULL
,      '-1'
,      cp.cp_id
,      cp.c_id
,      s.s_id
,      sc.sc_id
,      pl.pl_id
,      'P'
,      SYSDATE
,      'HH'
,      24
FROM coll_parameters cp
,    sids s
,    sid_credentials sc
,    page_lists pl
WHERE cp_code = 'EPRG_PURGE'
AND   s_name = UPPER('&&1')
AND   sc_username = 'bgpurge'
AND   pl_code = 'NONE'
AND   s.s_id = sc.s_id
AND   (cp.c_id, cp.cp_id, s.s_id, 'HH', 24, 'N', -1) NOT IN
         (SELECT c_id, cp_id, s_id, ca_restart_type, ca_restart_interval, ca_evnt_flag, ca_evnt_ea_id
          FROM coll_assigments)
/
