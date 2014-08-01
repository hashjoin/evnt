CREATE OR REPLACE PACKAGE evnt_util_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : evnt_util_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : evnt_util_pkgs.sql
-- DATE CREATED  : 05/17/2002
-- APPLICATION   : EVENTS
-- VERSION       : 1.2.10
-- DESCRIPTION   : Various Utils (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 05/17/02  vmogilev    created
--
-- 10/10/02  vmogilev    changed get_pending_mail to append
--                       $mail_grp_sub $mail_list_file after every
--                       trigger, this allows for any custom mailing
--                       program to submit pending mail. Before the
--                       output had to be parsed by AWK in mailman.sh
--
-- 10/18/02  vmogilev    insert_trigger_header - added acknowledgement
--                       get_pending_mail - added acknowledgement
--                          primary/secondary paging
--                       mail_ctrl - notofication inserts
--                       post_coll_purge - added the following tables
--                          event_trigger_notes
--                          event_trigger_notif
--
-- 10/21/02  vmogilev    get_pending_mail - implemented secondary
--                          emails with the following tresholds:
--                             o P_ACK_NOTIF_FREQ (freq of ack notif)
--                             o P_ACK_NOTIF_TRES (number of primary
--                                                 acks b4 going into
--                                                 secondary)
--
-- 02/05/03  vmogilev    (1.2.1)
--                       post_coll_mark - created
--                          called from collections (PULL) after
--                          it ends to mark triggers as ready for purge
--                          (et_purge_ready = 'Y')
--
-- 02/07/03  vmogilev    (1.2.2)
--                       ctrl - fixed bug where ea_started_time is NULL
--                          causing resubmission failure by changing to
--                          NVL(ea_started_time,SYSDATE) ntime
--
-- 03/10/03  vmogilev    (1.2.3)
--                       parse_event_parameters - added cp_code to the
--                          ep cursor to handle collection based events
--                          instead of using epv ...
--
-- 03/27/03  vmogilev    (1.2.4)
--                       reset - now reset the following statuses:
--                          R [running]
--                          l [local scheduled]
--                          r [remote scheduled]
--                       set_pend - created
--
-- 03/28/03  vmogilev    (1.2.5)
--                       set_pend - moved to glob_util_pkg
--                       reset - adjusted ea_status IN clause to be
--                          ea_status IN ('R','l') - [LOCAL events]
--                          ea_status IN ('R','r') - [REMOTE events]
--
-- 04/15/03  vmogilev    (1.2.6)
--                       insert_trigger_header - enabled notification
--                          suppressing on subsequent triggers that
--                          require acknowledgement
-- 29/SEP/2009	vmogilev	(1.2.7)
--				parse_event_assigment - added SC_TNS_ALIAS
-- 13/DEC/2010	vmogilev	(1.2.9)
--				purge_obsolete - created
-- 01/AUG/2014  vmogilev    ((1.2.10)  refresh_event_triggers_sum - created
-- ---------------------------------------------------------------------
PROCEDURE mail_ctrl(
   p_et_id  IN NUMBER
,  p_a_id   IN NUMBER DEFAULT NULL
,  p_ae_id  IN NUMBER DEFAULT NULL
,  p_type   IN VARCHAR2
,  p_status IN VARCHAR2);

PROCEDURE reset(
   p_rhost  IN VARCHAR2 DEFAULT NULL);

PROCEDURE ctrl(
   p_ea_id IN NUMBER
,  p_stage IN VARCHAR2);

PROCEDURE set_event_env(
   p_ea_id IN NUMBER
,  p_out_ref_id OUT NUMBER);

PROCEDURE get_event_output(
   p_et_id IN NUMBER
,  p_out_ref_id OUT NUMBER);

PROCEDURE insert_trigger_header(
  p_et_id                      OUT NUMBER,
  p_ea_id                      IN NUMBER ,
  p_pl_id                      IN NUMBER ,
  p_e_id                       IN NUMBER ,
  p_h_id                       IN NUMBER ,
  p_s_id                       IN NUMBER ,
  p_sc_id                      IN NUMBER ,
  p_date_created               IN DATE,
  p_created_by                 IN VARCHAR2 ,
  p_et_trigger_time            IN DATE     ,
  p_et_status                  IN VARCHAR2 ,
  p_ET_ORIG_ET_ID              IN NUMBER   ,
  p_et_prev_et_id              IN NUMBER   ,
  p_et_prev_status             IN VARCHAR2 DEFAULT NULL,
  p_ep_hold_level              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute1              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute2              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute3              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute4              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute5              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute6              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute7              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute8              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute9              IN VARCHAR2 DEFAULT NULL,
  p_et_attribute10             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute11             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute12             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute13             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute14             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute15             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute17             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute18             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute19             IN VARCHAR2 DEFAULT NULL,
  p_et_attribute20             IN VARCHAR2 DEFAULT NULL);

PROCEDURE insert_trigger_detail(
  p_et_id             IN NUMBER ,
  p_date_created      IN DATE,
  p_created_by        IN VARCHAR2 ,
  p_etd_trigger_time  IN DATE     ,
  p_etd_status        IN VARCHAR2 ,
  p_etd_attribute1    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute2    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute3    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute4    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute5    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute6    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute7    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute8    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute9    IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute10   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute11   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute12   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute13   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute14   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute15   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute16   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute17   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute18   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute19   IN VARCHAR2 DEFAULT NULL,
  p_etd_attribute20   IN VARCHAR2 DEFAULT NULL);

PROCEDURE insert_trigger_output(
  p_et_id             IN NUMBER ,
  p_date_created      IN DATE,
  p_created_by        IN VARCHAR2 ,
  p_eto_output_line   IN VARCHAR2 DEFAULT NULL);

PROCEDURE get_pending_mail(
   p_ack_notif_freq IN NUMBER
,  p_ack_notif_tres IN NUMBER
,  p_out_ref_id     OUT NUMBER);

PROCEDURE post_coll_purge(
   p_driver_table IN VARCHAR2
,  p_db_link IN VARCHAR2);

PROCEDURE post_coll_mark(
   p_driver_table IN VARCHAR2
,  p_db_link IN VARCHAR2);

procedure purge_obsolete;

procedure refresh_event_triggers_sum;

END evnt_util_pkg;
/
show error
