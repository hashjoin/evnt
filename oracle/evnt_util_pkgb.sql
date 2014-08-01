CREATE OR REPLACE PACKAGE BODY evnt_util_pkg AS
/* global vars */
g_out_ref_id NUMBER;
g_out_ref_type VARCHAR2(50);

g_ep_id NUMBER;
g_e_id NUMBER;
g_h_id NUMBER;
g_s_id NUMBER;

g_mon_pref VARCHAR2(10) := 'MON__';
g_der_pref VARCHAR2(10) := 'DER__';
g_par_pref VARCHAR2(10) := 'PARAM__';

set_event_env_out_code    CONSTANT VARCHAR2(50) := 'SETENV';
get_event_output_out_code CONSTANT VARCHAR2(50) := 'GETOUT';

get_pending_mail_out_code_trg CONSTANT VARCHAR2(50) := 'MAILPEND_TRG';
get_pending_mail_out_code_pgl CONSTANT VARCHAR2(50) := 'MAILPEND_PGL';




/* PRIVATE MODULES */
FUNCTION get_next_ref_id RETURN NUMBER
IS
   l_return_value NUMBER(38,0);
BEGIN
   SELECT evnt_util_pkg_out_ref_id_s.NEXTVAL
   INTO l_return_value
   FROM dual;
   RETURN l_return_value;
END;



PROCEDURE dump_output(p_out in VARCHAR2)
IS
BEGIN
   INSERT INTO evnt_util_pkg_out(
      EUPO_ID
   ,  EUPO_DATE
   ,  EUPO_REF_ID
   ,  EUPO_REF_TYPE
   ,  EUPO_OUT)
   VALUES(
      evnt_util_pkg_out_s.NEXTVAL
   ,  SYSDATE
   ,  g_out_ref_id
   ,  g_out_ref_type
   ,  p_out);
END dump_output;

PROCEDURE parse_event_assigment(p_ea_id IN NUMBER)
IS
   CURSOR assigment_cur IS
      SELECT
           g_mon_pref||'EA_ID='           ||ea_id             ||'; export '||g_mon_pref||'EA_ID;'
         ||g_mon_pref||'E_ID='            ||e_id              ||'; export '||g_mon_pref||'E_ID;'
         ||g_mon_pref||'EP_ID='           ||ep_id             ||'; export '||g_mon_pref||'EP_ID;'
         ||g_mon_pref||'H_ID='            ||h_id              ||'; export '||g_mon_pref||'H_ID;'
         ||g_mon_pref||'S_ID='            ||s_id              ||'; export '||g_mon_pref||'S_ID;'
         ||g_mon_pref||'SC_ID='           ||sc_id             ||'; export '||g_mon_pref||'SC_ID;'
         ||g_mon_pref||'PL_ID='           ||pl_id             ||'; export '||g_mon_pref||'PL_ID;'
         ||g_mon_pref||'E_CODE_BASE=$'    ||e_code_base       ||'; export '||g_mon_pref||'E_CODE_BASE;'
         ||g_mon_pref||'E_FILE_NAME='     ||e_file_name       ||'; export '||g_mon_pref||'E_FILE_NAME;'
         ||g_mon_pref||'H_NAME='          ||h_name            ||'; export '||g_mon_pref||'H_NAME;'
         ||g_mon_pref||'CONNECT_STRING='  ||connect_string    ||'; export '||g_mon_pref||'CONNECT_STRING;'
         ||g_mon_pref||'SC_TNS_ALIAS='    ||sc_tns_alias      ||'; export '||g_mon_pref||'SC_TNS_ALIAS;'
         ||g_mon_pref||'SC_DB_LINK_NAME=' ||sc_db_link_name   ||'; export '||g_mon_pref||'SC_DB_LINK_NAME;'
         ||g_mon_pref||'S_NAME='          ||s_name            ||'; export '||g_mon_pref||'S_NAME;'
         ||g_mon_pref||'EA_MIN_INTERVAL=' ||ea_min_interval   ||'; export '||g_mon_pref||'EA_MIN_INTERVAL;' output
      ,  e_id
      ,  ep_id
      ,  h_id
      ,  s_id
      FROM event_assigments_v
      WHERE EA_ID=p_ea_id;
   assigment assigment_cur%ROWTYPE;
BEGIN
   OPEN assigment_cur;
   FETCH assigment_cur INTO assigment;
   CLOSE assigment_cur;
   dump_output(assigment.output);
   g_e_id := assigment.e_id;
   g_ep_id := assigment.ep_id;
   g_h_id := assigment.h_id;
   g_s_id :=assigment.s_id;
END parse_event_assigment;



