CREATE OR REPLACE PACKAGE BODY coll_util_pkg AS
/* private modules */
-- private proc to grant select
PROCEDURE grant_select(
   p_tab_name IN VARCHAR2)
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   EXECUTE IMMEDIATE 'GRANT SELECT ON '||p_tab_name||' TO '||USER ;
END grant_select;


-- private proc to exec immediate
PROCEDURE exec_sql(
   p_sql IN VARCHAR2)
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   EXECUTE IMMEDIATE p_sql;
   commit;
END exec_sql;

/* public modules */

FUNCTION part_allowed RETURN BOOLEAN
IS
   CURSOR part_cur IS
      SELECT COUNT(*) flag
      FROM v$option
      WHERE parameter = 'Partitioning'
      AND value = 'TRUE';
   part part_cur%ROWTYPE;
   STATUS BOOLEAN DEFAULT FALSE;
BEGIN
   OPEN part_cur;
   FETCH part_cur INTO part;
   CLOSE part_cur;
   IF part.flag > 0 THEN
      STATUS := TRUE;
   END IF;
   RETURN STATUS;
END part_allowed;


PROCEDURE set_coll_env(
   p_ca_id        IN NUMBER
,  p_out_s_id     OUT NUMBER
,  p_out_c_id     OUT NUMBER
,  p_out_cp_id    OUT NUMBER
,  p_out_sc_id    OUT NUMBER
,  p_out_rcon_str OUT VARCHAR2
,  p_out_db_link  OUT VARCHAR2)
IS
   CURSOR coll_cur IS
      SELECT s_id
      ,      c_id
      ,      cp_id
      ,      sc_id
      FROM coll_assigments
      WHERE ca_id = p_ca_id;
   coll coll_cur%ROWTYPE;

   CURSOR cred_cur(p_sc_id IN NUMBER) IS
      SELECT sc_username||'/'||sc_password||'@'||sc_tns_alias rcon_str
      ,      sc_db_link_name db_link
      FROM sid_credentials
      WHERE sc_id = p_sc_id;
   cred cred_cur%ROWTYPE;
BEGIN
   OPEN coll_cur;
   FETCH coll_cur INTO coll;
   IF coll_cur%FOUND THEN
      CLOSE coll_cur;
      p_out_s_id    := coll.s_id;
      p_out_c_id    := coll.c_id;
      p_out_cp_id   := coll.cp_id;
      p_out_sc_id   := coll.sc_id;


      OPEN cred_cur(coll.sc_id);
      FETCH cred_cur INTO cred;
      CLOSE cred_cur;

      p_out_rcon_str:= cred.rcon_str;
      p_out_db_link := cred.db_link;

   ELSE
      CLOSE coll_cur;
      RAISE_APPLICATION_ERROR(-20001,'Invalid collection CA_ID='||p_ca_id);
   END IF;
END set_coll_env;


PROCEDURE get_view(
   p_c_id IN NUMBER
,  p_cp_id IN NUMBER
,  p_ca_id IN NUMBER
,  p_view_code OUT VARCHAR2
,  p_view_name OUT VARCHAR2)
IS
   CURSOR view_code_cur(p_view_name IN VARCHAR2) IS
      SELECT 'CREATE OR REPLACE VIEW '||p_view_name||' AS '||cp_pull_sql||';' vsql
      FROM   coll_parameters
      WHERE  cp_id = p_cp_id
      AND    c_id = p_c_id;
   view_code view_code_cur%ROWTYPE;

   l_view_name VARCHAR2(100);
   coll_par_invalid_pk EXCEPTION;

BEGIN

   /*
    * VM 28-JAN-2003
    * ----------------
    * To guarantee uniqueness of collection tables
    * when same collection is scheduled agaist same sid
    * CA_ID needs to be embedded into the pull table
    *
    */
   l_view_name := g_view_pref||p_c_id||'_'||p_cp_id||'_'||p_ca_id ;
   
   
   OPEN view_code_cur(l_view_name);
   FETCH view_code_cur INTO view_code;
   IF view_code_cur%FOUND THEN
      CLOSE view_code_cur;
   ELSE
      RAISE coll_par_invalid_pk;
   END IF;
   p_view_code := view_code.vsql;
   p_view_name := l_view_name;
EXCEPTION
   WHEN coll_par_invalid_pk THEN
      RAISE_APPLICATION_ERROR(-20000,'Invalid coll_parameters PK combination, p_c_id='||
                                      p_c_id||' p_cp_id='||p_cp_id);
END get_view;


