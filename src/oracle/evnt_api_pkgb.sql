CREATE OR REPLACE PACKAGE BODY evnt_api_pkg AS
/* global vars */

/* private modules */

/* public modules */
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
,  p_operation      IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR event_cur IS
      SELECT e_id
      FROM   events
      WHERE  e_code = p_e_code;
   event event_cur%ROWTYPE;

   CURSOR update_chk_cur(p_e_id IN NUMBER) IS
      SELECT date_modified
      FROM   event_parameters
      WHERE  ep_id = p_ep_id
      AND    e_id = p_e_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   invalid_event  EXCEPTION;
   row_is_updated EXCEPTION;

   l_e_id event_parameters.e_id%TYPE;
   l_ep_id event_parameters.ep_id%TYPE;

BEGIN
   -- process event FK
   IF p_e_code IS NOT NULL AND
      p_e_id IS NULL THEN
      OPEN event_cur;
      FETCH event_cur INTO event;

      IF event_cur%FOUND THEN
         CLOSE event_cur;
         l_e_id := event.e_id;
      ELSE
         CLOSE event_cur;
         RAISE invalid_event;
      END IF;

   ELSIF p_e_code IS NULL AND
         p_e_id IS NOT NULL THEN
      l_e_id := p_e_id;

   ELSE
      RAISE invalid_event;
   END IF;

   IF p_operation = 'I' THEN
      SELECT event_parameters_S.NEXTVAL
      INTO   l_ep_id
      FROM   dual;

      INSERT INTO event_parameters(
         ep_id
      ,  e_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  ep_code
      ,  ep_hold_level
      ,  ep_desc
      ,  ep_coll_cp_id)
      VALUES(
         l_ep_id
      ,  l_e_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  UPPER(p_ep_code)
      ,  p_ep_hold_level
      ,  p_ep_desc
      ,  p_ep_coll_cp_id);

   ELSIF p_operation = 'U' THEN
      OPEN update_chk_cur(l_e_id);
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

         UPDATE event_parameters
         SET date_modified = SYSDATE
         ,   modified_by = NVL(p_modified_by,'API')
         ,   ep_code = UPPER(p_ep_code)
         ,   ep_hold_level = p_ep_hold_level
         ,   ep_desc = p_ep_desc
         ,   ep_coll_cp_id = p_ep_coll_cp_id
         WHERE ep_id = p_ep_id
         AND   e_id = l_e_id;

      ELSE
         CLOSE update_chk_cur;
         RAISE invalid_event;
      END IF;

   ELSIF p_operation = 'D' THEN
      delete event_parameter_values
       where ep_id = p_ep_id
         and e_id = l_e_id;

      DELETE event_parameters
      WHERE ep_id = p_ep_id
      AND   e_id = l_e_id;
   END IF;

EXCEPTION
   WHEN invalid_event THEN
      RAISE_APPLICATION_ERROR(-20003,'Invalid event - CODE='||p_e_code||' ID='||p_e_id);

   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');
END ep;


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
,  p_operation     IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR epvfk_cur IS
      SELECT ep.ep_id
      ,      e.e_id
      FROM   event_parameters ep
      ,      events e
      WHERE  ep.ep_code = p_ep_code
      AND    e.e_code = p_e_code
      AND    ep.e_id = e.e_id;
   epvfk epvfk_cur%ROWTYPE;

   CURSOR update_chk_cur IS
      SELECT date_modified
      FROM   event_parameter_values
      WHERE  epv_id = p_epv_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   l_ep_id event_parameters.ep_id%TYPE;
   l_e_id event_parameters.e_id%TYPE;
   l_epv_id event_parameter_values.epv_id%TYPE;

   invalid_fk_comb EXCEPTION;
   invalid_pk EXCEPTION;
   row_is_updated EXCEPTION;