-- FUNCTION hold_mail(
--    p_mh_type IN VARCHAR2,
--    p_mh_type_id IN NUMBER,
--    p_hold_reason OUT VARCHAR2)
-- RETURN BOOLEAN
-- IS
--    CURSOR mail_hold_cur IS
--       SELECT eb_id
--       ,      DECODE(eb_type,
--                 'P', 'Pager/Email Blackout',
--                 'A', 'Admin Level Blackout',
--                      'Unknown Blackout')||' '||
--              eb_code||' is active' blackout_reason
--       FROM   event_blackouts
--       WHERE  DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),
--                 '0001-01-01', TO_DATE(TO_CHAR(SYSDATE,'RRRR-MM-DD')||' '||TO_CHAR(eb_start_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
-- 				              eb_start_date) <= TRUNC(SYSDATE,'MI')
--       AND    DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),
--                 '9000-01-01', TO_DATE(TO_CHAR(SYSDATE,'RRRR-MM-DD')||' '||TO_CHAR(eb_end_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
-- 				              eb_end_date) >= TRUNC(SYSDATE,'MI')
--       AND    DECODE(eb_week_day,-1,TO_CHAR(SYSDATE,'D'),TO_CHAR(eb_week_day)) = TO_CHAR(SYSDATE,'D')
--       AND    eb_active_flag = 'Y'
--       AND    eb_type = p_mh_type
--       AND    eb_type_id = p_mh_type_id;
--    mail_hold mail_hold_cur%ROWTYPE;
--    l_return_value BOOLEAN;
--    l_hold_reason VARCHAR2(100);
-- BEGIN
--    OPEN mail_hold_cur;
--    FETCH mail_hold_cur INTO mail_hold;
--    IF mail_hold_cur%FOUND THEN
--       CLOSE mail_hold_cur;
--       l_return_value := TRUE;
--       l_hold_reason := mail_hold.blackout_reason;
--    ELSE
--       CLOSE mail_hold_cur;
--       l_return_value := FALSE;
--       l_hold_reason := NULL;
--    END IF;
--
--    p_hold_reason := l_hold_reason;
--    RETURN l_return_value;
-- END hold_mail;
--


FUNCTION hold_exists(
   p_ea_id IN NUMBER,
   p_eh_type IN VARCHAR2,
   p_eh_type_id IN NUMBER,
   p_hold_reason OUT VARCHAR)
RETURN BOOLEAN
IS
   CURSOR event_holds_cur IS
      SELECT eh_id
      ,      DECODE(eh_type,
                'H', 'Host Level Hold',
                'S', 'Sid Level Hold',
                'E', 'Event Level Hold',
                     'Unknown Hold')||' Set by '||
             DECODE(eh_set_by_type,
                'E', 'Event',
                     'Unknown')||' '||
             eh_set_by_id||' On '||
             TO_CHAR(eh_set_date,'RRRR-MON-DD HH24:MI:SS') hold_reason
      FROM   event_holds
      WHERE  eh_type = p_eh_type
      AND    eh_type_id = p_eh_type_id
      AND    DECODE(eh_set_by_type,'E',eh_set_by_id,-1) != p_ea_id;

    event_holds event_holds_cur%ROWTYPE;

--    CURSOR event_blackouts_cur IS
--       SELECT eb_id
--       ,      DECODE(eb_type,
--                 'H', 'Host Level Blackout',
--                 'S', 'Sid Level Blackout',
--                 'E', 'Event Level Blackout',
--                 'X', 'Event Assigment Level Blackout',
--                      'Unknown Blackout')||' '||
--              eb_code||' is active' blackout_reason
--          FROM   event_blackouts
--          WHERE  DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),
--                    '0001-01-01', TO_DATE(TO_CHAR(SYSDATE,'RRRR-MM-DD')||' '||TO_CHAR(eb_start_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
-- 		                 eb_start_date) <= TRUNC(SYSDATE,'MI')
--          AND    DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),
--                    '9000-01-01', TO_DATE(TO_CHAR(SYSDATE,'RRRR-MM-DD')||' '||TO_CHAR(eb_end_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
-- 	                         eb_end_date) >= TRUNC(SYSDATE,'MI')
--          AND    DECODE(eb_week_day,-1,TO_CHAR(SYSDATE,'D'),TO_CHAR(eb_week_day)) = TO_CHAR(SYSDATE,'D')
--          AND    eb_active_flag = 'Y'
--          AND    eb_type = p_eh_type
--          AND    eb_type_id = p_eh_type_id;
--

--    event_blackouts event_blackouts_cur%ROWTYPE;

   l_hold_reason VARCHAR2(256);
   l_return_value BOOLEAN;
BEGIN
   -- check for holds
   dbms_output.put_line('check for holds');
   OPEN event_holds_cur;
   FETCH event_holds_cur INTO event_holds;
   IF event_holds_cur%FOUND THEN
      dbms_output.put_line('holds found');
      CLOSE event_holds_cur;
      l_return_value := TRUE;
      l_hold_reason := event_holds.hold_reason;
   ELSE
      dbms_output.put_line('holds NOT found');
      CLOSE event_holds_cur;
      l_return_value := FALSE;
      l_hold_reason := NULL;
   END IF;

   IF NOT l_return_value THEN
      -- check for blackouts
      IF glob_util_pkg.active_blackout(
            p_bl_type => p_eh_type,
            p_bl_type_id => p_eh_type_id,
            p_bl_reason => l_hold_reason) THEN

         l_return_value := TRUE;
      ELSE
         l_return_value := FALSE;
         l_hold_reason := NULL;
      END IF;

      -- OPEN event_blackouts_cur;
      -- FETCH event_blackouts_cur INTO event_blackouts;
      -- IF event_blackouts_cur%FOUND THEN
      --    CLOSE event_blackouts_cur;
      --    l_return_value := TRUE;
      --    l_hold_reason := event_blackouts.blackout_reason;
      -- ELSE
      --    CLOSE event_blackouts_cur;
      --    l_return_value := FALSE;
      --    l_hold_reason := NULL;
      -- END IF;
   END IF;

   p_hold_reason := l_hold_reason;
   RETURN l_return_value;
END hold_exists;


FUNCTION event_on_hold(
   p_ea_id IN NUMBER,
   p_e_id IN NUMBER,
   p_h_id IN NUMBER,
   p_s_id IN NUMBER DEFAULT -1,
   p_hold_reason OUT VARCHAR2)
RETURN BOOLEAN
IS
   l_hold_reason VARCHAR2(256);
   l_return_value BOOLEAN;
BEGIN
   -- EA level
   IF hold_exists(
         p_ea_id => p_ea_id,
         p_eh_type => 'X',
         p_eh_type_id => p_ea_id,
         p_hold_reason => l_hold_reason) THEN
      l_return_value := TRUE;

   -- E level (exluding if set by this EA)
   ELSIF hold_exists(
         p_ea_id => p_ea_id,
         p_eh_type => 'E',
         p_eh_type_id => p_e_id,
         p_hold_reason => l_hold_reason) THEN
      l_return_value := TRUE;

   -- Host level
   ELSIF hold_exists(
            p_ea_id => p_ea_id,
            p_eh_type => 'H',
            p_eh_type_id => p_h_id,
            p_hold_reason => l_hold_reason) THEN
      l_return_value := TRUE;

   -- Sid level
   ELSIF hold_exists(
            p_ea_id => p_ea_id,
            p_eh_type => 'S',
            p_eh_type_id => p_s_id,
            p_hold_reason => l_hold_reason) THEN
      l_return_value := TRUE;
   ELSE
      l_return_value := FALSE;
      l_hold_reason := NULL;
   END IF;
   p_hold_reason := l_hold_reason;
   RETURN l_return_value;
END event_on_hold;


PROCEDURE parse_last_event_trigger(p_ea_id IN NUMBER)
IS
   CURSOR last_trig_cur IS
      SELECT et_id
      ,      et_status
      ,      DECODE(et_status,'CLEARED',NULL,et_orig_et_id) et_orig_et_id
      FROM event_triggers
      WHERE et_id = (SELECT MAX(et_id) max_et_id
                     FROM event_triggers
                     WHERE ea_id=p_ea_id);
   last_trig last_trig_cur%ROWTYPE;
BEGIN
   OPEN last_trig_cur;
   FETCH last_trig_cur INTO last_trig;
   CLOSE last_trig_cur;
   dump_output('export '||g_der_pref||'last_et_id='||last_trig.et_id||';');
   dump_output('export '||g_der_pref||'last_sev_level='||last_trig.et_status||';');
   dump_output('export '||g_der_pref||'last_et_orig_et_id='||last_trig.et_orig_et_id||';');
END parse_last_event_trigger;


PROCEDURE parse_event_parameters(
   p_e_id IN NUMBER
,  p_ep_id IN NUMBER)
IS
   l_ep_holdl event_parameters.ep_hold_level%TYPE;
   l_ep_code  event_parameters.ep_code%TYPE;
   l_cp_code  coll_parameters.cp_code%TYPE;
BEGIN
   FOR epv IN (SELECT epv_name||'="'||epv_value||'"' param
               FROM event_parameter_values
               WHERE ep_id=p_ep_id
               AND   e_id=p_e_id
               AND   epv_status='A')
   LOOP
      dump_output('export '||g_par_pref||epv.param||';');
   END LOOP;

   SELECT ep_hold_level, ep_code, cp_code
   INTO l_ep_holdl, l_ep_code, l_cp_code
   FROM (SELECT ep_hold_level
         ,      ep_code
         ,      cp_code
         FROM   event_parameters ep
         ,      coll_parameters cp
         WHERE  ep_id = p_ep_id
         AND    e_id =p_e_id
         AND    ep.ep_coll_cp_id = cp.cp_id(+))
   WHERE ROWNUM = 1;

   dump_output('export '||g_par_pref||'ep_hold_level='||l_ep_holdl||';');
   dump_output('export '||g_par_pref||'ep_code="'||l_ep_code||'";');
   dump_output('export '||g_par_pref||'cp_code="'||l_cp_code||'";');
END parse_event_parameters;



PROCEDURE place_event_hold(
  p_ep_hold_level   IN VARCHAR2  ,
  p_e_id            IN NUMBER    ,
  p_s_id            IN NUMBER    ,
  p_h_id            IN NUMBER    ,
  p_ea_id           IN NUMBER    )
IS
BEGIN
  INSERT INTO event_holds(
     eh_id           ,
     date_created    ,
     date_modified   ,
     modified_by     ,
     created_by      ,
     eh_type         ,
     eh_type_id      ,
     eh_set_by_type  ,
     eh_set_by_id    ,
     eh_set_date     ,
     eh_hold_desc    )
  SELECT
     event_holds_s.NEXTVAL,
     SYSDATE,
     NULL,
     NULL,
     'EVENT_TRIGGER',
     p_ep_hold_level,
     DECODE(p_ep_hold_level,
        'E',p_e_id,
        'S',p_s_id,
        'H',p_h_id),
     'E',            /* E => Set By Event */
     p_ea_id ,
     SYSDATE,
     'event system generated hold'
  FROM dual;
EXCEPTION
   WHEN DUP_VAL_ON_INDEX THEN
      -- just OK
      null;
END place_event_hold;


PROCEDURE release_event_hold(p_ea_id IN NUMBER)
IS
BEGIN
   DELETE event_holds
   WHERE  eh_set_by_type = 'E'
   AND    eh_set_by_id = p_ea_id;
END release_event_hold;


/* public modules */

PROCEDURE set_event_env(p_ea_id IN NUMBER, p_out_ref_id OUT NUMBER)
IS
   l_continue      VARCHAR2(3);
   l_hold_reason   VARCHAR2(256);
BEGIN
   g_out_ref_id := get_next_ref_id;
   g_out_ref_type := set_event_env_out_code;

   -- load vars from event_assigments table
   -- this proc will set these globals:
   -- 	g_e_id
   --	g_ep_id
   --   g_h_id
   --   g_s_id
   --
   -- and dump output
   --
   parse_event_assigment(p_ea_id);

   IF g_e_id IS NOT NULL THEN

      IF event_on_hold(
            p_ea_id => p_ea_id,
            p_e_id => g_e_id,
            p_h_id => g_h_id,
            p_s_id => g_s_id,
            p_hold_reason => l_hold_reason)  THEN
         l_continue := 'NO';
      ELSE
         l_continue := 'YES';
      END IF;

   ELSE
      l_continue := 'NO';
      l_hold_reason := 'Inactive or Invalid Event Assigment';
   END IF;


   dump_output('export '||g_der_pref||'CONTINUE='||l_continue||';');
   dump_output('export '||g_der_pref||'HOLD_REASON="'||l_hold_reason||'";');

   IF l_continue = 'YES' THEN
      parse_last_event_trigger(p_ea_id);
      parse_event_parameters(g_e_id, g_ep_id);
   END IF;

   --commit;

   p_out_ref_id := g_out_ref_id;
END set_event_env;


PROCEDURE get_event_output(p_et_id IN NUMBER, p_out_ref_id OUT NUMBER)
IS
   CURSOR out_line_cur IS
      SELECT
        etd_attribute1    ||DECODE(etd_attribute2 ,NULL,NULL,',')||
        etd_attribute2    ||DECODE(etd_attribute3 ,NULL,NULL,',')||
        etd_attribute3    ||DECODE(etd_attribute4 ,NULL,NULL,',')||
        etd_attribute4    ||DECODE(etd_attribute5 ,NULL,NULL,',')||
        etd_attribute5    ||DECODE(etd_attribute6 ,NULL,NULL,',')||
        etd_attribute6    ||DECODE(etd_attribute7 ,NULL,NULL,',')||
        etd_attribute7    ||DECODE(etd_attribute8 ,NULL,NULL,',')||
        etd_attribute8    ||DECODE(etd_attribute9 ,NULL,NULL,',')||
        etd_attribute9    ||DECODE(etd_attribute10,NULL,NULL,',')||
        etd_attribute10   ||DECODE(etd_attribute11,NULL,NULL,',')||
        etd_attribute11   ||DECODE(etd_attribute12,NULL,NULL,',')||
        etd_attribute12   ||DECODE(etd_attribute13,NULL,NULL,',')||
        etd_attribute13   ||DECODE(etd_attribute14,NULL,NULL,',')||
        etd_attribute14   ||DECODE(etd_attribute15,NULL,NULL,',')||
        etd_attribute15   ||DECODE(etd_attribute16,NULL,NULL,',')||
        etd_attribute16   ||DECODE(etd_attribute17,NULL,NULL,',')||
        etd_attribute17   ||DECODE(etd_attribute18,NULL,NULL,',')||
        etd_attribute18   ||DECODE(etd_attribute19,NULL,NULL,',')||
        etd_attribute19   ||DECODE(etd_attribute20,NULL,NULL,',')||
        etd_attribute20   output
      FROM event_trigger_details
      WHERE et_id=p_et_id
      AND   etd_status != 'CLEARED'
      ORDER BY etd_id;
BEGIN
   g_out_ref_id := get_next_ref_id;
   g_out_ref_type := get_event_output_out_code;

   FOR out_line IN out_line_cur LOOP
      dump_output(out_line.output);
   END LOOP;
   --commit;

   p_out_ref_id := g_out_ref_id;
END get_event_output;



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
  p_et_attribute20             IN VARCHAR2 DEFAULT NULL)