PROCEDURE pull(
   p_c_id IN NUMBER
,  p_cp_id IN NUMBER
,  p_s_id IN NUMBER
,  p_ca_id IN NUMBER
,  p_view_name IN VARCHAR2
,  p_db_link IN VARCHAR2)
IS
   CURSOR coll_par_cur IS
      SELECT
         NVL(UPPER(ca_purge_flag),UPPER(cp_purge_flag))   cp_purge_flag
      ,  NVL(UPPER(ca_archive_flag),UPPER(cp_archive_flag)) cp_archive_flag
      ,  NVL(ca_pull_ts_name,cp_pull_ts_name) cp_pull_ts_name
      --,  cp_archive_ts_name
      ,  NVL(ca_purge_proc_name,cp_purge_proc_name) cp_purge_proc_name
      FROM coll_parameters cp
      ,    coll_assigments ca
      WHERE cp.c_id = p_c_id
      AND   cp.cp_id = p_cp_id
      AND   ca.ca_id = p_ca_id;
   coll_par coll_par_cur%ROWTYPE;

   CURSOR snap_cur IS
      SELECT MAX(csh_snap_id) maxid
      FROM   coll_snap_history
      WHERE  c_id = p_c_id
      AND    cp_id = p_cp_id
      AND    s_id = p_s_id
      AND    ca_id = p_ca_id;
   snap snap_cur%ROWTYPE;

   CURSOR stat_cur(p_max_sn IN NUMBER) IS
      SELECT csh_status
      ,      csh_id
      FROM   coll_snap_history
      WHERE  c_id = p_c_id
      AND    cp_id = p_cp_id
      AND    s_id = p_s_id
      AND    ca_id = p_ca_id
      AND    csh_snap_id = p_max_sn;
   stat stat_cur%ROWTYPE;

   missing_snap        EXCEPTION;
   unknown_snap        EXCEPTION;
   coll_par_invalid_pk EXCEPTION;

   FIRST_PULL BOOLEAN := FALSE;
   DO_ARCHIVE BOOLEAN := FALSE;
   DO_PURGE   BOOLEAN := FALSE;
   DO_DROP    BOOLEAN := FALSE;

   l_drop_sn      coll_snap_history.csh_snap_id%TYPE;
   l_prev_sn      coll_snap_history.csh_snap_id%TYPE;
   l_curr_sn      coll_snap_history.csh_snap_id%TYPE;
   l_snap_stat    coll_snap_history.csh_status%TYPE;
   l_hist_id      coll_snap_history.csh_id%TYPE;
   l_prev_hist_id coll_snap_history.csh_id%TYPE;
   l_drop_hist_id coll_snap_history.csh_id%TYPE;

   l_sql VARCHAR2(4000);

   l_tcnt NUMBER(10,0);

   l_part_bound NUMBER(10,0);

   l_drop_tab_name VARCHAR2(150);
   l_prev_tab_name VARCHAR2(150);
   l_curr_tab_name VARCHAR2(150);
   l_arch_tab_name VARCHAR2(150);

   l_pull_ts_name coll_parameters.cp_pull_ts_name%TYPE;
   --l_arch_ts_name coll_parameters.cp_archive_ts_name%TYPE;
   l_purge_proc   coll_parameters.cp_purge_proc_name%TYPE;

