CREATE OR REPLACE PACKAGE evnt_api_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : evnt_api_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : evnt_api_pkgs.sql
-- DATE CREATED  : 07/30/2002
-- APPLICATION   : EVENTS
-- VERSION       : 1.1.3
-- DESCRIPTION   : Various Api for data entry (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 07/30/02  vmogilev    created
--
-- 10/29/02  vmogilev    etn - created
--
-- 02/06/03  vmogilev    (1.1.1)
--                       ea - added p_ea_purge_freq
--
-- 03/10/03  vmogilev    (1.1.2)
--                       ep - added p_ep_coll_cp_id
-- 29/SEP/2009	vmogilev	(1.1.3)
--				ep - added delete from EPV when op=D
-- ---------------------------------------------------------------------
PROCEDURE etn(
   p_et_id      IN NUMBER   DEFAULT NULL
,  p_created_by IN VARCHAR2 DEFAULT NULL
,  p_string     IN VARCHAR2 DEFAULT NULL
,  p_format     IN VARCHAR2 DEFAULT 'TEXT');

PROCEDURE ep(
   p_ep_id          IN NUMBER   DEFAULT NULL
,  p_e_id           IN NUMBER   DEFAULT NULL
,  p_e_code         IN VARCHAR2 DEFAULT NULL
,  p_date_modified  IN DATE     DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_ep_code        IN VARCHAR2 DEFAULT NULL
,  p_ep_hold_level  IN VARCHAR2 DEFAULT NULL
,  p_ep_desc        IN VARCHAR2 DEFAULT NULL
,  p_ep_coll_cp_id  IN NUMBER   DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT 'I');

PROCEDURE epv(
   p_epv_id        IN NUMBER   DEFAULT NULL
,  p_date_modified IN DATE     DEFAULT NULL
,  p_modified_by   IN VARCHAR2 DEFAULT NULL
,  p_created_by    IN VARCHAR2 DEFAULT NULL
,  p_e_id          IN NUMBER   DEFAULT NULL
,  p_e_code        IN VARCHAR2 DEFAULT NULL
,  p_ep_id         IN NUMBER   DEFAULT NULL
,  p_ep_code       IN VARCHAR2 DEFAULT NULL
,  p_epv_name      IN VARCHAR2 DEFAULT NULL
,  p_epv_value     IN VARCHAR2 DEFAULT NULL
,  p_epv_status    IN VARCHAR2 DEFAULT NULL
,  p_operation     IN VARCHAR2 DEFAULT 'I');

PROCEDURE ea(
   p_ea_id             IN NUMBER   DEFAULT NULL
,  p_e_id              IN NUMBER   DEFAULT NULL
,  p_e_code            IN VARCHAR2 DEFAULT NULL
,  p_ep_id             IN NUMBER   DEFAULT NULL
,  p_ep_code           IN VARCHAR2 DEFAULT NULL
,  p_h_id              IN NUMBER   DEFAULT NULL
,  p_h_name            IN VARCHAR2 DEFAULT NULL
,  p_s_id              IN NUMBER   DEFAULT NULL
,  p_s_name            IN VARCHAR2 DEFAULT NULL
,  p_sc_id             IN NUMBER   DEFAULT NULL
,  p_sc_username       IN VARCHAR2 DEFAULT NULL
,  p_pl_id             IN NUMBER   DEFAULT NULL
,  p_pl_code           IN VARCHAR2 DEFAULT NULL
,  p_date_modified     IN DATE     DEFAULT NULL
,  p_modified_by       IN VARCHAR2 DEFAULT NULL
,  p_created_by        IN VARCHAR2 DEFAULT NULL
,  p_ea_min_interval   IN NUMBER   DEFAULT NULL
,  p_ea_status         IN VARCHAR2 DEFAULT NULL
,  p_ea_start_time     IN DATE     DEFAULT NULL
,  p_ea_purge_freq     IN NUMBER   DEFAULT NULL
,  p_operation         IN VARCHAR2 DEFAULT 'I');
END evnt_api_pkg;
/
show error