BEGIN
   -- process FK
   IF p_e_id IS NULL AND
      p_ep_id IS NULL AND
      p_operation != 'D' THEN

      OPEN epvfk_cur;
      FETCH epvfk_cur INTO epvfk;
      IF epvfk_cur%FOUND THEN
         l_ep_id := epvfk.ep_id;
         l_e_id := epvfk.e_id;
      ELSE
         RAISE invalid_fk_comb;
      END IF;

   ELSE
      l_ep_id := p_ep_id;
      l_e_id := p_e_id;
   END IF;

   IF p_operation = 'I' THEN
      SELECT event_parameter_values_s.NEXTVAL
      INTO l_epv_id
      FROM dual;

      INSERT INTO event_parameter_values(
         epv_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  e_id
      ,  ep_id
      ,  epv_name
      ,  epv_value
      ,  epv_status)
      VALUES(
         l_epv_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  l_e_id
      ,  l_ep_id
      ,  UPPER(RTRIM(LTRIM(p_epv_name)))
      ,  p_epv_value
      ,  UPPER(p_epv_status));

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

         UPDATE event_parameter_values
         SET date_modified = SYSDATE
         ,   modified_by = NVL(p_modified_by,'API')
         ,   epv_name = UPPER(p_epv_name)
         ,   epv_value = p_epv_value
         ,   epv_status = UPPER(p_epv_status)
         WHERE epv_id = p_epv_id;

      ELSE
         CLOSE update_chk_cur;
         RAISE invalid_pk;
      END IF;

   ELSIF p_operation = 'D' THEN
      DELETE event_parameter_values
      WHERE epv_id = p_epv_id;

   END IF;

EXCEPTION
   WHEN invalid_pk THEN
      RAISE_APPLICATION_ERROR(-20003,'Invalid EPV_ID='||p_epv_id);

   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');

   WHEN invalid_fk_comb THEN
      RAISE_APPLICATION_ERROR(-20003,'Invalid E_CODE='||p_e_code||'/EP_CODE='||p_ep_code||' combination');

END epv;

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
,  p_operation         IN VARCHAR2 DEFAULT 'I')
IS
   CURSOR ea_update_cur(
             p_sc_id IN NUMBER
          ,  p_ea_min_interval IN NUMBER
          ,  p_ea_status IN VARCHAR2
          ,  p_ea_start_time IN DATE
          ,  p_ea_purge_freq IN NUMBER) IS
      SELECT  NVL(p_sc_id           ,sc_id          ) sc_id
      ,       NVL(p_ea_min_interval ,ea_min_interval) ea_min_interval
      ,       NVL(p_ea_status       ,ea_status      ) ea_status
      ,       NVL(p_ea_start_time   ,ea_start_time  ) ea_start_time
      ,       NVL(p_ea_purge_freq   ,ea_purge_freq  ) ea_purge_freq
      FROM event_assigments
      WHERE ea_id = p_ea_id;
   ea_update ea_update_cur%ROWTYPE;


   CURSOR update_chk_cur IS
      SELECT date_modified
      FROM   event_assigments
      WHERE  ea_id = p_ea_id
      FOR UPDATE OF date_modified NOWAIT;
   update_chk update_chk_cur%ROWTYPE;

   l_ea_id event_assigments.ea_id%TYPE;

   l_e_id event_parameters.e_id%TYPE;
   l_ep_id event_parameters.ep_id%TYPE;
   l_h_id hosts.h_id%TYPE;
   l_s_id sids.s_id%TYPE;
   l_s_id_chk sids.s_id%TYPE;
   l_pl_id page_lists.pl_id%TYPE;
   l_sc_id sid_credentials.sc_id%TYPE;

   invalid_pk EXCEPTION;
   row_is_updated EXCEPTION;