BEGIN
   OPEN coll_par_cur;
   FETCH coll_par_cur INTO coll_par;

   IF coll_par_cur%FOUND THEN
      CLOSE coll_par_cur;
      l_pull_ts_name := coll_par.cp_pull_ts_name;
      --l_arch_ts_name := coll_par.cp_archive_ts_name;
      l_purge_proc   := coll_par.cp_purge_proc_name;

      IF coll_par.cp_purge_flag = 'Y' THEN
         DO_PURGE := TRUE;
      END IF;

      IF coll_par.cp_archive_flag = 'Y' THEN
         DO_ARCHIVE := TRUE;
      END IF;

   ELSE
      CLOSE coll_par_cur;
      RAISE coll_par_invalid_pk;
   END IF;


   OPEN snap_cur;
   FETCH snap_cur INTO snap;

   IF snap_cur%FOUND AND snap.maxid IS NOT NULL THEN
      CLOSE snap_cur;
      l_prev_sn := snap.maxid;
      l_drop_sn := l_prev_sn - 1;

      -- check for PREV
      OPEN stat_cur(l_prev_sn);
      FETCH stat_cur INTO stat;
      CLOSE stat_cur;
      -- at this point if last snap
      -- is not CURRENT I raise
      -- an ERROR
      IF stat.csh_status = 'C' THEN
         FIRST_PULL := FALSE;
         l_prev_hist_id := stat.csh_id ;
      ELSE
         RAISE missing_snap;
      END IF;

      -- check for OLD to DROP
      OPEN stat_cur(l_drop_sn);
      FETCH stat_cur INTO stat;
      IF stat_cur%FOUND THEN
         CLOSE stat_cur;
         -- at this point if OLD snap
         -- is not PREV I raise
         -- an ERROR since I don't want
         -- to drop some snap that is not
         -- obsolete
         IF stat.csh_status = 'P' THEN
            DO_DROP := TRUE;
            l_drop_hist_id := stat.csh_id ;
         ELSE
            RAISE unknown_snap;
         END IF;
      ELSE
         CLOSE stat_cur;
         DO_DROP := FALSE;
      END IF;

   ELSE
      CLOSE snap_cur;
      FIRST_PULL := TRUE;
   END IF;


   -- TOOK UPDATES FROM HERE

   IF FIRST_PULL THEN
      l_curr_sn := 1;
   ELSE
      l_curr_sn := l_prev_sn + 1;
   END IF;


   l_arch_tab_name := p_view_name||'_'||p_s_id||'_ARCH' ;
   l_curr_tab_name := p_view_name||'_'||p_s_id||'_'||l_curr_sn ;
   l_prev_tab_name := p_view_name||'_'||p_s_id||'_'||l_prev_sn ;
   l_drop_tab_name := p_view_name||'_'||p_s_id||'_'||l_drop_sn ;


   --> CREATE NEW
   l_sql := 'CREATE TABLE '||l_curr_tab_name||
             ' TABLESPACE '||l_pull_ts_name||
             ' NOLOGGING '||
             'AS '||
             'SELECT TO_NUMBER('||l_curr_sn||
                ',999999999999999) sn_id, pull_view.* FROM '||
                p_view_name||'@'||p_db_link||' pull_view' ;

   BEGIN
      exec_sql(l_sql);

      IF NOT FIRST_PULL THEN
         -- set CURR to PREV
         UPDATE coll_snap_history
         SET modified_by = 'PULL'
         ,   date_modified = SYSDATE
         ,   csh_status = 'P'
         WHERE csh_id = l_prev_hist_id;
      END IF;

      SELECT coll_snap_history_s.NEXTVAL
      INTO l_hist_id
      FROM dual;
      
      INSERT INTO coll_snap_history(
         csh_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  cp_id
      ,  ca_id
      ,  c_id
      ,  s_id
      ,  csh_snap_id
      ,  csh_snap_date
      ,  csh_status)
      VALUES(
         l_hist_id
      ,  SYSDATE
      ,  NULL
      ,  NULL
      ,  'PULL'
      ,  p_cp_id
      ,  p_ca_id
      ,  p_c_id
      ,  p_s_id
      ,  l_curr_sn
      ,  SYSDATE
      ,  'C');

   EXCEPTION
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20002,'PULL-PULL: Unexpected error: '||
                                         SQLERRM||' executing: '||l_sql);
   END;
   --< CREATE NEW


   --> ARCHIVE/DROP
   IF NOT FIRST_PULL AND DO_DROP THEN
   
      --> ARCHIVE
      IF DO_ARCHIVE and part_allowed THEN

         SELECT COUNT(*) tcnt
         INTO l_tcnt
         FROM user_tables
         WHERE table_name = UPPER(l_arch_tab_name);
         
         l_part_bound := l_drop_sn + 1 ;
         
         IF l_tcnt = 0 THEN
            -- CREATE ARCHIVE table
            l_sql := 'CREATE TABLE '||l_arch_tab_name||
                     ' PARTITION BY RANGE (sn_id) '||
                     '   ( '||
                     '     PARTITION sn'||l_drop_sn||' VALUES LESS THAN ('||l_part_bound||') '||
                     '   )'||
                     'AS SELECT * '||
                     'FROM '||l_drop_tab_name||
                     ' WHERE 1=2';
         ELSE
            -- ADD PARTITION to ARCHIVE TABLE
            l_sql := 'ALTER TABLE '||l_arch_tab_name||
                     ' ADD PARTITION sn'||l_drop_sn||' VALUES LESS THAN ('||l_part_bound||')' ;
         END IF;
         
         
         BEGIN
            exec_sql(l_sql);
         EXCEPTION
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20002,'PULL-ARCHIVE-CREATE: Unexpected error: '||
                                               SQLERRM||' executing: '||l_sql);
         END;
         
         
         -- ARCHIVE OLD SN by EXCHANGING PARTITIONS
         l_sql := 'ALTER TABLE '||l_arch_tab_name||
                  ' EXCHANGE PARTITION sn'||l_drop_sn||
                  ' WITH TABLE '||l_drop_tab_name ;
         
         BEGIN
            exec_sql(l_sql);
         
            -- set PREV(OLD) to ARCHIVED
            UPDATE coll_snap_history
            SET modified_by = 'ARCHIVE'
            ,   date_modified = SYSDATE
            ,   csh_status = 'A'
            WHERE csh_id = l_drop_hist_id;
         
         EXCEPTION
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20002,'PULL-ARCHIVE-EXCHANGE: Unexpected error: '||
                                               SQLERRM||' executing: '||l_sql);
         END;
         --commit;
      
      ELSE
         
         -- just set PREV to OLD
         UPDATE coll_snap_history
         SET modified_by = 'PULL'
         ,   date_modified = SYSDATE
         ,   csh_status = 'O'
         WHERE csh_id = l_drop_hist_id;
      
         
      END IF;
      --< ARCHIVE
      
      
      -- DROP occurs either way (ARCHIVE or NOT)
      -- above IF/THEN is only to handle
      -- correct UPDATE of history
      --
      l_sql := 'DROP TABLE '||l_drop_tab_name  ;
      
      BEGIN
         exec_sql(l_sql);
         
      EXCEPTION
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20002,'PULL-DROP: Unexpected error: '||
                                            SQLERRM||' executing: '||l_sql);
      END;
      
   END IF;
   --< ARCHIVE/DROP



   --> PURGE if enabled
   IF DO_PURGE AND l_purge_proc IS NOT NULL THEN

      l_sql := 'BEGIN '||l_purge_proc||'('||CHR(39)||l_curr_tab_name||CHR(39)||
                                ','||CHR(39)||p_db_link||CHR(39)||'); END;' ;

      BEGIN
         exec_sql(l_sql);
      EXCEPTION
         WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20002,'PULL-PURGE: Unexpected error: '||
                                            SQLERRM||' executing: '||l_sql);
      END;
      --commit;
   END IF;
   --< PURGE


EXCEPTION
   WHEN unknown_snap THEN
      RAISE_APPLICATION_ERROR(-20001,'Missing drop snapshoot from '||
                                      'coll_snap_history: drop_sn_id='||l_drop_sn);

   WHEN missing_snap THEN
      RAISE_APPLICATION_ERROR(-20001,'Missing prev snapshoot from '||
                                      'coll_snap_history: prev_sn_id='||l_prev_sn);

   WHEN coll_par_invalid_pk THEN
      RAISE_APPLICATION_ERROR(-20000,'Invalid coll_parameters PK combination, p_c_id='||
                                      p_c_id||' p_cp_id='||p_cp_id);

END pull;


PROCEDURE ctrl(
   p_ca_id IN NUMBER
,  p_stage IN VARCHAR2)
IS
   CURSOR restart_cur IS
      SELECT ca_id
      ,      ca_restart_type     typ
      ,      ca_restart_interval int
      ,      (DECODE(ca_restart_type,
                        'MI', 1/24/60,
                        'DD', 1 ,
                        'HH', 1/24) *  ca_restart_interval) +
             ca_started_time ntime
      ,      TRUNC(((NVL(ca_finished_time,SYSDATE)-NVL(ca_started_time,SYSDATE))/(1/24))*60*60) runt_sec
      FROM coll_assigments
      WHERE ca_id = p_ca_id;
   restart restart_cur%ROWTYPE;