IS
   l_et_id event_triggers.et_id%TYPE;
   l_ET_ACK_FLAG event_triggers.ET_ACK_FLAG%TYPE DEFAULT 'N';
BEGIN

   -- set PHASE_STATUS to OLD if new is NOT CLEARED
   -- on all triggers that have same p_ET_ORIG_ET_ID
   -- this ensures that only the latest trigger is pending
   -- I do this before the trigger is inserted to make sure
   -- new trigger is not updated
   IF p_ET_ORIG_ET_ID IS NOT NULL AND
      p_et_status != 'CLEARED'    THEN
      UPDATE event_triggers
      SET et_phase_status = 'O'
      ,   MODIFIED_BY = 'EVENT_TRIGGER'
      ,   DATE_MODIFIED = SYSDATE
      WHERE et_orig_et_id = p_ET_ORIG_ET_ID;
   END IF;


   /*
    * get acknowledgement flag for page list;
    * acknowledgement is only required FOR the first
    * trigger occurence (p_ET_ORIG_ET_ID IS NULL)
    * see below INSERT ...
    */

   SELECT pl_ack_required
   INTO l_ET_ACK_FLAG
   FROM page_lists
   WHERE pl_id = p_pl_id;

   SELECT event_triggers_s.nextval
   INTO   l_et_id
   FROM   dual;

   /*
    * The following rule is used for setting
    * notification flag (ET_MAIL_STATUS)
    * ---------------------------------------
    *    ET_MAIL_STATUS='P' (pending)
    *       1) first event trigger (p_ET_ORIG_ET_ID IS NULL)
    *
    *       2) subsequent trigger and acknowledgement is not
    *          required (p_ET_ORIG_ET_ID IS NOT NULL AND
    *          l_ET_ACK_FLAG='N')
    *
    *    ET_MAIL_STATUS='X' (suppressed)
    *       1) subsequent trigger and acknowledgement is required
    *          (p_ET_ORIG_ET_ID IS NOT NULL AND l_ET_ACK_FLAG='Y')
    *
    * This rule is in place to avoid subsequent and "CLEARED" pages
    * for event triggers that require acknowledgement.  These are the
    * types of triggers that occur in the middle of the night and you
    * are forced to getup, acknowledge, fix them then go back to sleep
    * and don't care when the trigger get's cleared you just want to
    * go to sleep ...  Guess how I came up with this rule ? :-)
    */
   INSERT INTO event_triggers(
     et_id                      ,
     ea_id                      ,
     pl_id                      ,
     e_id                       ,
     h_id                       ,
     s_id                       ,
     sc_id                      ,
     date_created               ,
     created_by                 ,
     et_trigger_time            ,
     et_status                  ,
     ET_ORIG_ET_ID              ,
     et_prev_et_id              ,
     et_prev_status             ,
     et_attribute1              ,
     et_attribute2              ,
     et_attribute3              ,
     et_attribute4              ,
     et_attribute5              ,
     et_attribute6              ,
     et_attribute7              ,
     et_attribute8              ,
     et_attribute9              ,
     et_attribute10             ,
     et_attribute11             ,
     et_attribute12             ,
     et_attribute13             ,
     et_attribute14             ,
     et_attribute15             ,
     et_attribute17             ,
     et_attribute18             ,
     et_attribute19             ,
     et_attribute20             ,
     ET_ACK_FLAG                ,
     ET_MAIL_STATUS             )
   VALUES(
     l_et_id                      ,
     p_ea_id                      ,
     p_pl_id                      ,
     p_e_id                       ,
     p_h_id                       ,
     p_s_id                       ,
     p_sc_id                      ,
     p_date_created               ,
     p_created_by                 ,
     p_et_trigger_time            ,
     p_et_status                  ,
     NVL(p_ET_ORIG_ET_ID,l_et_id) ,
     p_et_prev_et_id              ,
     p_et_prev_status             ,
     p_et_attribute1              ,
     p_et_attribute2              ,
     p_et_attribute3              ,
     p_et_attribute4              ,
     p_et_attribute5              ,
     p_et_attribute6              ,
     p_et_attribute7              ,
     p_et_attribute8              ,
     p_et_attribute9              ,
     p_et_attribute10             ,
     p_et_attribute11             ,
     p_et_attribute12             ,
     p_et_attribute13             ,
     p_et_attribute14             ,
     p_et_attribute15             ,
     p_et_attribute17             ,
     p_et_attribute18             ,
     p_et_attribute19             ,
     p_et_attribute20             ,
     DECODE(p_ET_ORIG_ET_ID,
        NULL,l_ET_ACK_FLAG,'N')   ,
     DECODE(p_ET_ORIG_ET_ID,
        NULL,'P'
            ,DECODE(l_ET_ACK_FLAG,
                'N','P',
                'Y','X'
                   ,'P')
            )                     );

   -- process holds
   IF p_ep_hold_level IS NOT NULL AND
      p_et_status != 'CLEARED'    THEN

      place_event_hold(
        p_ep_hold_level => p_ep_hold_level,
        p_e_id => p_e_id,
        p_s_id => p_s_id,
        p_h_id => p_h_id,
        p_ea_id => p_ea_id) ;

   ELSIF p_et_status = 'CLEARED' THEN

      -- release hold even if p_ep_hold_level IS NULL
      -- since it could've been changed after the hold
      -- is placed.  Release is done by p_ea_id
      -- This implies that hold can only be released
      -- by same EVENT ASSIGMENT
      --
      release_event_hold(p_ea_id);
   END IF;

   -- set PHASE_STATUS to COMPLETE if CLEARED
   -- on all triggers that have same p_ET_ORIG_ET_ID
   --
   IF p_ET_ORIG_ET_ID IS NOT NULL AND
      p_et_status = 'CLEARED'     THEN
      UPDATE event_triggers
      SET et_phase_status = 'C'
      ,   et_clr_et_id = l_et_id
      ,   MODIFIED_BY = 'EVENT_TRIGGER'
      ,   DATE_MODIFIED = SYSDATE
      WHERE et_orig_et_id = p_ET_ORIG_ET_ID;
   END IF;

   p_et_id := l_et_id;

