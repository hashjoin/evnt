set scan off

CREATE OR REPLACE PACKAGE glob_web_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : glob_web_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : glob_web_pkgs.sql
-- DATE CREATED  : 08/02/2002
-- APPLICATION   : GLOBAL WEB FORMS
-- VERSION       : 1.2.13
-- DESCRIPTION   : Various HTML Forms (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 08/02/02  vmogilev    created
--
-- 10/22/02  vmogilev    page_lists - added acknowlegement flag
--
-- 10/24/02  vmogilev    page_lists - added ADMIN BACKUPS
--
-- 10/31/02  vmogilev    all - changed font attributes to ccs
--
-- 11/22/02  vmogilev    trace_on - created
--                       trace_off - created
--                           REQUIRED GRANT to the owner of this package:
--                              GRANT ALTER SESSION TO <owner_of_glob_web_pkg>;
--
-- 02/07/03  vmogilev    (1.2.4)
--                       highlight - made calls to escape special chars
--                          like HTML start tag REPLACE(string,'<','&lt')
--
-- 02/18/03  vmogilev    (1.2.5)
--                       parse_binds - created
--                       prompt_bind - created
--                       exec_sql - added support for bind variables
--
-- 02/19/03  vmogilev    (1.2.6)
--                       trim_all - moved here from standalone function
--                          created on 9/24/2002
--                       ALL - no longer use escape_special instead
--                          utilized htf.escape_sc
--                       prompt_bind - added parameter name/list support
--                       rpt - created
--
-- 02/20/03  vmogilev    (1.2.7)
--                       exec_sql - added paginate functionality
--                       rpt - added p_r_type param
--
-- 02/21/03  vmogilev    (1.2.8)
--                       exec_sql - changed paginate to use bind vars
--                          for START/END row positions to avoid
--                          unnecessary parsing
--                          added p_heading
--                       (1.2.9)
--                       prompt_bind - parse LOV cursor locally instead
--                          of using owa_util.bind_variables
--                       (1.2.10)
--                       exec_sql - due to security concerns no longer
--                          except arbitrary SQL statements. Only except
--                          reports.r_id or dbms_sql.parse(ed) CURSOR ID
--                          added p_rep_what/p_rep_with to handle
--                          STRING REPLACEMENTS in SQL query which will
--                          allow for DB_LINKS/SNAPSHOOT(s) select(s)
--                       rpt - nolonger pass reports.r_sql to exec_sql
--
-- 03/07/03  vmogilev    (1.2.11)
--                       rpt - added description to reports table
--                          added reports group header
--                          excluded X type (internal) reports
--                          added db_link parser/table
--                       (1.2.12)
--                       exec_sql - p_report is now report code not id
--                          this allows for recursive calls to rep proc
--
-- 03/11/03  vmogilev    (1.2.13)
--                       rpt - made inteligent to figure out which page
--                          header to call based on report type
-- ---------------------------------------------------------------------

TYPE char_array IS TABLE OF VARCHAR2(255) INDEX BY BINARY_INTEGER;
empty_array char_array;

PROCEDURE trace_on;
PROCEDURE trace_off;

PROCEDURE rpt(
   p_r_code IN VARCHAR2 DEFAULT NULL
,  p_r_type IN VARCHAR2 DEFAULT NULL
,  p_db_link IN VARCHAR2 DEFAULT NULL);

PROCEDURE exec_sql(
   p_report      IN VARCHAR2   DEFAULT NULL
,  p_cursor      IN INTEGER    DEFAULT NULL
,  p_bind_names  IN char_array DEFAULT empty_array
,  p_bind_values IN char_array DEFAULT empty_array
,  p_pag         IN VARCHAR2   DEFAULT NULL
,  p_pag_str     IN NUMBER     DEFAULT 1
,  p_pag_int     IN NUMBER     DEFAULT 19
,  p_heading     IN VARCHAR2   DEFAULT 'Query Results'
,  p_rep_what    IN VARCHAR2   DEFAULT NULL
,  p_rep_with    IN VARCHAR2   DEFAULT NULL);

PROCEDURE page_lists(
   p_pl_id             IN VARCHAR2 DEFAULT NULL
,  p_pld_id            IN VARCHAR2 DEFAULT NULL
,  p_ae_id             IN VARCHAR2 DEFAULT NULL
,  p_a_id              IN VARCHAR2 DEFAULT NULL
,  p_a_name            IN VARCHAR2 DEFAULT NULL
,  p_a_desc            IN VARCHAR2 DEFAULT NULL
,  p_ae_email          IN VARCHAR2 DEFAULT NULL
,  p_ae_desc           IN VARCHAR2 DEFAULT NULL
,  p_ae_append_logfile IN VARCHAR2 DEFAULT NULL
,  p_date_modified     IN VARCHAR2 DEFAULT NULL
,  p_modified_by       IN VARCHAR2 DEFAULT NULL
,  p_pl_code           IN VARCHAR2 DEFAULT NULL
,  p_pl_desc           IN VARCHAR2 DEFAULT NULL
,  p_pl_ack_required   IN VARCHAR2 DEFAULT NULL
-- ADMIN BACKUPS
,  p_ab_id             IN VARCHAR2 DEFAULT NULL
,  p_pa_id             IN VARCHAR2 DEFAULT NULL
,  p_ba_id             IN VARCHAR2 DEFAULT NULL
,  p_bae_id            IN VARCHAR2 DEFAULT NULL
,  p_operation         IN VARCHAR2 DEFAULT NULL);

PROCEDURE blackouts(
   p_eb_id          IN VARCHAR2 DEFAULT NULL
,  p_date_created   IN VARCHAR2 DEFAULT NULL
,  p_date_modified  IN VARCHAR2 DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_eb_code        IN VARCHAR2 DEFAULT NULL
,  p_eb_type        IN VARCHAR2 DEFAULT NULL
,  p_eb_type_id     IN VARCHAR2 DEFAULT NULL
--
-- START LOCAL
,  p_loc_sd         IN VARCHAR2 DEFAULT NULL
,  p_loc_ed         IN VARCHAR2 DEFAULT NULL
,  p_loc_shh        IN VARCHAR2 DEFAULT NULL
,  p_loc_ehh        IN VARCHAR2 DEFAULT NULL
,  p_loc_smi        IN VARCHAR2 DEFAULT NULL
,  p_loc_emi        IN VARCHAR2 DEFAULT NULL
-- END LOCAL
--
,  p_eb_start_date  IN VARCHAR2 DEFAULT NULL
,  p_eb_end_date    IN VARCHAR2 DEFAULT NULL
,  p_eb_week_day    IN VARCHAR2 DEFAULT NULL
,  p_eb_active_flag IN VARCHAR2 DEFAULT NULL
,  p_eb_desc        IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT NULL);
END glob_web_pkg;
/

show errors