BEGIN

   IF p_stage = 'COMPLETE' THEN
      OPEN restart_cur;
      FETCH restart_cur INTO restart;
      CLOSE restart_cur;

      -- handle reschedule/close
      IF restart.typ IS NOT NULL AND
         restart.int IS NOT NULL THEN

         -- reschedule
         UPDATE coll_assigments
         SET ca_phase_code = 'P'
         ,   ca_start_time = restart.ntime
         ,   ca_started_time = NULL
         ,   ca_finished_time = SYSDATE
         ,   ca_last_runtime_sec = restart.runt_sec
         --,   modified_by = 'INTERNAL'
         --,   date_modified = SYSDATE
         WHERE ca_id = p_ca_id;

      ELSE
         -- just close the assigment
         UPDATE coll_assigments
         SET ca_phase_code = 'C'
         ,   ca_started_time = NULL
         ,   ca_finished_time = SYSDATE
         ,   ca_last_runtime_sec = restart.runt_sec
         --,   modified_by = 'INTERNAL'
         --,   date_modified = SYSDATE
         WHERE ca_id = p_ca_id;


      END IF;
   -- << END COMPLETE PHASE

   ELSIF p_stage = 'RUNNING' THEN
      -- set the running time/flag
      UPDATE coll_assigments
      SET ca_phase_code = 'R'
      ,   ca_started_time = SYSDATE
      ,   ca_finished_time = NULL
      --,   modified_by = 'INTERNAL'
      --,   date_modified = SYSDATE
      WHERE ca_id = p_ca_id;
   -- << END RUNNING PHASE

   ELSIF p_stage = 'ERROR' THEN
      -- set the error time/flag
      UPDATE coll_assigments
      SET ca_phase_code = 'E'
      --,   modified_by = 'INTERNAL'
      --,   date_modified = SYSDATE
      WHERE ca_id = p_ca_id;
   -- << END ERROR PHASE

   END IF;
END ctrl;


FUNCTION collection_on_hold(
   p_ca_id IN NUMBER
,  p_hold_reason OUT VARCHAR2)
RETURN BOOLEAN
IS
   CURSOR sid_cur IS
      SELECT a.s_id
      ,      s.h_id
      FROM   coll_assigments a
      ,      sids s
      WHERE  a.ca_id = p_ca_id
      AND    a.s_id = s.s_id;
   sid sid_cur%ROWTYPE;

   l_hold_reason VARCHAR2(100);
   l_return_value BOOLEAN;

   invalid_collection_assigment EXCEPTION;
BEGIN
   OPEN sid_cur;
   FETCH sid_cur INTO sid;
   IF sid_cur%FOUND THEN
      CLOSE sid_cur;

      -- check SID level blackout
      IF glob_util_pkg.active_blackout(
            p_bl_type => 'S',
            p_bl_type_id => sid.s_id,
            p_bl_reason => l_hold_reason) THEN

         l_return_value := TRUE;

      -- check HOST level blackout
      ELSIF glob_util_pkg.active_blackout(
               p_bl_type => 'H',
               p_bl_type_id => sid.h_id,
               p_bl_reason => l_hold_reason) THEN

         l_return_value := TRUE;

      -- check COLLECTION ASSIGMENT level blackout
      ELSIF glob_util_pkg.active_blackout(
               p_bl_type => 'C',
               p_bl_type_id => p_ca_id,
               p_bl_reason => l_hold_reason) THEN

         l_return_value := TRUE;

      ELSE
         l_return_value := FALSE;
      END IF;

   ELSE
      CLOSE sid_cur;
      RAISE invalid_collection_assigment;
   END IF;

   p_hold_reason := l_hold_reason;
   RETURN l_return_value;

EXCEPTION
   WHEN invalid_collection_assigment THEN
      RAISE_APPLICATION_ERROR(-20000,'Invalid Collection Assigment, p_ca_id='||p_ca_id);

END collection_on_hold;


PROCEDURE fix_coll_internal(
   p_c_id IN NUMBER
,  p_cp_id IN NUMBER
,  p_s_id IN NUMBER
,  p_ca_id IN NUMBER)
IS
   CURSOR last_snap_cur IS
      SELECT csh_id, csh_snap_id, csh_snap_date, csh_status
      FROM coll_snap_history
      WHERE csh_snap_id = (SELECT max(csh_snap_id)
                           FROM  coll_snap_history
                           WHERE c_id = p_c_id
                           AND cp_id = p_cp_id
                           AND s_id = p_s_id
                           AND ca_id = p_ca_id)
      AND c_id = p_c_id
      AND cp_id = p_cp_id
      AND s_id = p_s_id
      AND ca_id = p_ca_id;
   last_snap last_snap_cur%ROWTYPE;

   CURSOR prev_snap_cur(p_last_cnap_id IN NUMBER) IS
      SELECT csh_id, csh_snap_id, csh_snap_date, csh_status
      FROM coll_snap_history
      WHERE csh_snap_id = (p_last_cnap_id-1)
      AND c_id = p_c_id
      AND cp_id = p_cp_id
      AND s_id = p_s_id
      AND ca_id = p_ca_id;
   prev_snap prev_snap_cur%ROWTYPE;

   l_last_sn NUMBER(15,0);
   l_last_sn_stat VARCHAR2(1);
   l_last_csh_id NUMBER(15,0);

   l_prev_sn NUMBER(15,0);
   l_prev_sn_stat VARCHAR2(1);
   l_prev_csh_id NUMBER(15,0);

   l_view_name VARCHAR2(150);

   l_arch_tab_name VARCHAR2(150);
   l_last_tab_name VARCHAR2(150);
   l_prev_tab_name VARCHAR2(150);

   CURR_OK BOOLEAN DEFAULT FALSE;
   PREV_OK BOOLEAN DEFAULT FALSE;

   l_tcnt NUMBER(3,0);
   l_ts_name VARCHAR2(100);
   l_sql VARCHAR2(4000);