END insert_trigger_header;


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
  p_etd_attribute20   IN VARCHAR2 DEFAULT NULL)
IS
BEGIN
   INSERT INTO event_trigger_details(
      etd_id            ,
      et_id             ,
      date_created      ,
      created_by        ,
      etd_trigger_time  ,
      etd_status        ,
      etd_attribute1    ,
      etd_attribute2    ,
      etd_attribute3    ,
      etd_attribute4    ,
      etd_attribute5    ,
      etd_attribute6    ,
      etd_attribute7    ,
      etd_attribute8    ,
      etd_attribute9    ,
      etd_attribute10   ,
      etd_attribute11   ,
      etd_attribute12   ,
      etd_attribute13   ,
      etd_attribute14   ,
      etd_attribute15   ,
      etd_attribute16   ,
      etd_attribute17   ,
      etd_attribute18   ,
      etd_attribute19   ,
      etd_attribute20   )
   VALUES(
      event_trigger_details_s.NEXTVAL,
      p_et_id             ,
      p_date_created      ,
      p_created_by        ,
      p_etd_trigger_time  ,
      p_etd_status        ,
      p_etd_attribute1    ,
      p_etd_attribute2    ,
      p_etd_attribute3    ,
      p_etd_attribute4    ,
      p_etd_attribute5    ,
      p_etd_attribute6    ,
      p_etd_attribute7    ,
      p_etd_attribute8    ,
      p_etd_attribute9    ,
      p_etd_attribute10   ,
      p_etd_attribute11   ,
      p_etd_attribute12   ,
      p_etd_attribute13   ,
      p_etd_attribute14   ,
      p_etd_attribute15   ,
      p_etd_attribute16   ,
      p_etd_attribute17   ,
      p_etd_attribute18   ,
      p_etd_attribute19   ,
      p_etd_attribute20   );
