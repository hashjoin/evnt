CREATE OR REPLACE PACKAGE BODY glob_util_pkg AS
/* GLOBAL VARS */

/* PRIVATE MODULES */

/* GLOBAL MODULES */

FUNCTION active_blackout(
   p_bl_type IN VARCHAR2,
   p_bl_type_id IN NUMBER,
   p_bl_reason OUT VARCHAR2)
RETURN BOOLEAN
IS
   CURSOR blackout_cur IS
      SELECT eb_id
      ,      DECODE(eb_type,
                'H', 'Host Level Blackout',
                'S', 'Sid Level Blackout',
                'E', 'Event Level Blackout',
                'X', 'Event Assigment Level Blackout',
                'P', 'Pager/Email Blackout',
                'A', 'Admin Level Blackout',
                'C', 'Collection Level Blackout',
                     'Unknown Blackout')||' '||
             eb_code||' is active EB_ID='||TO_CHAR(eb_id) blackout_reason
      FROM   event_blackouts
      WHERE  DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),
                '0001-01-01', TO_DATE(TO_CHAR(SYSDATE,'RRRR-MM-DD')||' '||TO_CHAR(eb_start_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
				              eb_start_date) <= TRUNC(SYSDATE,'MI')
      AND    DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),
                '9000-01-01', TO_DATE(TO_CHAR(SYSDATE,'RRRR-MM-DD')||' '||TO_CHAR(eb_end_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
				              eb_end_date) >= TRUNC(SYSDATE,'MI')
      AND    DECODE(eb_week_day,-1,TO_CHAR(SYSDATE,'D'),TO_CHAR(eb_week_day)) = TO_CHAR(SYSDATE,'D')
      AND    eb_active_flag = 'Y'
      AND    eb_type = p_bl_type
      AND    eb_type_id = p_bl_type_id;
   blackout blackout_cur%ROWTYPE;
   l_return_value BOOLEAN;
   l_bl_reason VARCHAR2(100);
BEGIN
   OPEN blackout_cur;
   FETCH blackout_cur INTO blackout;
   IF blackout_cur%FOUND THEN
      CLOSE blackout_cur;
      l_return_value := TRUE;
      l_bl_reason := blackout.blackout_reason;
   ELSE
      CLOSE blackout_cur;
      l_return_value := FALSE;
      l_bl_reason := NULL;
   END IF;

   p_bl_reason := l_bl_reason;
   RETURN l_return_value;
END active_blackout;


PROCEDURE host_int(
   p_host IN VARCHAR2
,  p_host_desc IN VARCHAR2
,  p_host_id OUT NUMBER)
IS
   CURSOR host_cur IS
      SELECT h_id
      FROM   hosts
      WHERE  LOWER(h_name) = LOWER(p_host);
   host host_cur%ROWTYPE;

   l_host_id hosts.h_id%TYPE;
BEGIN
   OPEN host_cur;
   FETCH host_cur INTO host;
   IF host_cur%FOUND THEN
      CLOSE host_cur;
      l_host_id := host.h_id;
   ELSE
      CLOSE host_cur;
      SELECT hosts_s.NEXTVAL
      INTO l_host_id
      FROM dual;
      
      dbms_output.put_line('CREATING HOST: H_ID='||l_host_id);

      INSERT INTO hosts(
         h_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  h_name
      ,  h_desc)
      VALUES(
         l_host_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  'INTERFACE'
      ,  p_host
      ,  p_host_desc);
   END IF;

   p_host_id := l_host_id;
END host_int;


PROCEDURE sid_int(
   p_sid IN VARCHAR2
,  p_sid_desc IN VARCHAR2
,  p_host_id IN NUMBER
,  p_sid_id OUT NUMBER)
IS
   CURSOR sid_cur IS
      SELECT s_id
      FROM sids
      WHERE UPPER(s_name) = UPPER(p_sid)
      AND   h_id = p_host_id;
   sid sid_cur%ROWTYPE;

   l_sid_id sids.s_id%TYPE;
BEGIN
   OPEN sid_cur;
   FETCH sid_cur INTO sid;
   IF sid_cur%FOUND THEN
      CLOSE sid_cur;
      l_sid_id := sid.s_id;
   ELSE
      CLOSE sid_cur;

      SELECT sids_s.NEXTVAL
      INTO l_sid_id
      FROM dual;
      
      dbms_output.put_line('CREATING SID: S_ID='||l_sid_id);

      INSERT INTO sids(
         s_id
      ,  h_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  s_name
      ,  s_desc)
      VALUES(
         l_sid_id
      ,  p_host_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  'INTERFACE'
      ,  p_sid
      ,  p_sid_desc);
   END IF;

   p_sid_id := l_sid_id;
END sid_int;


PROCEDURE sid_cred_int(
   p_sc_username IN VARCHAR2
,  p_sc_password IN VARCHAR2
,  p_sc_tns_alias IN VARCHAR2
,  p_sid_id IN NUMBER)
IS
   CURSOR sc_cur IS
      SELECT sc_id
      FROM sid_credentials
      WHERE s_id = p_sid_id
      AND   UPPER(sc_username) = UPPER(p_sc_username);
   sc sc_cur%ROWTYPE;

   l_sc_id sid_credentials.sc_id%TYPE;
BEGIN
   OPEN sc_cur;
   FETCH sc_cur INTO sc;
   IF sc_cur%FOUND THEN
      CLOSE sc_cur;
   ELSE
      CLOSE sc_cur;

      SELECT sid_credentials_s.NEXTVAL
      INTO l_sc_id
      FROM dual;
      
      dbms_output.put_line('CREATING SID CREDENTIAL: SC_ID='||l_sc_id);

      INSERT INTO sid_credentials(
         sc_id
      ,  s_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  sc_username
      ,  sc_password
      ,  sc_tns_alias)
      VALUES(
         l_sc_id
      ,  p_sid_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  'INTERFACE'
      ,  p_sc_username
      ,  p_sc_password
      ,  p_sc_tns_alias);
   END IF;
END sid_cred_int;


PROCEDURE target_int
IS
   CURSOR load_cur IS
      SELECT
         uti_host         host
      ,  uti_host_desc    host_desc
      ,  uti_sid          sid
      ,  uti_sid_desc     sid_desc
      ,  uti_sc_username  sc_username
      ,  uti_sc_password  sc_password
      ,  uti_sc_tns_alias sc_tns_alias
      FROM util_target_int
      ORDER BY uti_host
      ,        uti_sid
      ,        uti_sc_username;

   l_host_id hosts.h_id%TYPE;
   l_sid_id sids.s_id%TYPE;

BEGIN
   FOR load IN load_cur LOOP
      host_int(
         p_host => load.host
      ,  p_host_desc => load.host_desc
      ,  p_host_id => l_host_id);

      IF load.sid IS NOT NULL THEN
         sid_int(
            p_sid => load.sid
         ,  p_sid_desc => load.sid_desc
         ,  p_host_id => l_host_id
         ,  p_sid_id => l_sid_id);
      END IF;
      
      IF load.sc_username IS NOT NULL AND
         load.sc_password IS NOT NULL AND
         load.sc_tns_alias IS NOT NULL THEN
         sid_cred_int(
            p_sc_username => load.sc_username
         ,  p_sc_password => load.sc_password
         ,  p_sc_tns_alias => load.sc_tns_alias
         ,  p_sid_id => l_sid_id);
      END IF;
      
      
   END LOOP;
END target_int;


PROCEDURE set_pend(
   p_type     IN VARCHAR2
,  p_max_proc IN NUMBER
,  p_rhost    IN VARCHAR2 DEFAULT NULL)
IS
BEGIN
   IF p_type = 'COLL' THEN

      INSERT INTO glob_pend_assignments
         SELECT ROWNUM, a.ca_id FROM (
            SELECT ca_id
            ,      ca_start_time
            FROM coll_assigments
            WHERE ca_phase_code IN ('P','E')
            AND ca_evnt_flag = 'N'
            AND ca_start_time <= SYSDATE
            ORDER BY ca_start_time) a
         WHERE ROWNUM <= p_max_proc;

      UPDATE coll_assigments
      SET ca_phase_code = 'S'
      WHERE ca_id IN (
         SELECT gpa_val
         FROM glob_pend_assignments
      );

   ELSIF p_type = 'EVNT' THEN

      IF p_rhost IS NULL THEN

         INSERT INTO glob_pend_assignments
            SELECT ROWNUM, a.ea_id FROM (
               SELECT /*+ ORDERED */
                   ea_id
               ,   ea_start_time
               FROM event_assigments ea
               ,    events e
               WHERE e.e_code_base NOT LIKE '*%'
               AND   ea.e_id = e.e_id
               AND   ea_status in ('A','B')
               AND   ea_start_time <= SYSDATE
               ORDER BY ea_start_time) a
            WHERE ROWNUM <= p_max_proc;

         -- ea_status "l" sets up EA to run
         -- thru LOCAL agent
         UPDATE event_assigments
         SET ea_status = 'l'
         WHERE ea_id IN (
            SELECT gpa_val
            FROM glob_pend_assignments
         );

      ELSE

         INSERT INTO glob_pend_assignments
            SELECT ROWNUM, a.ea_id FROM (
               SELECT /*+ ORDERED */
                  ea_id
               ,  ea_start_time
               FROM event_assigments ea
               ,    events e
               ,    hosts h
               WHERE e.e_code_base LIKE '*%'
               AND   h.h_name = p_rhost
               AND   ea.h_id  = h.h_id
               AND   ea.e_id = e.e_id
               AND   ea_status in ('A','B')
               AND   ea_start_time <= SYSDATE
               ORDER BY ea_start_time) a
            WHERE ROWNUM <= p_max_proc;

         -- ea_status "r" sets up EA to run
         -- thru REMOTE agent
         UPDATE event_assigments
         SET ea_status = 'r'
         WHERE ea_id in (
            SELECT gpa_val
            FROM glob_pend_assignments
         );

      -- <END p_rhost IF>
      END IF;

   -- <END p_type IF>
   END IF;

END set_pend;


END glob_util_pkg;
/
show error