BEGIN
   dbms_output.put_line('p_c_id ='||p_c_id );
   dbms_output.put_line('p_cp_id='||p_cp_id);
   dbms_output.put_line('p_s_id='||p_s_id);
   dbms_output.put_line('p_ca_id='||p_ca_id);

   OPEN last_snap_cur;
   FETCH last_snap_cur INTO last_snap;
   CLOSE last_snap_cur;
   l_last_sn := last_snap.csh_snap_id;
   l_last_sn_stat := last_snap.csh_status;
   l_last_csh_id := last_snap.csh_id;

   OPEN prev_snap_cur(l_last_sn);
   FETCH prev_snap_cur INTO prev_snap;
   CLOSE prev_snap_cur;
   l_prev_sn := prev_snap.csh_snap_id;
   l_prev_sn_stat := prev_snap.csh_status;
   l_prev_csh_id := prev_snap.csh_id;

   l_view_name := g_view_pref||p_c_id||'_'||p_cp_id||'_'||p_ca_id ;

   l_arch_tab_name := l_view_name||'_'||p_s_id||'_ARCH' ;
   l_last_tab_name := l_view_name||'_'||p_s_id||'_'||l_last_sn ;
   l_prev_tab_name := l_view_name||'_'||p_s_id||'_'||l_prev_sn ;

   dbms_output.put_line('l_arch_tab_name='||l_arch_tab_name);
   dbms_output.put_line('l_last_tab_name='||l_last_tab_name);
   dbms_output.put_line('l_prev_tab_name='||l_prev_tab_name);
   
   IF l_last_sn IS NOT NULL AND
      l_prev_sn IS NOT NULL AND
      l_last_sn_stat = 'P' AND
      l_prev_sn_stat = 'A' THEN

      dbms_output.put_line('LAST=P ['||l_last_tab_name||'] PREV=A ['||l_prev_tab_name||']');
      -- this case is when PULL procedure
      -- ARCHIVED old SNAP and set the CURRENT
      -- to PREVIOUS:

      -- check if ARCHIVE was succesfull
      --
      SELECT COUNT(*)
      INTO l_tcnt
      FROM user_tab_partitions
      WHERE table_name = UPPER(l_arch_tab_name)
      AND   partition_name = UPPER('sn'||l_prev_sn);

      -- 1. revert ARCHIVE PARTITION
      --
      IF l_tcnt > 0 THEN
         SELECT MAX(tablespace_name)
         INTO l_ts_name
         FROM user_tab_partitions
         WHERE table_name = UPPER(l_arch_tab_name)
         AND   partition_name = UPPER('sn'||l_prev_sn);

         l_sql := 'CREATE TABLE '||l_prev_tab_name||
                  ' TABLESPACE '||l_ts_name||
                  ' AS '||
                  ' SELECT * FROM '||l_arch_tab_name||' PARTITION (SN'||l_prev_sn||')';

         BEGIN
            EXECUTE IMMEDIATE l_sql ;
         EXCEPTION
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20002,'FIX-COLL-ARCHIVE-REVERT: Unexpected error: '||
                                               SQLERRM||' executing: '||l_sql);
         END;


         l_sql := 'ALTER TABLE '||l_arch_tab_name||' DROP PARTITION SN'||l_prev_sn ;

         BEGIN
            EXECUTE IMMEDIATE l_sql ;
         EXCEPTION
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20002,'FIX-COLL-ARCHIVE-DROP: Unexpected error: '||
                                               SQLERRM||' executing: '||l_sql);
         END;

      END IF;

      -- reset statuses
      --
      UPDATE coll_snap_history
      SET    date_modified = SYSDATE
      ,      modified_by = 'FIX-COLL-ARCHIVE'
      ,      csh_status = 'C'
      WHERE csh_id = l_last_csh_id;

      UPDATE coll_snap_history
      SET    date_modified = SYSDATE
      ,      modified_by = 'FIX-COLL-ARCHIVE'
      ,      csh_status = 'P'
      WHERE csh_id = l_prev_csh_id;


   ELSIF l_last_sn IS NOT NULL AND
         l_prev_sn IS NOT NULL AND
         l_last_sn_stat = 'C' AND
         l_prev_sn_stat = 'P' THEN

      dbms_output.put_line('LAST=C ['||l_last_tab_name||'] PREV=P ['||l_prev_tab_name||']');
      
      -- this case when PULL procedure
      -- failed somewhere in the middle leaving
      -- things unclean just create blank tables
      -- for each missing snapshoot

      -- check if CURRENT table exists
      --
      SELECT COUNT(*)
      INTO l_tcnt
      FROM user_tables
      WHERE table_name = UPPER(l_last_tab_name);

      IF l_tcnt > 0 THEN
         CURR_OK := TRUE;
      END IF;

      -- check if PREVIOUS table exists
      --
      SELECT COUNT(*)
      INTO l_tcnt
      FROM user_tables
      WHERE table_name = UPPER(l_prev_tab_name);

      IF l_tcnt > 0 THEN
         PREV_OK := TRUE;
      END IF;


      IF CURR_OK AND
         NOT PREV_OK THEN

         SELECT tablespace_name
         INTO l_ts_name
         FROM user_tables
         WHERE table_name = UPPER(l_last_tab_name);

         -- recreate empty PREV table
         l_sql := 'CREATE TABLE '||l_prev_tab_name||
                  ' TABLESPACE '||l_ts_name||
                  ' AS '||
                  ' SELECT * FROM '||l_last_tab_name||' WHERE 1=2';

         BEGIN
            EXECUTE IMMEDIATE l_sql ;
         EXCEPTION
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20002,'FIX-COLL-PREV-CREATE: Unexpected error: '||
                                               SQLERRM||' executing: '||l_sql);
         END;

      END IF;


      IF PREV_OK AND
         NOT CURR_OK THEN

         SELECT tablespace_name
         INTO l_ts_name
         FROM user_tables
         WHERE table_name = UPPER(l_prev_tab_name);

         -- recreate empty CURR table
         l_sql := 'CREATE TABLE '||l_last_tab_name||
                  ' TABLESPACE '||l_ts_name||
                  ' AS '||
                  ' SELECT * FROM '||l_prev_tab_name||' WHERE 1=2';

         BEGIN
            EXECUTE IMMEDIATE l_sql ;
         EXCEPTION
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20002,'FIX-COLL-CURR-CREATE: Unexpected error: '||
                                               SQLERRM||' executing: '||l_sql);
         END;

      END IF;

      -- no need to reset statuses
      --

   ELSIF l_last_sn IS NOT NULL AND
         l_prev_sn IS NOT NULL AND
         l_last_sn_stat = 'P' AND
         l_prev_sn_stat = 'O' THEN

      dbms_output.put_line('LAST=P ['||l_last_tab_name||'] PREV=O ['||l_prev_tab_name||']');
      -- this another case when PULL procedure
      -- failed somewhere in the middle leaving
      -- things unclean just create blank tables
      -- for each missing snapshoot

      -- check if CURRENT table exists
      --
      SELECT COUNT(*)
      INTO l_tcnt
      FROM user_tables
      WHERE table_name = UPPER(l_last_tab_name);

      IF l_tcnt > 0 THEN
         CURR_OK := TRUE;
      END IF;


      IF CURR_OK THEN

         SELECT tablespace_name
         INTO l_ts_name
         FROM user_tables
         WHERE table_name = UPPER(l_last_tab_name);

         -- recreate empty PREV table
         l_sql := 'CREATE TABLE '||l_prev_tab_name||
                  ' TABLESPACE '||l_ts_name||
                  ' AS '||
                  ' SELECT * FROM '||l_last_tab_name||' WHERE 1=2';

         BEGIN
            EXECUTE IMMEDIATE l_sql ;
         EXCEPTION
            WHEN OTHERS THEN
               RAISE_APPLICATION_ERROR(-20002,'FIX-COLL-PREV-CREATE: Unexpected error: '||
                                               SQLERRM||' executing: '||l_sql);
         END;


         -- reset statuses
         --
         UPDATE coll_snap_history
         SET    date_modified = SYSDATE
         ,      modified_by = 'FIX-COLL-ARCHIVE'
         ,      csh_status = 'C'
         WHERE csh_id = l_last_csh_id;

         UPDATE coll_snap_history
         SET    date_modified = SYSDATE
         ,      modified_by = 'FIX-COLL-ARCHIVE'
         ,      csh_status = 'P'
         WHERE csh_id = l_prev_csh_id;

      END IF;


   ELSIF l_last_sn IS NOT NULL AND
         l_prev_sn IS NULL AND
         l_last_sn_stat = 'P' THEN

         -- this a case where it errored out
         -- after first PULL reset status
         -- back to CURRENT

         UPDATE coll_snap_history
         SET    date_modified = SYSDATE
         ,      modified_by = 'FIX-COLL-ARCHIVE'
         ,      csh_status = 'C'
         WHERE csh_id = l_last_csh_id;
   END IF;