END insert_trigger_detail;


PROCEDURE insert_trigger_output(
  p_et_id             IN NUMBER ,
  p_date_created      IN DATE,
  p_created_by        IN VARCHAR2 ,
  p_eto_output_line   IN VARCHAR2 DEFAULT NULL)
IS
BEGIN
   INSERT INTO event_trigger_output(
      eto_id           ,
      date_created     ,
      et_id            ,
      date_modified    ,
      modified_by      ,
      created_by       ,
      eto_output_line  )
   VALUES(
      event_trigger_output_S.NEXTVAL,
      p_date_created,
      p_et_id,
      NULL,
      NULL,
      p_created_by,
      p_eto_output_line);
END insert_trigger_output;


PROCEDURE get_pending_mail(
   p_ack_notif_freq IN NUMBER
,  p_ack_notif_tres IN NUMBER
,  p_out_ref_id     OUT NUMBER)
IS
   CURSOR peng_trig_cur IS
      SELECT /*+ ORDERED USE_NL(ea) */
              'export MAIL_ET_ID='||     et_id
      ||';'|| 'export MAIL_PL_ID='||     et.pl_id
      ||';'|| 'export MAIL_EP_ID='||     ea.ep_id
      ||';'|| 'export MAIL_STATUS="'||   NVL(et_attribute2,et_attribute1)||'-'||DECODE(et_status,'CLEARED',et_status||' '||et_prev_status,et_status)||'"'
      ||';'|| 'export MAIL_DONE_BY="'||  '$MON_TOP'||substr(et.et_attribute4,instr(et.et_attribute4,'/mon/evnt',-1)+4)||'"'
      ||';'|| 'export MAIL_TRG_TIME="'|| TO_CHAR(et_trigger_time,'MON-DD HH24:MI:SS')||'"'
      ||';'|| 'export MAIL_HOST="'||     et_attribute1||'"'
      ||';'|| 'export MAIL_SID="'||      et_attribute2||'"'
      ||';'|| 'export MAIL_ACK="'||      DECODE(et_ack_flag,'Y','Yes','N','No')||'"'
      ||';'|| 'export MAIL_FNSHORT='||   et_id||'.MAIL_FNSHORT.mail'
      ||';'|| 'export MAIL_FNLONG='||    et_id||'.MAIL_FNLONG.mail'
      ||';'|| '$mail_grp_sub $mail_list_file'  output_line,
              et.pl_id             pl_id,
              et_id||'.MAIL_FNSHORT.mail' short_file,
              et_id||'.MAIL_FNLONG.mail'  long_file,
              et_id,
              DECODE(et_mail_status,
                 /* only if second pass et_mail_status != 'P' */
                 'P','NO'
                    ,DECODE(et_ack_flag,
                        /* only if ack=Y */
                        'N','NO'
                           ,DECODE(et_ack_date,
                               /* only if et_ack_date IS NULL */
                               NULL,DECODE(SIGN(SYSDATE - (et_trigger_time + (p_ack_notif_freq*1/24/60))),
                                       /* and it hasn't been acknowledged
                                        * for over VALUE(p_ack_notif_freq)
                                        * minutes
                                        */
                                       1,'YES'
                                        ,'NO'
                                    )
                                   ,'NO'
                            )
                     )
              ) sec_flag
      FROM event_triggers et
      ,    event_assigments ea
      WHERE (et_mail_status='P'
            /*
             * first pass will page PRIMARY
             * since the et_mail_status will be 'P'
             *
             * if event is not acknowledged after
             * 15 minutes the BACKUP(Secondary) admins
             * are paged
             */
            OR (et_ack_flag='Y'
                AND et_ack_date IS NULL
                AND SYSDATE >= (et_trigger_time + (p_ack_notif_freq*1/24/60))
                /*
                 * this ensures that we don't get paged
                 * for acknowledgments every time
                 * mail subsystem is running only once in
                 * VALUE(p_ack_notif_freq) minutes
                 */
                AND SYSDATE >= (SELECT MAX(etn_date) +
                                       (p_ack_notif_freq*1/24/60)
                                FROM event_trigger_notif sn
                                WHERE sn.et_id = et.et_id)
               )
            )
      AND   et.ea_id = ea.ea_id
      ORDER BY et_trigger_time;

   CURSOR page_list_cur(p_pl_id      IN NUMBER,
                        p_short_file IN VARCHAR2,
                        p_long_file  IN VARCHAR2) IS
      SELECT /*+ ORDERED */
              a.a_name
      ||','|| ae.ae_email
      ||','|| DECODE(ae.ae_append_logfile,'Y',p_long_file,p_short_file)
      ||','|| pld.a_id
      ||','|| pld.ae_id
      ||','|| 'P' /* primary */  output_line
      ,       pld.a_id
      ,       pld.ae_id
      FROM page_list_definitions pld
      ,    admin_emails ae
      ,    admins a
      WHERE pld.ae_id = ae.ae_id
      AND   pld.a_id = ae.a_id
      AND   pld.a_id = a.a_id
      AND   pld.pld_status='A'
      AND   pld.pl_id = p_pl_id;

   CURSOR sec_page_list_cur(p_a_id IN NUMBER,
                            p_short_file IN VARCHAR2,
                            p_long_file  IN VARCHAR2) IS
      SELECT /*+ RULE */
              a.a_name||'[backup_for('||pa.a_name||')]'
      ||','|| ae.ae_email
      ||','|| DECODE(ae.ae_append_logfile,'Y',p_long_file,p_short_file)
      ||','|| ab.backup_a_id
      ||','|| ab.backup_ae_id
      ||','|| 'S' /* secondary */  output_line
      ,       ab.backup_a_id a_id
      ,       ab.backup_ae_id ae_id
      FROM admin_backups ab
      ,    admin_emails ae
      ,    admins a
      ,    admins pa
      WHERE ab.backup_a_id = ae.a_id
      AND   ab.backup_ae_id = ae.ae_id
      AND   ae.a_id = a.a_id
      AND   ab.primary_a_id = pa.a_id
      AND   ab.primary_a_id = p_a_id;

   CURSOR pnotif_cnt_cur(p_et_id IN NUMBER,
                         p_a_id IN NUMBER,
                         p_ae_id IN NUMBER) IS
      SELECT COUNT(etn_id)
      FROM event_trigger_notif
      WHERE et_id = p_et_id
      AND   a_id = p_a_id
      AND   ae_id = p_ae_id
      HAVING COUNT(etn_id) >= p_ack_notif_tres;
   pnotif_cnt pnotif_cnt_cur%ROWTYPE;

   l_hold_reason  VARCHAR2(100);
   PAGE_SECONDARY BOOLEAN DEFAULT FALSE;

