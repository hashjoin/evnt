set scan off

CREATE OR REPLACE PACKAGE evnt_web_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : evnt_web_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : evnt_web_pkgs.sql
-- DATE CREATED  : 07/02/2002
-- APPLICATION   : EVENTS
-- VERSION       : 3.5.46
-- DESCRIPTION   : Various Forms (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 07/02/02  vmogilev    created
--
-- 10/16/02  vmogilev    changed disp_triggers and disp_trig_grp
--                       to display and sort triggers by
--                       NVL(date_modified,et_trigger_time); before
--                       it was done by et_trigger_time
--
--                       changed disp_triggers made p_h_id optional
--                       so that it can be called from ea_form with
--                       these parameters -> P_PHASE, P_EA_ID; this
--                       allows for migration of SID to another HOST
--
--                       changed ea_form to call disp_triggers with
--                       these parameters -> P_PHASE, P_EA_ID instead of
--                       these parameters -> P_PHASE, P_EA_ID, P_H_ID
--
--                       changed ep_form to drill down to triggers by
--                       calling disp_trig_grp directly
--
--                       changed allowing disp_triggers to report by EP_ID
--
-- 10/21/02  vmogilev    ea_form - added the following tables to PURGE
--                          event_trigger_notif
--                          event_trigger_notes
--
-- 10/22/02  vmogilev    display_notif - created
--                       disp_triggers - added calls to display_notif
--                       epv_form - added EP_CODE to event desc cur
--
-- 10/24/02  vmogilev    get_trig_output - changed trig attributes
--                          from fixed comma separated to html table
--                       get_trig_diff - same change + call to
--                          get_trig_output for the high trig details
--
-- 10/25/02  vmogilev    ack_one_trig - created
--                       ack_all_trigs - created
--                       disp_triggers - added ack param + links
--
-- 10/28/02  vmogilev    disp_triggers - added link to ack_all_trigs
--                       ea_form -
--                          o PURGE-INTERNAL calls delete_commit
--                          o DELETES and PURGES require confirmation
--
-- 10/29/02  vmogilev    disp_triggers -
--                          o increased l_head_message to 256
--                            to avoid ORA-06502/ORA-06512
--                          o changed et_status display for CLEARED trs
--                          o added link to trg_notes
--                       trg_notes - created
--
-- 10/31/02  vmogilev    all - changed font attributes to ccs
--                       epv_form - disallowed DELETE or param values
--
-- 11/08/02  vmogilev    ep_form - changed layout by grouping by
--                          o CODEPASE
--                          o EVENT
--
--                       ack_all_trigs - added call to web_std_pkg.print_styles
--                          on HTML that didn't have headers
--
--                       ack_one_trig - added call to web_std_pkg.print_styles
--                          on HTML that didn't have headers
--
-- 11/22/02  vmogilev    ea_form -
--                          o removed param passing for EDIT and COPY links
--                            to improve LOAD times
--                          o removed the following columns
--                            to improve LOAD times and display:
--                               - Event File
--                               - Started
--
-- 12/03/02  vmogilev    ea_form - added HOST filter
--
-- 12/16/02  vmogilev    disp_triggers - changed sort order from
--                          target, time to just time
--                       disp_triggers - changed WHERE clause on p_date
--                          from TRUNC(NVL(et.date_modified,et_trigger_time))
--                          to   TRUNC(et_trigger_time)
--                       disp_trig_grp - added et_status to the report
--                          added EP_ID to the link over to disp_triggers
--                       disp_triggers - added scroll back/forward on p_date
--
-- 12/18/02  vmogilev    epv_form - escaped '<' char in desc of event
--
-- 01/08/03  vmogilev    disp_trig_grp - changed sort order RRRR/MM/DD
--
-- 02/03/03  vmogilev    (3.5.26)
--                       get_trig_diff
--                       get_trig_output
--                          ADDED REPLACE(output_line,'<','&lt')
--                            AND REPLACE(etd_attribute9,'<','&lt')
--
-- 02/06/03  vmogilev    (3.5.27)
--                       ea_form - added p_ea_purge_freq
--
-- 02/10/03  vmogilev    (3.5.28)
--                       disp_triggers - added p_e_id parameter
--                          (called from history)
--                       history - created
--
-- 02/11/03  vmogilev    (3.5.29)
--                       get_trigger - created this is main API
--                          for displaying trigger output/attributes
--
--                       get_trig_diff - made private removed tables
--                       get_trig_output -
--                          made shared tables with get_trig_diff
--                          added p_prev_id made call to get_trig_diff
--                             if trig and prev trig are not same
--                          made private
--                       display_notif - added header to the table
--                       disp_triggers -
--                          removed links to get_trig_diff
--                          changed links to get_trigger
--
-- 02/25/03  vmogilev    (3.5.30)
--                       today - created
--                       get_trigger - added lookup functionality
--                       get_trig_output - placed call to get_trig_diff
--                          ahead of current attributes
--                       get_trig_diff - placed NEW vals ahead of OLD
--                       history - added NVL(e_name,e_code)
--                       event_header - created
--                       epv_form - pulled event detail cur into
--                          event_header proc, added back button
--                       ep_form - many nav changes now main screen
--                          reports all events with drill down to
--                          event thresholds, added DETAIL op to
--                          allow for threshold drilldown
--
-- 02/28/03  vmogilev    (3.5.31)
--                       ep_form - changed flow to display thres on
--                          update VS returning back to events page
--                          turned off report, detail and footer
--                          on exceptions to avoid double printing
--                       epv_form - removed event/thres from table
--                          row moving it to the header
--                       ea_form - changed update, create forms to
--                          refresh list screen for updated or inserted
--                          host only to speed up navigations
--                       show_ea_cnt - created (PRIVATE) called when
--                          no host is specified in "report mode"
--
-- 03/04/03  vmogilev    (3.5.32)
--                       get_trigger - added link to ea_form(target)
--
-- 03/05/03  vmogilev    (3.5.33)
--                       compare_button - created (INTERNAL)
--                       get_trigger - added compare with functionality
--
-- 03/06/03  vmogilev    (3.5.34)
--                       disp_triggers - removed OLD triggers report
--                          when print rending triggers
--                       disp_trig_grp - REMOVED all together
--                       ep_form - replaced link to disp_trig_grp with
--                          link to disp_triggers
--                       get_trigger - highlighted curr trig in compare
--                          with table
--
-- 03/10/03  vmogilev    (3.5.35)
--                       ep_form - added p_ep_coll_cp_id to handle
--                          collection based events instead of passing
--
-- 03/25/03  vmogilev    (3.5.36)
--                       ea_form - added ep_desc to ep_%_cur CURSORS
--
-- 03/26/03  vmogilev    (3.5.37)
--                       ea_form - added e_name to e_%_cur CURSORS
--
-- 05/05/03  vmogilev    (3.5.38)
--                       ep_form, epv_form - minor facelift
--                       (3.5.39)
--                       get_trigger - added paginate
--
-- 05/12/03  vmogilev    (3.5.40)
--                       get_trigger - NEXT/CUR/PREV paginate controls
--
-- 05/16/03  vmogilev    (3.5.41)
--                       today - added daily trend analysis
--
-- 05/28/03  vmogilev    (3.5.42)
--                       event_header - removed extra <PRE> tags
--
-- 07/05/05  vmogilev    (3.5.43)
--                       ea_form - added RULE hint to many PURGE-INTERNAL
-- 12/13/13  vmogilev    (3.5.44)
--                       disp_triggers - added p_evnt_cnt + p_target
--
-- 12/20/13  vmogilev    (3.5.45) - exposed get_trig_output
--
-- 12/23/13  vmogilev    (3.5.46) - added p_attr_search
-- ---------------------------------------------------------------------
PROCEDURE today(
   p_date IN VARCHAR2 DEFAULT TO_CHAR(SYSDATE,'RRRR-MON-DD'));

PROCEDURE get_trigger(
   p_et_id     IN NUMBER DEFAULT NULL
,  p_diff_with IN NUMBER DEFAULT NULL
,  p_pag_str   IN NUMBER DEFAULT 1
,  p_pag_int   IN NUMBER DEFAULT 19);

PROCEDURE history(
   p_week IN VARCHAR2 DEFAULT NULL);

PROCEDURE trg_notes(
   p_et_id     IN VARCHAR2 DEFAULT NULL
,  p_note      IN VARCHAR2 DEFAULT NULL
,  p_operation IN VARCHAR2 DEFAULT NULL
,  p_format    IN VARCHAR2 DEFAULT NULL);

PROCEDURE ack_all_trigs(
   p_out_type IN VARCHAR2 DEFAULT 'HTML');

PROCEDURE ack_one_trig(
   p_et_id IN NUMBER
,  p_out_type IN VARCHAR2 DEFAULT 'HTML');

PROCEDURE display_notif(
   p_et_id IN NUMBER);

PROCEDURE disp_triggers(
   p_h_id  IN VARCHAR2 DEFAULT 'x'
,  p_s_id  IN VARCHAR2 DEFAULT 'x'
,  p_phase IN VARCHAR2 DEFAULT 'x'
,  p_date  IN VARCHAR  DEFAULT NULL
,  p_ea_id IN VARCHAR2 DEFAULT 'x'
,  p_ep_id IN VARCHAR2 DEFAULT 'x'
,  p_e_id  IN VARCHAR2 DEFAULT 'x'
,  p_ack_flag IN VARCHAR2 DEFAULT 'x'
,  p_evnt_cnt in VARCHAR2 default null
,  p_target   in VARCHAR2 default null
,  p_attr_search in VARCHAR2 default null)

;

PROCEDURE ep_form(
   p_ep_id          IN VARCHAR2 DEFAULT NULL
,  p_e_id           IN VARCHAR2 DEFAULT NULL
,  p_e_code         IN VARCHAR2 DEFAULT NULL
,  p_date_modified  IN VARCHAR2 DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_ep_code        IN VARCHAR2 DEFAULT NULL
,  p_ep_hold_level  IN VARCHAR2 DEFAULT NULL
,  p_ep_desc        IN VARCHAR2 DEFAULT NULL
,  p_ep_coll_cp_id  IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT NULL);


PROCEDURE epv_form(
   p_epv_id        IN VARCHAR2 DEFAULT NULL
,  p_date_modified IN VARCHAR2 DEFAULT NULL
,  p_modified_by   IN VARCHAR2 DEFAULT NULL
,  p_created_by    IN VARCHAR2 DEFAULT NULL
,  p_e_id          IN VARCHAR2 DEFAULT NULL
,  p_e_code        IN VARCHAR2 DEFAULT NULL
,  p_ep_id         IN VARCHAR2 DEFAULT NULL
,  p_ep_code       IN VARCHAR2 DEFAULT NULL
,  p_epv_name      IN VARCHAR2 DEFAULT NULL
,  p_epv_value     IN VARCHAR2 DEFAULT NULL
,  p_epv_status    IN VARCHAR2 DEFAULT NULL
,  p_operation     IN VARCHAR2 DEFAULT NULL);

PROCEDURE ea_form(
   p_ea_id            IN VARCHAR2 DEFAULT NULL
,  p_e_id             IN VARCHAR2 DEFAULT NULL
,  p_ep_id            IN VARCHAR2 DEFAULT NULL
,  p_h_id             IN VARCHAR2 DEFAULT NULL
,  p_s_id             IN VARCHAR2 DEFAULT NULL
,  p_sc_id            IN VARCHAR2 DEFAULT NULL
,  p_pl_id            IN VARCHAR2 DEFAULT NULL
,  p_date_modified    IN VARCHAR2 DEFAULT NULL
,  p_ea_min_interval  IN VARCHAR2 DEFAULT NULL
,  p_ea_status        IN VARCHAR2 DEFAULT NULL
,  p_ea_start_time    IN VARCHAR2 DEFAULT NULL
,  p_ea_purge_freq    IN VARCHAR2 DEFAULT NULL
,  p_operation        IN VARCHAR2 DEFAULT NULL
,  p_sort             IN VARCHAR2 DEFAULT NULL);

PROCEDURE get_trig_output(
   p_trig_id IN NUMBER
,  p_prev_id IN NUMBER DEFAULT NULL);

END evnt_web_pkg;
/

show errors