END fix_coll_internal;



PROCEDURE fix_coll(
   p_ca_id IN NUMBER DEFAULT NULL)
IS
   CURSOR failed_cur IS
      SELECT ca_id
      FROM coll_assigments
      WHERE ca_phase_code = 'E';

   CURSOR chk_ca_cur IS
      SELECT ca_phase_code
      FROM coll_assigments
      WHERE ca_id = p_ca_id;
   chk_ca chk_ca_cur%ROWTYPE;

   CURSOR failed_det_cur(p_ca_id IN NUMBER) IS
      SELECT c_id
      ,      cp_id
      ,      s_id
      FROM coll_assigments
      WHERE ca_id = p_ca_id;
   failed_det failed_det_cur%ROWTYPE;

   coll_not_error EXCEPTION;
   invalid_collection EXCEPTION;

BEGIN
   IF p_ca_id IS NOT NULL THEN
      OPEN chk_ca_cur;
      FETCH chk_ca_cur INTO chk_ca;
      IF chk_ca_cur%FOUND THEN
         CLOSE chk_ca_cur;
         IF chk_ca.ca_phase_code != 'E' THEN
            RAISE coll_not_error;
         END IF;
      ELSE
         CLOSE chk_ca_cur;
         RAISE invalid_collection;
      END IF;

      OPEN failed_det_cur(p_ca_id);
      FETCH failed_det_cur INTO failed_det;
      CLOSE failed_det_cur;

      DBMS_OUTPUT.PUT_LINE('FIXING CA_ID='||p_ca_id);

      fix_coll_internal(
         p_c_id => failed_det.c_id
      ,  p_cp_id => failed_det.cp_id
      ,  p_s_id => failed_det.s_id
      ,  p_ca_id => p_ca_id);

      UPDATE coll_assigments
      SET   ca_phase_code = 'P'
      --    date_modified = SYSDATE
      --,   modified_by = 'FIX_COLL'
      WHERE ca_id = p_ca_id;

   ELSE
      FOR failed IN failed_cur LOOP
         OPEN failed_det_cur(failed.ca_id);
         FETCH failed_det_cur INTO failed_det;
         CLOSE failed_det_cur;

         DBMS_OUTPUT.PUT_LINE('FIXING CA_ID='||failed.ca_id);

         fix_coll_internal(
            p_c_id => failed_det.c_id
         ,  p_cp_id => failed_det.cp_id
         ,  p_s_id => failed_det.s_id
         ,  p_ca_id => failed.ca_id);

         UPDATE coll_assigments
         SET    ca_phase_code = 'P'
         --    date_modified = SYSDATE
         --,   modified_by = 'FIX_COLL'
         WHERE ca_id = failed.ca_id;
      END LOOP;
   END IF;