BEGIN
   g_out_ref_id := get_next_ref_id;

   g_out_ref_type := get_pending_mail_out_code_trg;
   dump_output('#!/bin/ksh');

   FOR peng_trig IN peng_trig_cur LOOP
      g_out_ref_type := get_pending_mail_out_code_trg;
      dump_output(peng_trig.output_line);
      FOR page_list IN page_list_cur(peng_trig.pl_id,
                                     peng_trig.short_file,
                                     peng_trig.long_file)
      LOOP

         -- process PRIMARY blackouts
         --
         IF glob_util_pkg.active_blackout(
               p_bl_type => 'A',
               p_bl_type_id => page_list.a_id,
               p_bl_reason => l_hold_reason) THEN

            -- hold this mail
            g_out_ref_type := get_pending_mail_out_code_pgl||'_HOLD' ;
            dump_output(page_list.output_line||','||l_hold_reason);

         ELSIF glob_util_pkg.active_blackout(
                  p_bl_type => 'P',
                  p_bl_type_id => page_list.ae_id,
                  p_bl_reason => l_hold_reason) THEN

            -- hold this mail
            g_out_ref_type := get_pending_mail_out_code_pgl||'_HOLD' ;
            dump_output(page_list.output_line||','||l_hold_reason);

         ELSE
            -- process this mail
            g_out_ref_type := get_pending_mail_out_code_pgl ;
            dump_output(page_list.output_line);
         END IF;


         -- check for SECONDARY emails
         --
         IF peng_trig.sec_flag = 'YES' THEN
            -- check if PRIMARY has been
            -- paged enough times >= p_ack_notif_tres
            --
            OPEN pnotif_cnt_cur(peng_trig.et_id,
                                page_list.a_id,
                                page_list.ae_id);
            FETCH pnotif_cnt_cur INTO pnotif_cnt;
            IF pnotif_cnt_cur%FOUND THEN
               CLOSE pnotif_cnt_cur;
               PAGE_SECONDARY := TRUE;
            ELSE
               CLOSE pnotif_cnt_cur;
               PAGE_SECONDARY := FALSE;
            END IF;
         END IF;


         IF PAGE_SECONDARY THEN
            FOR sec_page_list IN sec_page_list_cur(page_list.a_id,
                                                   peng_trig.short_file,
                                                   peng_trig.long_file)
            LOOP
               -- process SECONDARY blackouts
               --
               IF glob_util_pkg.active_blackout(
                     p_bl_type => 'A',
                     p_bl_type_id => sec_page_list.a_id,
                     p_bl_reason => l_hold_reason) THEN

                  -- hold this mail
                  g_out_ref_type := get_pending_mail_out_code_pgl||'_HOLD' ;
                  dump_output(sec_page_list.output_line||','||l_hold_reason);

               ELSIF glob_util_pkg.active_blackout(
                        p_bl_type => 'P',
                        p_bl_type_id => sec_page_list.ae_id,
                        p_bl_reason => l_hold_reason) THEN

                  -- hold this mail
                  g_out_ref_type := get_pending_mail_out_code_pgl||'_HOLD' ;
                  dump_output(sec_page_list.output_line||','||l_hold_reason);

               ELSE
                  -- process this mail
                  g_out_ref_type := get_pending_mail_out_code_pgl ;
                  dump_output(sec_page_list.output_line);
               END IF;

            -- SECONDARY LOOP
            END LOOP;
         -- PAGE_SECONDARY IF
         END IF;

         -- turn the flag OFF
         PAGE_SECONDARY := FALSE;

      -- PRIMARY LOOP
      END LOOP;

   -- PENDING TRIGGERS LOOP
   END LOOP;

   p_out_ref_id := g_out_ref_id;
