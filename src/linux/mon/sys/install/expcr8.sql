CREATE TABLE x_reports AS
SELECT r_type
,      r_code
,      r_name
,      r_desc
,      r_sql
FROM reports
/

CREATE TABLE x_report_shr_prms AS
SELECT rsp_code
,      rsp_name
,      rsp_type
,      rsp_list_sql
FROM report_shr_prms
/

CREATE TABLE x_page_lists AS
SELECT
   pl_code
,  pl_ack_required
,  pl_desc
FROM page_lists
WHERE pl_code IN ('DAY','24x7','EMAIL','NONE')
/

CREATE TABLE x_page_list_definitions AS
SELECT
   pl.pl_code
,  a.a_name
,  ae.ae_email
,  ae.ae_desc
,  pld_status
FROM page_list_definitions pld
,    admin_emails ae
,    admins a
,    page_lists pl
WHERE pld.pl_id = pl.pl_id
AND   pld.ae_id = ae.ae_id
AND   pld.a_id = ae.a_id
AND   ae.a_id = a.a_id
AND   a.a_name = 'NO_ONE'
AND   pl_code = 'NONE'
/

CREATE TABLE x_admins AS
SELECT
   a_name
,  a_desc
FROM admins
WHERE a_name='NO_ONE'
/

CREATE TABLE x_admin_emails AS
SELECT
   a_name
,  ae_email
,  ae_append_logfile
,  ae_desc
FROM admin_emails ae
,    admins a
WHERE ae.a_id = a.a_id
AND a_name='NO_ONE'
/

CREATE TABLE x_collections AS
SELECT
   c_code
,  c_desc
FROM collections
/

CREATE TABLE x_coll_parameters AS
SELECT
   c_code
,  cp_code
,  cp_pull_sql
,  cp_purge_flag
,  cp_archive_flag
,  cp_pull_ts_name
,  cp_purge_proc_name
,  cp_desc
FROM coll_parameters cp
,    collections c
WHERE cp.c_id = c.c_id
/

CREATE TABLE x_event_parameters AS
SELECT
   e_code
,  ep_code
,  cp_code
,  ep_hold_level
,  ep_desc
FROM event_parameters ep
,    coll_parameters cp
,    events e
WHERE ep.e_id = e.e_id
AND ep.ep_coll_cp_id = cp.cp_id(+)
/

CREATE TABLE x_event_parameter_values AS
SELECT
   e_code
,  ep_code
,  epv_name
,  epv_value
,  epv_status
FROM event_parameter_values epv
,    event_parameters ep
,    events e
WHERE epv.e_id = ep.e_id
AND   epv.ep_id = ep.ep_id
AND   ep.e_id = e.e_id
/