BEGIN

   -- event_parameters FK
   --
   IF p_operation != 'D' AND
      p_e_id IS NULL AND
      p_ep_id IS NULL THEN
      BEGIN
         SELECT ep.e_id
         ,      ep.ep_id
         INTO l_e_id
         ,    l_ep_id
         FROM event_parameters ep
         ,    events e
         WHERE ep.ep_code = p_ep_code
         AND   ep.e_id = e.e_id
         AND   e.e_code = p_e_code;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,'Invalid E_CODE='||p_e_code||'/EP_CODE='||p_ep_code||' combination');
      END;
   ELSE
      l_e_id := p_e_id;
      l_ep_id := p_ep_id;
   END IF;


   -- hosts FK
   --
   IF p_operation != 'D' AND
      p_h_id IS NULL THEN
      BEGIN
         SELECT h_id
         INTO l_h_id
         FROM hosts
         WHERE h_name = p_h_name;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,'Invalid H_NAME='||p_h_name);
      END;
   ELSE
      l_h_id := p_h_id;
   END IF;


   -- sids FK
   --
   IF p_operation != 'D' AND
      p_s_id IS NULL AND
      p_s_name IS NOT NULL THEN

      BEGIN
         SELECT s_id
         INTO l_s_id
         FROM sids
         WHERE s_name = p_s_name;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,'Invalid S_NAME='||p_s_name);
      END;
   ELSE
      l_s_id := p_s_id;
   END IF;


   -- validate HOST/SID combination
   --
   IF p_operation != 'D' AND
      l_s_id IS NOT NULL THEN

      BEGIN
         SELECT s_id
         INTO l_s_id_chk
         FROM sids
         WHERE s_id = l_s_id
         AND   h_id = l_h_id;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,'Invalid S_ID='||l_s_id||'/H_ID='||l_h_id||' combination');
      END;
   END IF;


   -- page_lists FK
   --
   IF p_operation != 'D' AND
      p_pl_id IS NULL THEN

      BEGIN
         SELECT pl_id
         INTO l_pl_id
         FROM page_lists
         WHERE pl_code = p_pl_code;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,'Invalid PL_CODE='||p_pl_code);
      END;
   ELSE
      l_pl_id := p_pl_id;
   END IF;


   -- sid_credentials FK
   --
   IF p_operation != 'D' AND
      l_s_id IS NOT NULL AND
      p_sc_id IS NULL THEN

      BEGIN
         SELECT sc_id
         INTO l_sc_id
         FROM sid_credentials
         WHERE sc_username = p_sc_username
         AND   s_id = l_s_id;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,'Invalid S_ID='||l_s_id||'/SC_USERNAME='||p_sc_username||' combination');
      END;

   ELSIF p_operation != 'D' AND
         l_s_id IS NOT NULL AND
         p_sc_id IS NOT NULL THEN

      BEGIN
         SELECT sc_id
         INTO l_sc_id
         FROM sid_credentials
         WHERE sc_id = p_sc_id
         AND   s_id = l_s_id;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003,'Invalid S_ID='||l_s_id||'/SC_ID='||p_sc_id||' combination');
      END;

   ELSE
      l_sc_id := p_sc_id;
   END IF;




   IF p_operation = 'I' THEN
      SELECT event_assigments_s.NEXTVAL
      INTO l_ea_id
      FROM dual;

      INSERT INTO event_assigments(
         ea_id
      ,  e_id
      ,  ep_id
      ,  h_id
      ,  s_id
      ,  sc_id
      ,  pl_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  ea_min_interval
      ,  ea_status
      ,  ea_start_time
      ,  ea_purge_freq)
      VALUES(
         l_ea_id
      ,  l_e_id
      ,  l_ep_id
      ,  l_h_id
      ,  l_s_id
      ,  l_sc_id
      ,  l_pl_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  p_ea_min_interval
      ,  p_ea_status
      ,  NVL(p_ea_start_time,SYSDATE)
      ,  p_ea_purge_freq);

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

         --
         --    There are only few columns
         --    that can be updated due to
         --    EVENT_TRIGGERS table dependency (see below)
         --
         --    EVENT_TRIGGERS is higly denormalized
         --    thus it can be misleading that it can
         --    function independently from EVENT_ASSIGMENTS.PK
         --    but it's just an illusion.  Infact the only
         --    real FK in EVENT_TRIGGERS is the one linked to
         --    EVENT_ASSIGMENTS
         --
         --    Than's why I only allow UPDATE of non vital
         --    FK (page list, sid credential, ep_id [treshold]) on EVENT_ASSIGMENTS
         --    All other FK are non updateable.
         --

         OPEN ea_update_cur(
                 l_sc_id
              ,  p_ea_min_interval
              ,  p_ea_status
              ,  p_ea_start_time
              ,  p_ea_purge_freq);
         FETCH ea_update_cur INTO ea_update;
         IF ea_update_cur%FOUND THEN
            CLOSE ea_update_cur;

            UPDATE event_assigments
            SET sc_id = ea_update.sc_id
            ,   pl_id = l_pl_id
            ,   ep_id = l_ep_id
            ,   ea_min_interval  = ea_update.ea_min_interval
            ,   ea_status        = ea_update.ea_status
            ,   ea_start_time    = ea_update.ea_start_time
            ,   ea_purge_freq    = ea_update.ea_purge_freq
            ,   date_modified = SYSDATE
            ,   modified_by = NVL(p_modified_by,'API')
            WHERE ea_id = p_ea_id;
         ELSE
            CLOSE ea_update_cur;
            RAISE invalid_pk;
         END IF;


      ELSE
         CLOSE update_chk_cur;
         RAISE invalid_pk;
      END IF;


   ELSIF p_operation = 'D' THEN
      DELETE event_assigments
      WHERE ea_id = p_ea_id;

   END IF;