END get_pending_mail;


PROCEDURE ctrl(
   p_ea_id IN NUMBER
,  p_stage IN VARCHAR2)
IS
   CURSOR restart_cur IS
      SELECT ea_id
      ,      (ea_min_interval * 1/24/60) +
             NVL(ea_started_time,SYSDATE) ntime
      ,      TRUNC(((NVL(ea_finished_time,SYSDATE)-NVL(ea_started_time,SYSDATE))/(1/24))*60*60) runt_sec
      FROM event_assigments
      WHERE ea_id = p_ea_id;

   restart restart_cur%ROWTYPE;
BEGIN
   IF p_stage = 'COMPLETE' THEN
      OPEN restart_cur;
      FETCH restart_cur INTO restart;
      CLOSE restart_cur;

      -- set the complete time/flag
      -- as well as handle reschedule
      UPDATE event_assigments
      SET ea_status = 'A'
      ,   ea_finished_time = SYSDATE
      ,   ea_started_time = NULL
      ,   ea_start_time = restart.ntime
      ,   ea_last_runtime_sec = restart.runt_sec
      --,   modified_by = 'INTERNAL'
      --,   date_modified = SYSDATE
      WHERE ea_id = restart.ea_id;
   -- << END COMPLETE PHASE

   ELSIF p_stage = 'RUNNING' THEN
      -- set the running time/flag
      UPDATE event_assigments
      SET ea_status = 'R'
      ,   ea_finished_time = NULL
      ,   ea_started_time = SYSDATE
      --,   modified_by = 'INTERNAL'
      --,   date_modified = SYSDATE
      WHERE ea_id = p_ea_id;
   -- << END RUNNING PHASE

   ELSIF p_stage = 'ERROR' THEN
      OPEN restart_cur;
      FETCH restart_cur INTO restart;
      CLOSE restart_cur;

      -- set the broken time/flag
      -- as well as handle reschedule
      -- NOTE
      -- ======
      -- BROKEN events continue to run
      -- but the sysadmin doesn't get
      -- notification with repeaded errors
      -- this is to make sure that events
      -- eventually run after system failures
      --
      UPDATE event_assigments
      SET ea_status = 'B'
      ,   ea_finished_time = SYSDATE
      ,   ea_started_time = NULL
      ,   ea_start_time = restart.ntime
      ,   ea_last_runtime_sec = restart.runt_sec
      --,   modified_by = 'INTERNAL'
      --,   date_modified = SYSDATE
      WHERE ea_id = restart.ea_id;
   -- << END ERROR PHASE

   END IF;
END ctrl;


