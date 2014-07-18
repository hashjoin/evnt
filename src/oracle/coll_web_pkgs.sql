set scan off

CREATE OR REPLACE PACKAGE coll_web_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : coll_web_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : coll_web_pkgs.sql
-- DATE CREATED  : 08/02/2002
-- APPLICATION   : COLLECTIONS
-- VERSION       : 3.5.11
-- DESCRIPTION   : Various Forms (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 08/02/02  vmogilev    created
--
-- 10/31/02  vmogilev    all - changed font attributes to ccs
--
-- 01/28/03  vmogilev    (3.5.2)
--                       history - made compatible with 1.8.1
--                       ca_form - made html link to history
--                       cp_form - created
--
-- 02/03/03  vmogilev    (3.5.3)
--                       ca_form - added event assignment details
--
-- 02/06/03  vmogilev    (3.5.4)
--                       trend_analyzer - created
--
-- 02/07/03  vmogilev    (3.5.5)
--                       trend_analyzer - added the following
--                          o p_year stepping
--                          o year PIVOT query
--
-- 02/21/03  vmogilev    (3.5.6)
--                       trend_analyzer - call to glob_web_pkg.exec_sql
--                          now requires parsed cursor
--                       show_snap - changed to use pre-build report
--                          from REPORTS table instead of building
--                          SQL query dynamically for each snapshot
--                          to close security gap where any sql could
--                          be ran through it
--                       history - changed html link to show_snap to
--                          pass csh_id instead of snapshot table
--                          for the same security reason
--
-- 02/26/03  vmogilev    (3.5.7)
--                       show_snap - removed COLL_TAB_PREF from
--                          sn_name_cur to avoid passing complete table
--                          name to exec_sql for security reasons
--
-- 03/07/03  vmogilev    (3.5.8)
--                       show_snap - removed cursor to get rep id
--                          since exec_sql now excepts r_code
--
-- 03/25/03  vmogilev    (3.5.9)
--                       trend_analyzer - call glob_web_pkg.exec_sql
--                          only when snapshots found
--                       cp_form - fixed some HTML bugs
-- 05/05/03  vmogilev    (3.5.10)
--                       history - added paginate
--
-- 05/12/03  vmogilev    (3.5.11)
--                       history - NEXT/CURR/PREV paginate controls
-- ---------------------------------------------------------------------
PROCEDURE trend_analyzer(
   p_event      IN VARCHAR2 DEFAULT NULL
,  p_year       IN VARCHAR2 DEFAULT NULL
,  p_date       IN VARCHAR2 DEFAULT NULL
,  p_operation  IN VARCHAR2 DEFAULT NULL);
PROCEDURE cp_form(
   p_cp_id               IN VARCHAR2 DEFAULT NULL
,  p_c_id                IN VARCHAR2 DEFAULT NULL
,  p_date_created        IN VARCHAR2 DEFAULT NULL
,  p_date_modified       IN VARCHAR2 DEFAULT NULL
,  p_modified_by         IN VARCHAR2 DEFAULT NULL
,  p_created_by          IN VARCHAR2 DEFAULT NULL
,  p_cp_code             IN VARCHAR2 DEFAULT NULL
,  p_cp_pull_sql         IN VARCHAR2 DEFAULT NULL
,  p_cp_purge_flag       IN VARCHAR2 DEFAULT NULL
,  p_cp_archive_flag     IN VARCHAR2 DEFAULT NULL
,  p_cp_pull_ts_name     IN VARCHAR2 DEFAULT NULL
,  p_cp_purge_proc_name  IN VARCHAR2 DEFAULT NULL
,  p_cp_desc             IN VARCHAR2 DEFAULT NULL
,  p_operation           IN VARCHAR2 DEFAULT NULL);

PROCEDURE history(
   p_cp_id      IN VARCHAR2 DEFAULT NULL
,  p_c_id       IN VARCHAR2 DEFAULT NULL
,  p_s_id       IN VARCHAR2 DEFAULT NULL
,  p_ca_id      IN VARCHAR2 DEFAULT NULL
,  p_csh_status IN VARCHAR2 DEFAULT NULL
,  p_operation  IN VARCHAR2 DEFAULT NULL
,  p_pag_str    IN NUMBER   DEFAULT 1
,  p_pag_int    IN NUMBER   DEFAULT 19);

PROCEDURE ca_form(
   p_ca_id     IN VARCHAR2 DEFAULT NULL
,  p_operation IN VARCHAR2 DEFAULT NULL);

PROCEDURE show_snap(
   p_csh_id IN NUMBER);
END coll_web_pkg;
/
show error