EXCEPTION
   WHEN coll_not_error THEN
      RAISE_APPLICATION_ERROR(-20004,'Collection Assigment ID='||p_ca_id||' does not have error status');

   WHEN invalid_collection THEN
      RAISE_APPLICATION_ERROR(-20004,'Collection Assigment ID='||p_ca_id||' is not present in COLL_ASSIGMENTS table');
END fix_coll;



PROCEDURE evnt_snps(
   p_cp_code IN VARCHAR2
,  p_s_id    IN NUMBER
,  p_ca_id   IN NUMBER
,  p_out_csnp OUT VARCHAR2
,  p_out_psnp OUT VARCHAR2)
IS
   CURSOR snps_cur IS
      SELECT /*+ RULE */
         csh_id
      ,  s.s_name
      ,  cp.cp_code
      ,  csh_snap_id
      ,  TO_CHAR(csh_snap_date,'RRRR-MON-DD HH24:MI:SS') csh_snap_date
      ,  csh_status
      ,  DECODE(csh_status,
            'O','OBSOLETE',
            'C','CURRENT',
            'P','PREVIOUS',
            'A','ARCHIVED') status
      ,  DECODE(csh_status,
            'O',' ** DROPPED **',
            'C','evnt.'||g_view_pref||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_'||csh_snap_id,
            'P','evnt.'||g_view_pref||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_'||csh_snap_id,
            'A','evnt.'||g_view_pref||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_arch PARTITION(sn'||csh_snap_id||')') tab_name
      ,  csh.date_modified
      ,  csh.modified_by
      ,  csh.cp_id
      ,  csh.c_id
      ,  csh.s_id
      FROM coll_snap_history csh
      ,    sids s
      ,    coll_parameters cp
      WHERE csh.cp_id = cp.cp_id
      AND   csh.c_id = cp.c_id
      AND   csh.s_id = s.s_id
      AND   cp.cp_code = p_cp_code
      AND   csh.s_id = p_s_id
      AND   csh.ca_id = p_ca_id
      /* only get CURR and PREV coll */
      AND   csh.csh_status IN ('C','P') ;

   -- dummy cursor to lock the row
   -- for PENDING event based collection
   -- (ROW level lock)
   -- if I don't find pending coll exit
   -- out immediately since collections
   -- could be "old" and there's no reason
   -- of making a USER belive that everything
   -- is OK when it's old or bogus data
   --
   -- BOTTOM line is - collection based events
   -- HAVE TO HAVE active collections (P status)
   --
   CURSOR coll_chk_cur IS
      SELECT ca_phase_code
      ,      ca_id
      FROM coll_assigments
      WHERE ca_id = p_ca_id
      AND   ca_phase_code = 'P'
      FOR UPDATE OF ca_phase_code;
   coll_chk coll_chk_cur%ROWTYPE;

   -- running check curs
   CURSOR coll_running_cur IS
      SELECT ca_phase_code
      ,      TO_CHAR(ca_started_time,'RRRR_MON_DD HH24:MI:SS') started_time
      ,      ca_id
      FROM coll_assigments
      WHERE ca_id = p_ca_id
      AND   ca_phase_code = 'R';

   coll_running coll_running_cur%ROWTYPE;

   l_csnp VARCHAR2(256) DEFAULT '-1';
   l_psnp VARCHAR2(256) DEFAULT '-1';

   COLL_STILL_RUNNING BOOLEAN DEFAULT TRUE;

BEGIN
   -- first check if collection is running
   -- wait until it's done (this can create
   -- forever running event but it's better
   -- then erroing it out just because collection
   -- was still running ...)
   WHILE COLL_STILL_RUNNING LOOP
      OPEN coll_running_cur;
      FETCH coll_running_cur INTO coll_running;
      IF coll_running_cur%FOUND THEN
         CLOSE coll_running_cur;
         dbms_output.put_line(TO_CHAR(SYSDATE,'RRRR_MON_DD HH24:MI:SS')||
                                 ': found running collections for this event ('||
                                 coll_running.started_time||
                                 ' going to sleep for 5 secs ...');
         dbms_lock.sleep(5);
      ELSE
         CLOSE coll_running_cur;
         COLL_STILL_RUNNING := FALSE;
      END IF;
   END LOOP;


   -- lock the collection from being
   -- run, if not found exit right away
   -- see cursor for details
   OPEN coll_chk_cur;
   FETCH coll_chk_cur INTO coll_chk;
   IF coll_chk_cur%FOUND THEN
      CLOSE coll_chk_cur;

      FOR snps IN snps_cur LOOP
         dbms_output.put_line('csh_id='||snps.csh_id);
         dbms_output.put_line('s_name='||snps.s_name);
         dbms_output.put_line('cp_code='||snps.cp_code);
         dbms_output.put_line('csh_snap_date='||snps.csh_snap_date);
         dbms_output.put_line('tab_name='||snps.tab_name);
         dbms_output.put_line('status='||snps.status);

         IF snps.status = 'CURRENT' THEN
            l_csnp := snps.tab_name;
         ELSIF snps.status = 'PREVIOUS' THEN
            l_psnp := snps.tab_name;
         END IF;
      END LOOP;

      -- grant select on collected tables
      -- to the current user (bgproc)
      --
      IF l_csnp != '-1' AND
         l_psnp != '-1' THEN

         -- this was causing implicit commit and releasing my lock!
         --
         --EXECUTE IMMEDIATE 'GRANT SELECT ON '||l_csnp||' TO '||USER ;
         --EXECUTE IMMEDIATE 'GRANT SELECT ON '||l_psnp||' TO '||USER ;
         grant_select(l_csnp);
         grant_select(l_psnp);

      ELSE
         dbms_output.put_line('found no current/previous pair of collections for this event!');
      END IF;

   ELSE
      CLOSE coll_chk_cur;
      -- if I got here then there's no pending
      -- collection for this event exit
      dbms_output.put_line('found no pending collection for this event!');
      dbms_output.put_line('p_cp_code='||p_cp_code);
      dbms_output.put_line('p_s_id='||p_s_id);
      dbms_output.put_line('p_ca_id='||p_ca_id);
   END IF;

   -- set OUT vals
   -- '-1' vals will tell that event shouldn't run
   -- DBMS OUTPUT above will give the reason
   p_out_csnp := l_csnp;
   p_out_psnp := l_psnp;