-- build summary of trigger stats by ea_id
--
procedure refresh_event_triggers_sum
is
begin
    delete event_triggers_sum;
    insert /*+ parallel (t,8)*/
      into event_triggers_sum t
    select /*+ parallel (s,8)*/
           s.ea_id, count(1), s.et_phase_status
      from event_triggers s
     where s.et_status != 'CLEARED'
     group by s.ea_id, s.et_phase_status;
end refresh_event_triggers_sum;


-- new purge procedure
-- I've gotten really tired of post_coll_purge/post_coll_mark failures
-- due to dead locks on underlying tables so I collapsed everything here
-- into one hopefully simple pkg which I'll just run as dbms_job
--
procedure purge_obsolete
is
begin
   delete purge_et_id_tmp;

   insert into purge_et_id_tmp
   select et.et_id
   from event_triggers et
   ,    event_assigments ea
   where et.ea_id = ea.ea_id
   and et_phase_status != 'P'
   and et.et_trigger_time <= trunc((sysdate - ea.ea_purge_freq))
   and ea.ea_purge_freq != -1;

   delete event_trigger_notif x where exists (select 1 from purge_et_id_tmp d where x.et_id = d.et_id);
   delete event_trigger_notes x where exists (select 1 from purge_et_id_tmp d where x.et_id = d.et_id);
   delete event_trigger_output x where exists (select 1 from purge_et_id_tmp d where x.et_id = d.et_id);
   delete event_trigger_details x where exists (select 1 from purge_et_id_tmp d where x.et_id = d.et_id);
   delete event_triggers x where exists (select 1 from purge_et_id_tmp d where x.et_id = d.et_id);

   delete coll_snap_history where csh_status = 'O';

end purge_obsolete;


PROCEDURE post_coll_purge(
   p_driver_table IN VARCHAR2
,  p_db_link IN VARCHAR2)
IS
   l_sql VARCHAR2(4000);
BEGIN
   -- I don't use p_db_link link here
   -- since DELETE is on the local database
   --
   l_sql := 'DELETE event_trigger_notif WHERE et_id IN (SELECT DISTINCT et_id FROM '||p_driver_table||')';

   EXECUTE IMMEDIATE l_sql;

   l_sql := 'DELETE event_trigger_notes WHERE et_id IN (SELECT DISTINCT et_id FROM '||p_driver_table||')';

   EXECUTE IMMEDIATE l_sql;

   l_sql := 'DELETE event_trigger_output WHERE et_id IN (SELECT DISTINCT et_id FROM '||p_driver_table||')';

   EXECUTE IMMEDIATE l_sql;

   l_sql := 'DELETE event_trigger_details WHERE et_id IN (SELECT DISTINCT et_id FROM '||p_driver_table||')';

   EXECUTE IMMEDIATE l_sql;

   l_sql := 'DELETE event_triggers WHERE et_id IN (SELECT DISTINCT et_id FROM '||p_driver_table||')';

   EXECUTE IMMEDIATE l_sql;
END post_coll_purge;



PROCEDURE post_coll_mark(
   p_driver_table IN VARCHAR2
,  p_db_link IN VARCHAR2)
IS
   l_sql VARCHAR2(4000);

BEGIN
   l_sql := 'UPDATE event_triggers '||
            'SET et_purge_ready = ''Y'' '||
            'WHERE et_id IN (SELECT et_id FROM '||p_driver_table||')';

   EXECUTE IMMEDIATE l_sql;
END post_coll_mark;

PROCEDURE reset(
   p_rhost  IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR local_cur IS
      SELECT ea_id
      FROM event_assigments
      WHERE ea_status IN ('R','l')
      AND e_id IN (select e_id
                   from events
                   where e_code_base NOT LIKE '*%')
      FOR UPDATE OF ea_id NOWAIT;

   CURSOR remote_cur IS
      SELECT ea_id
      FROM event_assigments
      WHERE ea_status IN ('R','r')
      AND e_id IN (select e_id
                   from events
                   where e_code_base LIKE '*%')
      AND h_id = (select h_id
                  from hosts
                  where h_name = p_rhost)
      FOR UPDATE OF ea_id NOWAIT;
BEGIN
   IF p_rhost IS NOT NULL THEN
      FOR remote IN remote_cur LOOP
         dbms_output.put_line('RESETTING REMOTE ea_id='||remote.ea_id);
         UPDATE event_assigments
         SET ea_status = 'A'
         WHERE CURRENT OF remote_cur;
      END LOOP;
   ELSE
      FOR local IN local_cur LOOP
         dbms_output.put_line('RESETTING LOCAL ea_id='||local.ea_id);
         UPDATE event_assigments
         SET ea_status = 'A'
         WHERE CURRENT OF local_cur;
      END LOOP;
   END IF;
END reset;


PROCEDURE mail_ctrl(
   p_et_id  IN NUMBER
,  p_a_id   IN NUMBER DEFAULT NULL
,  p_ae_id  IN NUMBER DEFAULT NULL
,  p_type   IN VARCHAR2
,  p_status IN VARCHAR2)
IS
BEGIN

   -- if trigger type
   -- then just update event_triggers
   --
   IF p_type = 'T' THEN
      UPDATE event_triggers
      SET et_mail_status=UPPER(p_status)
      WHERE et_id = p_et_id;

   ELSE
      INSERT INTO event_trigger_notif(
         etn_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  et_id
      ,  a_id
      ,  ae_id
      ,  etn_date
      ,  etn_type
      ,  etn_status)
      VALUES(
         event_trigger_notif_s.NEXTVAL
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  'MAIL_SUB_SYSTEM'
      ,  p_et_id
      ,  p_a_id
      ,  p_ae_id
      ,  SYSDATE
      ,  p_type /* types are P=Primary, S=Seconday */
      ,  p_status /* statuses are C=Complete, E=Error */);
   END IF;

END mail_ctrl;


END evnt_util_pkg;
/
show error
