CREATE OR REPLACE PACKAGE glob_api_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : glob_api_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : glob_api_pkgs.sql
-- DATE CREATED  : 08/21/2002
-- APPLICATION   : GLOBAL
-- VERSION       : 1.1
-- DESCRIPTION   : Various Api for data entry (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 08/21/02  vmogilev    created
--
-- 10/24/02  vmogilev    ab - created
-- ---------------------------------------------------------------------
PROCEDURE ab(
   p_ab_id          IN NUMBER   DEFAULT NULL
,  p_date_modified  IN DATE     DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_primary_a_id   IN NUMBER   DEFAULT NULL
,  p_backup_a_id    IN NUMBER   DEFAULT NULL
,  p_backup_ae_id   IN NUMBER   DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT 'I');

PROCEDURE ae(
   p_ae_id             IN NUMBER   DEFAULT NULL
,  p_date_modified     IN DATE     DEFAULT NULL
,  p_modified_by       IN VARCHAR2 DEFAULT NULL
,  p_created_by        IN VARCHAR2 DEFAULT NULL
,  p_a_id              IN NUMBER   DEFAULT NULL
,  p_ae_email          IN VARCHAR2 DEFAULT NULL
,  p_ae_append_logfile IN VARCHAR2 DEFAULT NULL
,  p_ae_desc           IN VARCHAR2 DEFAULT NULL
,  p_operation         IN VARCHAR2 DEFAULT 'I');

PROCEDURE a(
   p_a_id           IN NUMBER   DEFAULT NULL
,  p_date_modified  IN DATE     DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_a_name         IN VARCHAR2 DEFAULT NULL
,  p_a_desc         IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT 'I');

PROCEDURE pld(
   p_pld_id         IN NUMBER   DEFAULT NULL
,  p_date_modified  IN DATE     DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_pl_id          IN NUMBER   DEFAULT NULL
,  p_a_id           IN NUMBER   DEFAULT NULL
,  p_ae_id          IN NUMBER   DEFAULT NULL
,  p_pld_status     IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT 'I');

PROCEDURE pl(
   p_pl_id           IN NUMBER   DEFAULT NULL
,  p_date_modified   IN DATE     DEFAULT NULL
,  p_modified_by     IN VARCHAR2 DEFAULT NULL
,  p_created_by      IN VARCHAR2 DEFAULT NULL
,  p_pl_code         IN VARCHAR2 DEFAULT NULL
,  p_pl_desc         IN VARCHAR2 DEFAULT NULL
,  p_pl_ack_required IN VARCHAR2 DEFAULT NULL
,  p_operation       IN VARCHAR2 DEFAULT 'I');

PROCEDURE eb(
   p_eb_id          IN NUMBER   DEFAULT NULL
,  p_date_created   IN DATE     DEFAULT NULL
,  p_date_modified  IN DATE     DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_eb_code        IN VARCHAR2 DEFAULT NULL
,  p_eb_type        IN VARCHAR2 DEFAULT NULL
,  p_eb_type_id     IN NUMBER   DEFAULT NULL
,  p_eb_start_date  IN DATE     DEFAULT NULL
,  p_eb_end_date    IN DATE     DEFAULT NULL
,  p_eb_week_day    IN NUMBER   DEFAULT NULL
,  p_eb_active_flag IN VARCHAR2 DEFAULT NULL
,  p_eb_desc        IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT 'I');

END glob_api_pkg;
/
show error
