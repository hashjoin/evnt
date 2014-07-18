CREATE OR REPLACE PACKAGE BODY glob_api_pkg AS
/* global vars */

/* private modules */

/* public modules */

PROCEDURE ae(
   p_ae_id             IN NUMBER   DEFAULT NULL
,  p_date_modified     IN DATE     DEFAULT NULL
,  p_modified_by       IN VARCHAR2 DEFAULT NULL
,  p_created_by        IN VARCHAR2 DEFAULT NULL
,  p_a_id              IN NUMBER   DEFAULT NULL
,  p_ae_email          IN VARCHAR2 DEFAULT NULL
,  p_ae_append_logfile IN VARCHAR2 DEFAULT NULL
,  p_ae_desc           IN VARCHAR2 DEFAULT NULL
,  p_operation         IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR update_chk_cur IS
      SELECT date_modified
      FROM   admin_emails
      WHERE  a_id = p_a_id
      AND    ae_id = p_ae_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   row_is_updated EXCEPTION;

   l_ae_id admin_emails.ae_id%TYPE;
BEGIN
   IF p_operation = 'I' THEN

      SELECT admin_emails_s.NEXTVAL
      INTO l_ae_id
      FROM dual;

      INSERT INTO admin_emails(
         ae_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  a_id
      ,  ae_email
      ,  ae_append_logfile
      ,  ae_desc)
      VALUES(
         l_ae_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  p_a_id
      ,  p_ae_email
      ,  UPPER(p_ae_append_logfile)
      ,  UPPER(p_ae_desc));

   ELSIF p_operation = 'U' THEN
      OPEN update_chk_cur;
      FETCH update_chk_cur INTO update_chk;

      IF update_chk_cur%FOUND THEN
         CLOSE update_chk_cur;

         -- check that the rows are identical
         -- NOTE:
         -- =====
         --  on the first update there's a chance
         --  of overwride
         --
         IF update_chk.date_modified IS NOT NULL AND
            update_chk.date_modified != p_date_modified THEN
            RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NULL AND
               p_date_modified IS NOT NULL THEN
               RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NOT NULL AND
               p_date_modified IS NULL THEN
               RAISE row_is_updated;
         END IF;

         UPDATE admin_emails
         SET date_modified = SYSDATE
         ,   modified_by   = NVL(p_modified_by,'API')
         ,   ae_email = p_ae_email
         ,   ae_append_logfile = UPPER(p_ae_append_logfile)
         ,   ae_desc = p_ae_desc
         WHERE a_id = p_a_id
         AND   ae_id = p_ae_id;

      ELSE
         CLOSE update_chk_cur;
         RAISE_APPLICATION_ERROR(-20003,'Invalid AE_ID='||p_ae_id||' A_ID='||p_a_id||' combination');
      END IF;

   ELSIF p_operation = 'D' THEN
      DELETE admin_emails
      WHERE a_id = p_a_id
      AND   ae_id = p_ae_id;
   END IF;

EXCEPTION
   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');
END ae;


PROCEDURE a(
   p_a_id           IN NUMBER   DEFAULT NULL
,  p_date_modified  IN DATE     DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_a_name         IN VARCHAR2 DEFAULT NULL
,  p_a_desc         IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR update_chk_cur IS
      SELECT date_modified
      FROM   admins
      WHERE  a_id = p_a_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   row_is_updated EXCEPTION;

   l_a_id admins.a_id%TYPE;
BEGIN
   IF p_operation = 'I' THEN

      SELECT admins_s.NEXTVAL
      INTO l_a_id
      FROM dual;

      INSERT INTO admins(
         a_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  a_name
      ,  a_desc)
      VALUES(
         l_a_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  UPPER(p_a_name)
      ,  p_a_desc);

   ELSIF p_operation = 'U' THEN
      OPEN update_chk_cur;
      FETCH update_chk_cur INTO update_chk;

      IF update_chk_cur%FOUND THEN
         CLOSE update_chk_cur;

         -- check that the rows are identical
         -- NOTE:
         -- =====
         --  on the first update there's a chance
         --  of overwride
         --
         IF update_chk.date_modified IS NOT NULL AND
            update_chk.date_modified != p_date_modified THEN
            RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NULL AND
               p_date_modified IS NOT NULL THEN
               RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NOT NULL AND
               p_date_modified IS NULL THEN
               RAISE row_is_updated;
         END IF;

         UPDATE admins
         SET date_modified = SYSDATE
         ,   modified_by   = NVL(p_modified_by,'API')
         ,   a_desc = p_a_desc
         WHERE a_id = p_a_id;

      ELSE
         CLOSE update_chk_cur;
         RAISE_APPLICATION_ERROR(-20003,'Invalid A_ID='||p_a_id);
      END IF;

   ELSIF p_operation = 'D' THEN
      DELETE admins
      WHERE a_id = p_a_id;
   END IF;

EXCEPTION
   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');
END a;


PROCEDURE pld(
   p_pld_id         IN NUMBER   DEFAULT NULL
,  p_date_modified  IN DATE     DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_pl_id          IN NUMBER   DEFAULT NULL
,  p_a_id           IN NUMBER   DEFAULT NULL
,  p_ae_id          IN NUMBER   DEFAULT NULL
,  p_pld_status     IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR update_chk_cur IS
      SELECT date_modified
      FROM   page_list_definitions
      WHERE  pld_id = p_pld_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   row_is_updated EXCEPTION;

   l_pld_id page_list_definitions.pld_id%TYPE;
BEGIN
   IF p_operation = 'I' THEN

      SELECT page_list_definitions_s.NEXTVAL
      INTO l_pld_id
      FROM dual;

      INSERT INTO page_list_definitions(
         pld_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  pl_id
      ,  a_id
      ,  ae_id
      ,  pld_status)
      VALUES(
         l_pld_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  p_pl_id
      ,  p_a_id
      ,  p_ae_id
      ,  UPPER(p_pld_status));

   ELSIF p_operation = 'U' THEN
      OPEN update_chk_cur;
      FETCH update_chk_cur INTO update_chk;

      IF update_chk_cur%FOUND THEN
         CLOSE update_chk_cur;

         -- check that the rows are identical
         -- NOTE:
         -- =====
         --  on the first update there's a chance
         --  of overwride
         --
         IF update_chk.date_modified IS NOT NULL AND
            update_chk.date_modified != p_date_modified THEN
            RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NULL AND
               p_date_modified IS NOT NULL THEN
               RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NOT NULL AND
               p_date_modified IS NULL THEN
               RAISE row_is_updated;
         END IF;

         UPDATE page_list_definitions
         SET date_modified = SYSDATE
         ,   modified_by   = NVL(p_modified_by,'API')
         ,   pld_status = UPPER(p_pld_status)
         WHERE pld_id = p_pld_id;

      ELSE
         CLOSE update_chk_cur;
         RAISE_APPLICATION_ERROR(-20003,'Invalid PLD_ID='||p_pld_id);
      END IF;

   ELSIF p_operation = 'D' THEN
      DELETE page_list_definitions
      WHERE pld_id = p_pld_id;
   END IF;

EXCEPTION
   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');
END pld;


PROCEDURE pl(
   p_pl_id           IN NUMBER   DEFAULT NULL
,  p_date_modified   IN DATE     DEFAULT NULL
,  p_modified_by     IN VARCHAR2 DEFAULT NULL
,  p_created_by      IN VARCHAR2 DEFAULT NULL
,  p_pl_code         IN VARCHAR2 DEFAULT NULL
,  p_pl_desc         IN VARCHAR2 DEFAULT NULL
,  p_pl_ack_required IN VARCHAR2 DEFAULT NULL
,  p_operation       IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR update_chk_cur IS
      SELECT date_modified
      FROM   page_lists
      WHERE  pl_id = p_pl_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   row_is_updated EXCEPTION;

   l_pl_id page_lists.pl_id%TYPE;
BEGIN
   IF p_operation = 'I' THEN
      SELECT page_lists_s.NEXTVAL
      INTO l_pl_id
      FROM dual;

      INSERT INTO page_lists(
         pl_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  pl_code
      ,  pl_desc
      ,  pl_ack_required)
      VALUES(
         l_pl_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  UPPER(p_pl_code)
      ,  p_pl_desc
      ,  UPPER(p_pl_ack_required));

   ELSIF p_operation = 'U' OR
         p_operation = 'U-ACK' THEN

      OPEN update_chk_cur;
      FETCH update_chk_cur INTO update_chk;

      IF update_chk_cur%FOUND THEN
         CLOSE update_chk_cur;

         -- check that the rows are identical
         -- NOTE:
         -- =====
         --  on the first update there's a chance
         --  of overwride
         --
         IF update_chk.date_modified IS NOT NULL AND
            update_chk.date_modified != p_date_modified THEN
            RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NULL AND
               p_date_modified IS NOT NULL THEN
               RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NOT NULL AND
               p_date_modified IS NULL THEN
               RAISE row_is_updated;
         END IF;

         IF p_operation = 'U-ACK' THEN
            UPDATE page_lists
            SET date_modified = SYSDATE
            ,   modified_by   = NVL(p_modified_by,'API')
            ,   pl_ack_required = UPPER(p_pl_ack_required)
            WHERE pl_id = p_pl_id;
         ELSE
            UPDATE page_lists
            SET date_modified = SYSDATE
            ,   modified_by   = NVL(p_modified_by,'API')
            ,   pl_code = p_pl_code
            ,   pl_desc = p_pl_desc
            ,   pl_ack_required = UPPER(p_pl_ack_required)
            WHERE pl_id = p_pl_id;
         END IF;

      ELSE
         CLOSE update_chk_cur;
         RAISE_APPLICATION_ERROR(-20003,'Invalid PL_ID='||p_pl_id);
      END IF;

   ELSIF p_operation = 'D' THEN
      DELETE page_lists
      WHERE pl_id = p_pl_id;
   END IF;

EXCEPTION
   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');
END pl;


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
,  p_operation      IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR update_chk_cur IS
      SELECT date_modified
      FROM   event_blackouts
      WHERE  eb_id = p_eb_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   row_is_updated EXCEPTION;

   l_eb_id event_blackouts.eb_id%TYPE;

BEGIN
   IF p_operation = 'I' THEN
      SELECT event_blackouts_s.NEXTVAL
      INTO l_eb_id
      FROM dual;

      INSERT INTO event_blackouts(
         eb_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  eb_code
      ,  eb_type
      ,  eb_type_id
      ,  eb_start_date
      ,  eb_end_date
      ,  eb_week_day
      ,  eb_active_flag
      ,  eb_desc)
      VALUES(
         l_eb_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  p_eb_code
      ,  p_eb_type
      ,  p_eb_type_id
      ,  p_eb_start_date
      ,  p_eb_end_date
      ,  p_eb_week_day
      ,  UPPER(p_eb_active_flag)
      ,  p_eb_desc);

   ELSIF p_operation = 'U' THEN
      OPEN update_chk_cur;
      FETCH update_chk_cur INTO update_chk;

      IF update_chk_cur%FOUND THEN
         CLOSE update_chk_cur;

         -- check that the rows are identical
         -- NOTE:
         -- =====
         --  on the first update there's a chance
         --  of overwride
         --
         IF update_chk.date_modified IS NOT NULL AND
            update_chk.date_modified != p_date_modified THEN
            RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NULL AND
               p_date_modified IS NOT NULL THEN
               RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NOT NULL AND
               p_date_modified IS NULL THEN
               RAISE row_is_updated;
         END IF;

         UPDATE event_blackouts
         SET date_modified = SYSDATE
         ,   modified_by   = NVL(p_modified_by,'API')
         ,   eb_code       = p_eb_code
         ,   eb_type       = p_eb_type
         ,   eb_type_id    = p_eb_type_id
         ,   eb_start_date = p_eb_start_date
         ,   eb_end_date   = p_eb_end_date
         ,   eb_week_day   = p_eb_week_day
         ,   eb_active_flag = UPPER(p_eb_active_flag)
         ,   eb_desc = p_eb_desc
         WHERE eb_id = p_eb_id;

      ELSE
         CLOSE update_chk_cur;
         RAISE_APPLICATION_ERROR(-20003,'Invalid EB_ID='||p_eb_id);
      END IF;

   ELSIF p_operation = 'D' THEN
      DELETE event_blackouts
      WHERE eb_id = p_eb_id;
   END IF;

EXCEPTION
   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');
END eb;


PROCEDURE ab(
   p_ab_id          IN NUMBER   DEFAULT NULL
,  p_date_modified  IN DATE     DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_primary_a_id   IN NUMBER   DEFAULT NULL
,  p_backup_a_id    IN NUMBER   DEFAULT NULL
,  p_backup_ae_id   IN NUMBER   DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR update_chk_cur IS
      SELECT date_modified
      FROM   admin_backups
      WHERE  ab_id = p_ab_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   row_is_updated EXCEPTION;
BEGIN
   IF p_operation = 'I' THEN
      INSERT INTO admin_backups(
         ab_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  primary_a_id
      ,  backup_a_id
      ,  backup_ae_id)
      VALUES(
         admin_backups_s.NEXTVAL
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  p_primary_a_id
      ,  p_backup_a_id
      ,  p_backup_ae_id);
   
   ELSIF p_operation = 'U' THEN
      
      OPEN update_chk_cur;
      FETCH update_chk_cur INTO update_chk;

      IF update_chk_cur%FOUND THEN
         CLOSE update_chk_cur;

         -- check that the rows are identical
         -- NOTE:
         -- =====
         --  on the first update there's a chance
         --  of overwride
         --
         IF update_chk.date_modified IS NOT NULL AND
            update_chk.date_modified != p_date_modified THEN
            RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NULL AND
               p_date_modified IS NOT NULL THEN
               RAISE row_is_updated;
         ELSIF update_chk.date_modified IS NOT NULL AND
               p_date_modified IS NULL THEN
               RAISE row_is_updated;
         END IF;

         UPDATE admin_backups
         SET date_modified = SYSDATE
         ,   modified_by = NVL(p_modified_by,'API')
         ,   primary_a_id = p_primary_a_id
         ,   backup_a_id = p_backup_a_id
         ,   backup_ae_id = p_backup_ae_id
         WHERE ab_id = p_ab_id;

      ELSE
         CLOSE update_chk_cur;
         RAISE_APPLICATION_ERROR(-20003,'Invalid AB_ID='||p_ab_id);
      END IF;

   ELSIF p_operation = 'D' THEN
      DELETE admin_backups
      WHERE ab_id = p_ab_id;
   END IF;

EXCEPTION
   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');
END ab;


END glob_api_pkg;
/
show error