END evnt_snps;


PROCEDURE evnt_get_ca(
   p_cp_code  IN VARCHAR2 DEFAULT NULL
,  p_s_id     IN NUMBER   DEFAULT NULL
,  p_sc_id    IN NUMBER   DEFAULT NULL
,  p_pl_id    IN NUMBER   DEFAULT NULL
,  p_ea_id    IN NUMBER   DEFAULT NULL
,  p_ca_id_out OUT NUMBER
,  p_ret_code  OUT VARCHAR2)
IS
   CURSOR cp_cur IS
      SELECT cp_id
      ,      c_id
      FROM coll_parameters
      WHERE cp_code = p_cp_code;
   cp_rec cp_cur%ROWTYPE;
   
   CURSOR ca_cur(p_cp_id IN NUMBER,
                 p_c_id IN NUMBER,
                 p_phase IN VARCHAR) IS
      SELECT ca_id
      FROM coll_assigments
      WHERE c_id = p_c_id
      AND cp_id = p_cp_id
      AND s_id = p_s_id
      AND ca_phase_code = p_phase
      AND ca_restart_type = 'DD'
      AND ca_restart_interval = 365
      AND ca_evnt_flag = 'Y'
      AND ca_evnt_ea_id = p_ea_id;
   failed_ca ca_cur%ROWTYPE;
   pending_ca ca_cur%ROWTYPE;
   
   l_ret_code VARCHAR2(100) DEFAULT 'OLD';
   l_ret_ca_id coll_assigments.ca_id%TYPE;
   
   invalid_collection_code EXCEPTION;
   
BEGIN
   OPEN cp_cur;
   FETCH cp_cur INTO cp_rec;
   IF cp_cur%FOUND THEN
      CLOSE cp_cur;
   ELSE
      CLOSE cp_cur;
      RAISE invalid_collection_code;
   END IF;


   OPEN ca_cur(cp_rec.cp_id, cp_rec.c_id, 'P');
   FETCH ca_cur INTO l_ret_ca_id;
   CLOSE ca_cur;

   IF l_ret_ca_id IS NULL THEN
   
      -- check if collection 
      -- has failed previously to flag
      -- using dbms_output
      --
      OPEN ca_cur(cp_rec.cp_id, cp_rec.c_id, 'E');
      FETCH ca_cur INTO l_ret_ca_id;
      CLOSE ca_cur;
      
      IF l_ret_ca_id IS NOT NULL THEN
         dbms_output.put_line('WARNING: collection has failed status ca_id='||l_ret_ca_id);
         
      ELSE
         l_ret_code := 'NEW';
         
         SELECT coll_assigments_s.NEXTVAL
         INTO l_ret_ca_id
         FROM DUAL;
         
         INSERT INTO coll_assigments(
            ca_id
         ,  date_created
         ,  date_modified
         ,  modified_by
         ,  created_by
         ,  cp_id
         ,  c_id
         ,  s_id
         ,  sc_id
         ,  pl_id
         ,  ca_phase_code
         ,  ca_start_time
         ,  ca_restart_type
         ,  ca_restart_interval
         ,  ca_started_time
         ,  ca_finished_time
         ,  ca_last_runtime_sec
         ,  ca_purge_flag
         ,  ca_archive_flag
         ,  ca_pull_ts_name
         ,  ca_purge_proc_name
         ,  ca_evnt_flag
         ,  ca_evnt_ea_id)
         VALUES(
            l_ret_ca_id
         ,  SYSDATE
         ,  NULL
         ,  NULL
         ,  'EVNT_AUTO'
         ,  cp_rec.cp_id
         ,  cp_rec.c_id
         ,  p_s_id
         ,  p_sc_id
         ,  p_pl_id
         ,  'P'
         ,  SYSDATE
         ,  'DD'
         ,  365 /*this is just a dummy once a year coll for event based collections */
         ,  NULL
         ,  NULL
         ,  NULL
         ,  NULL
         ,  NULL
         ,  NULL
         ,  NULL
         ,  'Y'
         ,  p_ea_id);
      
      END IF;
      --< END FAILED
   
   END IF;
   --< END OLD
   
   p_ca_id_out := l_ret_ca_id;
   p_ret_code := l_ret_code;

EXCEPTION
   WHEN invalid_collection_code THEN
      RAISE_APPLICATION_ERROR(-20001,'Invalid collection code P_CP_CODE='||p_cp_code);
/*
 * --------------
 * VM 02/03/2003
 * ------------------------------------------------------
 *   I NO LONGER FAIL AN EVEN IF COLLECTION
 *   IS FAILED.  I am working on stabilizing
 *   pull procedure to avoid unrecoverable failures
 *   so that when collection fails you simply rerun it
 *   without the need for cleanups using coll_fix
 *
     
   WHEN failed_collection THEN
      RAISE_APPLICATION_ERROR(-20001,'Collection has failed status - ca_id='||failed_ca.ca_id||' collection code P_CP_CODE='||p_cp_code);
 
 */
 
END evnt_get_ca;


END coll_util_pkg;
/
show error