EXCEPTION
   WHEN invalid_pk THEN
      RAISE_APPLICATION_ERROR(-20003,'Invalid EA_ID='||p_ea_id);

   WHEN row_is_updated THEN
      RAISE_APPLICATION_ERROR(-20003,'Row has been updated');
END ea;


-- at this time I only support
-- additions to notes table
--
PROCEDURE etn(
   p_et_id      IN NUMBER   DEFAULT NULL
,  p_created_by IN VARCHAR2 DEFAULT NULL
,  p_string     IN VARCHAR2 DEFAULT NULL
,  p_format     IN VARCHAR2 DEFAULT 'TEXT')
IS
   string_len    INTEGER := LENGTH(p_string);
   line_size     INTEGER := 3999;
   last_position INTEGER := 1;
   chunk         INTEGER := 0;
   cur_line      VARCHAR2(4000);
BEGIN
   INSERT INTO event_trigger_notes(
      tn_id
   ,  date_created
   ,  date_modified
   ,  modified_by
   ,  created_by
   ,  et_id
   ,  tn_note)
   VALUES(
      event_trigger_notes_s.NEXTVAL
   ,  SYSDATE
   ,  NULL
   ,  NULL
   ,  NVL(p_created_by,'API')
   ,  p_et_id
   ,  '<pre><b>*** '||NVL(p_created_by,'API')||' '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS')||' ***</b></pre>');
   
   
   IF p_format = 'TEXT' THEN
      INSERT INTO event_trigger_notes(
         tn_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  et_id
      ,  tn_note)
      VALUES(
         event_trigger_notes_s.NEXTVAL
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  p_et_id
      ,  '<pre>');
   END IF;

   IF string_len > 3999 THEN
      WHILE SUBSTR(p_string,last_position,line_size) IS NOT NULL LOOP
         cur_line := SUBSTR(p_string,last_position,line_size);
         chunk := chunk+1;
         last_position := (line_size*chunk)+1;
      
         INSERT INTO event_trigger_notes(
            tn_id
         ,  date_created
         ,  date_modified
         ,  modified_by
         ,  created_by
         ,  et_id
         ,  tn_note)
         VALUES(
            event_trigger_notes_s.NEXTVAL
         ,  SYSDATE
         ,  NULL
         ,  NULL
         ,  NVL(p_created_by,'API')
         ,  p_et_id
         ,  cur_line);
      END LOOP;

   ELSE
      INSERT INTO event_trigger_notes(
         tn_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  et_id
      ,  tn_note)
      VALUES(
         event_trigger_notes_s.NEXTVAL
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  p_et_id
      ,  p_string);
   END IF;
   
   
   IF p_format = 'TEXT' THEN
      INSERT INTO event_trigger_notes(
         tn_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  et_id
      ,  tn_note)
      VALUES(
         event_trigger_notes_s.NEXTVAL
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  NVL(p_created_by,'API')
      ,  p_et_id
      ,  '</pre>');
   END IF;
   
END etn;


END evnt_api_pkg;
/
show error
