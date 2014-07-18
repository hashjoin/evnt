set scan off

CREATE OR REPLACE PACKAGE BODY coll_web_pkg AS

/* GLOBAL FORMATING */
  d_THC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('THC');  /* Table Header Color     */
  d_TRC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRC');  /* Table Row Color        */
  d_TRSC web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRSC'); /* Table SubRow Color        */
  d_PHCM web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCM'); /* Page Header Main Color */
  d_PHCS web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCS'); /* Page Header Sub Color  */

  d_ARC_A web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('ARC_A'); /* Assigment Row Color ACTIVE */
  d_ARC_I web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('ARC_I'); /* Assigment Row Color INACTIVE */
  d_ARC_B web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('ARC_B'); /* Assigment Row Color BROKEN */
  d_ARC_R web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('ARC_R'); /* Assigment Row Color RUNNING */

  COLL_TAB_PREF VARCHAR2(50) := coll_util_pkg.g_view_pref;


PROCEDURE show_snap(
   p_csh_id IN NUMBER)
IS
   CURSOR sn_name_cur IS
      SELECT
         DECODE(csh_status,
            'C',csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_'||csh_snap_id,
            'P',csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_'||csh_snap_id,
            'A',csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_arch PARTITION(sn'||csh_snap_id||')') sn
      FROM coll_snap_history csh
      WHERE csh_id = p_csh_id;

   l_snap_name VARCHAR2(256);
   
BEGIN
   OPEN sn_name_cur;
   FETCH sn_name_cur INTO l_snap_name;
   CLOSE sn_name_cur;
   
   IF l_snap_name IS NOT NULL THEN

      glob_web_pkg.exec_sql(
         p_report => 'COLL_SNAP'
      ,  p_pag => 'YES'
      ,  p_heading => 'Snapshot data ('||COLL_TAB_PREF||l_snap_name||')'
      ,  p_rep_what => '&SNAPSHOOT_TABLE'
      ,  p_rep_with => l_snap_name);  
   
   ELSE
      web_std_pkg.header('Collection System - Invalid Snapshot History ID ('||p_csh_id||')','COLL');
      web_std_pkg.footer;
   END IF;
END show_snap;



PROCEDURE ca_form(
   p_ca_id     IN VARCHAR2 DEFAULT NULL
,  p_operation IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR ca_all_cur IS
      SELECT /*+ ORDERED */
         DECODE(SIGN(DECODE(ca_phase_code,'T',0,'R',0,TRUNC(((SYSDATE-ca_start_time)/(1/24))*60))),
           1,'DOWN',DECODE(ca_phase_code,
                        'P','PEND',
                        'T','TERM',
                        'R','RUN',
                        'E','ERR',
                            'OK')) der_stat
      ,  DECODE(SIGN(DECODE(ca_phase_code,'T',0,'R',0,TRUNC(((SYSDATE-ca_start_time)/(1/24))*60))),
           1,d_ARC_B,DECODE(ca_phase_code,
                        'P',d_ARC_A,
                        'T',d_ARC_I,
                        'R',d_ARC_R,
                        'E',d_ARC_B,
                            d_TRC)) rbg_col
      ,  ca_id
      ,  ca.cp_id
      ,  ca.c_id
      ,  h_name||':'||s_name target
      ,  cp_code
      ,  ca_phase_code stat
      ,  ca_restart_type typ
      ,  ca_restart_interval int
      ,  TO_CHAR(ca_start_time,'RRRR-MON-DD HH24:MI:SS') sch_t
      ,  TO_CHAR(ca_started_time,'RRRR-MON-DD HH24:MI:SS') str_t
      ,  TO_CHAR(ca_finished_time,'RRRR-MON-DD HH24:MI:SS') fin_t
      ,  ca_last_runtime_sec rt_sec
      ,  DECODE(ep.ep_code,NULL,NULL,'('||ea.ea_id||')'||'['||TO_CHAR(ea.ea_start_time,'MON-DD HH24:MI')||']'||ep.ep_code) ea_det
      FROM coll_assigments ca
      ,    coll_parameters cp
      ,    sids s
      ,    hosts h
      ,    event_assigments ea
      ,    event_parameters ep    
      WHERE ca.s_id = s.s_id
      AND   s.h_id = h.h_id
      AND   ca.cp_id = cp.cp_id
      AND   ca.c_id = cp.c_id
      AND   ca.ca_evnt_ea_id = ea.ea_id(+)
      AND   ea.e_id = ep.e_id(+)
      AND   ea.ep_id = ep.ep_id(+)
      ORDER BY target, cp_code;

   -- SWITCHES
   PRINT_REPORT BOOLEAN DEFAULT FALSE;
   PRINT_FOOTER BOOLEAN DEFAULT TRUE;
BEGIN
   PRINT_REPORT := TRUE;

   IF PRINT_REPORT THEN
      web_std_pkg.header('Collection System - Control Panel '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'COLL');

      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Control Links</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Id</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Target</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Collection</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Ea Detail</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">STS</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">I-UNIT</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">I-INT</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Scheduled</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Started</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Finished</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">RT(S)</font></TH>');
      
      FOR ca_all IN ca_all_cur LOOP
         htp.p('<TR BGCOLOR="'||ca_all.rbg_col||'">');
         htp.p('<TD nowrap><font class="TRT"></font></TD>');
         htp.p('<TD nowrap><a href="coll_web_pkg.history?p_ca_id='||
             ca_all.ca_id||
             '&p_operation=DETAIL"'||
             '"><font class="TRL">'||
             ca_all.ca_id||
             '</font></a></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.target||'</font></TD>');
         htp.p('<TD nowrap><a href="coll_web_pkg.cp_form'||
             '?p_c_id='||ca_all.c_id||
             '&p_cp_id='||ca_all.cp_id||
             '&p_operation=CP_DETAIL"'||
             '"><font class="TRL">'||
             ca_all.cp_code||
             '</font></a></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.ea_det||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.stat||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.typ||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.int||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.sch_t||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.str_t||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.fin_t||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ca_all.rt_sec||'</font></TD>');
         htp.p('</TR>');

      END LOOP;

      htp.p('</TABLE>');

   END IF;

   IF PRINT_FOOTER THEN
      web_std_pkg.footer;
   END IF;

END ca_form;


PROCEDURE history(
   p_cp_id      IN VARCHAR2 DEFAULT NULL
,  p_c_id       IN VARCHAR2 DEFAULT NULL
,  p_s_id       IN VARCHAR2 DEFAULT NULL
,  p_ca_id      IN VARCHAR2 DEFAULT NULL
,  p_csh_status IN VARCHAR2 DEFAULT NULL
,  p_operation  IN VARCHAR2 DEFAULT NULL
,  p_pag_str    IN NUMBER   DEFAULT 1
,  p_pag_int    IN NUMBER   DEFAULT 19)
IS

   CURSOR snap_grp_cur IS
      SELECT
         s.s_name
      ,  cp.cp_code
      ,  DECODE(csh_status,
            'O','OBSOLETE',
            'C','CURRENT',
            'P','PREVIOUS',
            'A','ARCHIVED') status
      ,  DECODE(csh_status,
            'O',1,
            'C',4,
            'P',3,
            'A',2) order_by
      ,  COUNT(*) cnt
      ,  csh_status
      ,  csh.cp_id
      ,  csh.c_id
      ,  csh.ca_id
      ,  csh.s_id
      FROM coll_snap_history csh
      ,    coll_parameters cp
      ,    sids s
      WHERE csh.cp_id = cp.cp_id(+)
      AND   csh.c_id = cp.c_id(+)
      AND   csh.s_id = s.s_id(+)
      AND   DECODE(p_ca_id,NULL,'x',csh.ca_id) = NVL(p_ca_id,'x')
      GROUP BY
         s.s_name
      ,  cp.cp_code
      ,  DECODE(csh_status,
            'O','OBSOLETE',
            'C','CURRENT',
            'P','PREVIOUS',
            'A','ARCHIVED')
      ,  DECODE(csh_status,
            'O',1,
            'C',4,
            'P',3,
            'A',2)
      ,  csh_status
      ,  csh.cp_id
      ,  csh.c_id
      ,  csh.s_id
      ,  csh.ca_id
      ORDER BY s_name
      ,        cp.cp_code
      ,        csh.ca_id
      ,  DECODE(csh_status,
            'O',1,
            'C',4,
            'P',3,
            'A',2);


   CURSOR snap_hist_cur IS
      SELECT * 
      FROM (
         SELECT ROWNUM r, a.*
         FROM (
            SELECT
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
                  'C',COLL_TAB_PREF||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_'||csh_snap_id,
                  'P',COLL_TAB_PREF||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_'||csh_snap_id,
                  'A',COLL_TAB_PREF||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_arch PARTITION(sn'||csh_snap_id||')') tab_name
            ,  csh.date_modified
            ,  csh.modified_by
            ,  csh.cp_id
            ,  csh.c_id
            ,  csh.s_id
            ,  csh.ca_id
            FROM coll_snap_history csh
            ,    coll_parameters cp
            ,    sids s
            WHERE csh.cp_id = cp.cp_id(+)
            AND   csh.c_id = cp.c_id(+)
            AND   csh.s_id = s.s_id(+)
            AND   DECODE(p_cp_id,NULL,'x',csh.cp_id) = NVL(p_cp_id,'x')
            AND   DECODE(p_c_id,NULL,'x',csh.c_id) = NVL(p_c_id,'x')
            AND   DECODE(p_s_id,NULL,'x',csh.s_id) = NVL(p_s_id,'x')
            AND   DECODE(p_csh_status,NULL,'x',csh.csh_status) = NVL(p_csh_status,'x')
            AND   DECODE(p_ca_id,NULL,'x',csh.ca_id) = NVL(p_ca_id,'x')
            ORDER BY s_name
            ,        cp.cp_code
            ,        csh.ca_id
            ,        csh_snap_id DESC) a
         WHERE ROWNUM <= (p_pag_str + p_pag_int))
      WHERE r >= p_pag_str;

   -- SWITCHES
   PRINT_REP_BANNER BOOLEAN DEFAULT FALSE;
   PRINT_REPORT     BOOLEAN DEFAULT FALSE;
   PRINT_GRP        BOOLEAN DEFAULT TRUE;
   PRINT_REP_FOOTER BOOLEAN DEFAULT TRUE;
   
   row_cnt INTEGER DEFAULT 0;
   lrow_id INTEGER;

BEGIN
   IF p_operation = 'DETAIL' THEN
      PRINT_REPORT := TRUE;
      PRINT_GRP := FALSE;
   END IF;

   PRINT_REP_BANNER := TRUE;

   IF PRINT_REP_BANNER THEN
      web_std_pkg.header('Collection System - History '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'COLL');
   END IF;


   IF PRINT_REPORT THEN
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Source</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Collection</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Id</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">SNP</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">DATE</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">STATUS</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">PULL Table</font></TH>');

      FOR snap_hist IN snap_hist_cur LOOP
         htp.p('<TR>');
         htp.p('<TD nowrap><font class="TRT">'||snap_hist.s_name||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||snap_hist.cp_code||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||snap_hist.ca_id||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||snap_hist.csh_snap_id||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||snap_hist.csh_snap_date||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||snap_hist.status||'</font></TD>');
         IF snap_hist.status = 'OBSOLETE' THEN
            htp.p('<TD nowrap><font class="TRT">'||snap_hist.tab_name||'</font></TD>');
         ELSE
            htp.p('<TD nowrap><a href="coll_web_pkg.show_snap?p_csh_id='||
                web_std_pkg.encode_url(snap_hist.csh_id)||
                '"><font class="TRL">'||
                snap_hist.tab_name||
                '</font></a></TD>');
         END IF;
         
         htp.p('</TR>');

         row_cnt := row_cnt + 1;
         lrow_id := snap_hist.r;
      END LOOP;
      htp.p('</TABLE>');

      -- paginate controls
      -- open paginate table
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');
      htp.p('<tr>');

      -- PREV
      IF p_pag_str > 1 THEN
         htp.p('<form method="POST" action="coll_web_pkg.history">');
         htp.p('<input type="hidden" name="p_cp_id" value="'||htf.escape_sc(p_cp_id)||'">');
         htp.p('<input type="hidden" name="p_c_id" value="'||htf.escape_sc(p_c_id)||'">');
         htp.p('<input type="hidden" name="p_s_id" value="'||htf.escape_sc(p_s_id)||'">');
         htp.p('<input type="hidden" name="p_ca_id" value="'||htf.escape_sc(p_ca_id)||'">');
         htp.p('<input type="hidden" name="p_csh_status" value="'||htf.escape_sc(p_csh_status)||'">');
         htp.p('<input type="hidden" name="p_operation" value="'||htf.escape_sc(p_operation)||'">');
         htp.p('<input type="hidden" name="p_pag_str" value="'||htf.escape_sc(TO_CHAR(p_pag_str-p_pag_int-1))||'">');
         htp.p('<input type="hidden" name="p_pag_int" value="'||htf.escape_sc(p_pag_int)||'">');
         htp.p('<td><input type="SUBMIT" value="<< ['||TO_CHAR(p_pag_str-p_pag_int-1)||'-'||TO_CHAR(p_pag_str-1)||']"></td>');
         htp.p('</form>');
      END IF;
      
      -- CURR
      IF row_cnt > 0 THEN
         htp.p('<TD nowrap><font class="TRT">[<b>'||p_pag_str||'-'||lrow_id||'</b>]</TD>');
      ELSE
         htp.p('<TD nowrap><font class="TRT">[<b>no data found ...</b>]</TD>');
      END IF;
      
      -- NEXT
      IF row_cnt > p_pag_int THEN
         htp.p('<form method="POST" action="coll_web_pkg.history">');
         htp.p('<input type="hidden" name="p_cp_id" value="'||htf.escape_sc(p_cp_id)||'">');
         htp.p('<input type="hidden" name="p_c_id" value="'||htf.escape_sc(p_c_id)||'">');
         htp.p('<input type="hidden" name="p_s_id" value="'||htf.escape_sc(p_s_id)||'">');
         htp.p('<input type="hidden" name="p_ca_id" value="'||htf.escape_sc(p_ca_id)||'">');
         htp.p('<input type="hidden" name="p_csh_status" value="'||htf.escape_sc(p_csh_status)||'">');
         htp.p('<input type="hidden" name="p_operation" value="'||htf.escape_sc(p_operation)||'">');
         htp.p('<input type="hidden" name="p_pag_str" value="'||htf.escape_sc(TO_CHAR(p_pag_str+p_pag_int+1))||'">');
         htp.p('<input type="hidden" name="p_pag_int" value="'||htf.escape_sc(p_pag_int)||'">');
         htp.p('<td><input type="SUBMIT" value="['||TO_CHAR(lrow_id+1)||'-'||TO_CHAR(lrow_id+p_pag_int+1)||'] >>"></td>');
         htp.p('</form>');
      END IF;
      
      -- close paginate table
      htp.p('</tr>');
      htp.p('</table>');

      htp.p('<BR>');
   END IF;


   IF PRINT_GRP THEN
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Source</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Collection</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Id</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">STATUS</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">COUNT</font></TH>');

      FOR snap_grp IN snap_grp_cur LOOP
         htp.p('<TR>');
         htp.p('<TD nowrap><font class="TRT">'||snap_grp.s_name||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||snap_grp.cp_code||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||snap_grp.ca_id||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||snap_grp.status||'</font></TD>');
         htp.p('<TD nowrap><a href="coll_web_pkg.history?p_cp_id='||snap_grp.cp_id||
                                                       '&p_c_id='||snap_grp.c_id||
                                                       '&p_s_id='||snap_grp.s_id||
                                                       '&p_ca_id='||snap_grp.ca_id||
                                                       '&p_csh_status='||snap_grp.csh_status||
                                                       '&p_operation=DETAIL">'||
                                                       '<font class="TRL">'||
                                                        snap_grp.cnt||'</font></a></TD>');
         htp.p('</TR>');
      END LOOP;

      htp.p('</TABLE>');
   END IF;


   IF PRINT_REP_FOOTER THEN
      web_std_pkg.footer;
   END IF;

END history;


PROCEDURE cp_form(
   p_cp_id               IN VARCHAR2 DEFAULT NULL
,  p_c_id                IN VARCHAR2 DEFAULT NULL
,  p_date_created        IN VARCHAR2 DEFAULT NULL
,  p_date_modified       IN VARCHAR2 DEFAULT NULL
,  p_modified_by         IN VARCHAR2 DEFAULT NULL
,  p_created_by          IN VARCHAR2 DEFAULT NULL
,  p_cp_code             IN VARCHAR2 DEFAULT NULL
,  p_cp_pull_sql         IN VARCHAR2 DEFAULT NULL
,  p_cp_purge_flag       IN VARCHAR2 DEFAULT NULL
,  p_cp_archive_flag     IN VARCHAR2 DEFAULT NULL
,  p_cp_pull_ts_name     IN VARCHAR2 DEFAULT NULL
,  p_cp_purge_proc_name  IN VARCHAR2 DEFAULT NULL
,  p_cp_desc             IN VARCHAR2 DEFAULT NULL
,  p_operation           IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR cp_det_cur IS
      SELECT
         cp_id
      ,  c_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  cp_code
      ,  cp_pull_sql
      ,  cp_purge_flag
      ,  cp_archive_flag
      ,  cp_pull_ts_name
      ,  cp_purge_proc_name
      ,  cp_desc
      FROM coll_parameters
      WHERE c_id = p_c_id
      AND   cp_id = p_cp_id;
   cp_det cp_det_cur%ROWTYPE;
   
   PRINT_REP_BANNER BOOLEAN DEFAULT FALSE;
   PRINT_REPORT     BOOLEAN DEFAULT FALSE;
   PRINT_REP_FOOTER BOOLEAN DEFAULT TRUE;
BEGIN
   IF p_operation = 'CP_DETAIL' THEN
      PRINT_REP_BANNER := TRUE;
      PRINT_REPORT := TRUE;
   END IF;

   IF PRINT_REP_BANNER THEN
      web_std_pkg.header('Collection System - Collection Parameters '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'COLL');
   END IF;

   IF PRINT_REPORT THEN
      htp.p('<TABLE border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');

      OPEN cp_det_cur;
      FETCH cp_det_cur INTO cp_det;
      CLOSE cp_det_cur;

      htp.p('<TR>');
      htp.p('<TD nowrap><font class="TRT"><b>'||cp_det.cp_desc||'</b></font></TD>');
      htp.p('</TR>');
      
      htp.p('<TR>');
      htp.p('<TD>'); 
      htp.p('<PRE>');
      htp.p('<b>Collection:  </b>'||cp_det.cp_code);
      htp.p('<b>Purge:       </b>'||cp_det.cp_purge_flag);
      htp.p('<b>Purge Proc:  </b>'||cp_det.cp_purge_proc_name);
      htp.p('<b>Acrhive:     </b>'||cp_det.cp_archive_flag);
      htp.p('<b>Tablespace:  </b>'||cp_det.cp_pull_ts_name);
      htp.p('----------------------------------------------');
      htp.p(htf.escape_sc(cp_det.cp_pull_sql));
      htp.p('</PRE>');
      htp.p('</TD>');
      htp.p('</TR>');
      
      htp.p('</TABLE>');
   END IF;

   IF PRINT_REP_FOOTER THEN
      web_std_pkg.footer;
   END IF;
      
END cp_form;


PROCEDURE trend_analyzer(
   p_event      IN VARCHAR2 DEFAULT NULL
,  p_year       IN VARCHAR2 DEFAULT NULL
,  p_date       IN VARCHAR2 DEFAULT NULL
,  p_operation  IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR from_clause_cur IS
      SELECT DISTINCT
         DECODE(csh_status,
                  'C',COLL_TAB_PREF||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_'||csh_snap_id,
                  'P',COLL_TAB_PREF||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_'||csh_snap_id,
                  'A',COLL_TAB_PREF||csh.c_id||'_'||csh.cp_id||'_'||csh.ca_id||'_'||csh.s_id||'_arch') tab_name
      FROM coll_snap_history csh
      WHERE ca_id = (SELECT ca_id
                     FROM coll_assigments
                     WHERE (cp_id, c_id) = (SELECT cp_id, c_id
                                            FROM coll_parameters
                                            WHERE cp_code = 'EPRG_MARK'))
      AND   csh_status != 'O';
  
  l_cur INTEGER;
  sql_all    VARCHAR2(32000);
  sql_union  VARCHAR2(20);
  sql_select VARCHAR2(700);
  sql_where  VARCHAR2(700);
  sql_end    VARCHAR2(300);
  from_cnt   INTEGER DEFAULT 0;
  ret_chr    VARCHAR2(5) DEFAULT chr(10);
  l_year     VARCHAR2(4) DEFAULT TO_CHAR(SYSDATE,'RRRR');
BEGIN
   web_std_pkg.header('Collection System - Event Trend Analyzer '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'COLL');

   IF p_year IS NOT NULL THEN
      l_year := p_year;
   END IF;
   

   IF p_operation IS NULL THEN

      -- allow for year stepping
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');
      htp.p('<tr>');

      -- year back
      htp.p('<td>');
      htp.p('<form method="POST" action="coll_web_pkg.trend_analyzer">');
      htp.p('<input type="SUBMIT" value="'||TO_NUMBER(l_year-1,'9999')||' <<<">');
      htp.p('<input type="hidden" name="p_year" value="'||TO_NUMBER(l_year-1,'9999')||'">');
      htp.p('<input type="hidden" name="p_date" value="'||p_date||'">');
      htp.p('<input type="hidden" name="p_event" value="'||p_event||'">');
      htp.p('<input type="hidden" name="p_operation" value="'||p_operation||'">');
      htp.p('</form>');
      htp.p('</td>');

      -- refresh current year
      htp.p('<td>');
      htp.p('<form method="POST" action="coll_web_pkg.trend_analyzer">');
      htp.p('<input type=text name=p_year size=4 maxlength=4 value="'||l_year||'">');
      htp.p('<input type="SUBMIT" value="Refresh">');
      htp.p('<input type="hidden" name="p_date" value="'||p_date||'">');
      htp.p('<input type="hidden" name="p_event" value="'||p_event||'">');
      htp.p('<input type="hidden" name="p_operation" value="'||p_operation||'">');
      htp.p('</form>');
      htp.p('</td>');

      -- year forward
      htp.p('<td>');
      htp.p('<form method="POST" action="coll_web_pkg.trend_analyzer">');
      htp.p('<input type="SUBMIT" value=">>> '||TO_NUMBER(l_year+1,'9999')||'">');
      htp.p('<input type="hidden" name="p_year" value="'||TO_NUMBER(l_year+1,'9999')||'">');
      htp.p('<input type="hidden" name="p_date" value="'||p_date||'">');
      htp.p('<input type="hidden" name="p_event" value="'||p_event||'">');
      htp.p('<input type="hidden" name="p_operation" value="'||p_operation||'">');
      htp.p('</form>');
      htp.p('</td>');

      htp.p('</tr>');
      htp.p('</table>');


      sql_all := 'SELECT '||ret_chr||
                 '   e_code "Event" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/01&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/01'',cnt,NULL))||''</font></a>'' "JAN" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/02&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/02'',cnt,NULL))||''</font></a>'' "FEB" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/03&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/03'',cnt,NULL))||''</font></a>'' "MAR" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/04&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/04'',cnt,NULL))||''</font></a>'' "APR" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/05&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/05'',cnt,NULL))||''</font></a>'' "MAR" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/06&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/06'',cnt,NULL))||''</font></a>'' "JUN" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/07&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/07'',cnt,NULL))||''</font></a>'' "JUL" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/08&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/08'',cnt,NULL))||''</font></a>'' "AUG" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/09&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/09'',cnt,NULL))||''</font></a>'' "SEP" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/10&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/10'',cnt,NULL))||''</font></a>'' "OCT" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/11&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/11'',cnt,NULL))||''</font></a>'' "NOV" '||ret_chr||
                 ',  ''<a href="coll_web_pkg.trend_analyzer?p_event=''||e_code||''&p_date='||l_year||'/12&p_operation=MONTH">''||MAX(DECODE(tr_time,'''||l_year||'/12'',cnt,NULL))||''</font></a>'' "DEC" '||ret_chr||
                 'FROM ( '||ret_chr||
                 'SELECT '||ret_chr||
                 '   e_code '||ret_chr||
                 ',  tr_time '||ret_chr||
                 ',  COUNT(e_code) cnt '||ret_chr||
                 'FROM ( ';
     
      sql_select := '   e_code '||ret_chr||
                    ',  TO_CHAR(et_trigger_time,''RRRR/MM'') tr_time ' ;

      sql_end := 'GROUP BY e_code, tr_time '||ret_chr||
                 'ORDER BY e_code, tr_time) '||ret_chr||
                 'GROUP BY e_code '||ret_chr||
                 'ORDER BY e_code ';
      
   END IF;
   --<< YEAR OPERATION
   
   
   IF p_operation = 'MONTH' THEN

      sql_all := 'SELECT '||ret_chr||
                 '   target "Target" '||ret_chr||
                 ',  et_trigger_time "Time" '||ret_chr||
                 ',  et_status "Threshold" '||ret_chr||
                 ',  ''<a href="evnt_web_pkg.get_trigger?p_et_id=''||et_id||''"><font class="TRL">''||et_id||''</font></a>'' "Trigger" '||ret_chr||
                 'FROM ( ';
      
      sql_select := '   et_id '||ret_chr||
                    ',  host||DECODE(sid,NULL,NULL,'':''||sid) target '||ret_chr||
                    ',  TO_CHAR(et_trigger_time,''RRRR/MM/DD HH24:MI:SS'') et_trigger_time '||ret_chr||
                    ',  et_status  ';


      sql_where := 'WHERE e_code = '''||p_event||''' '||ret_chr||
                   'AND   TRUNC(et_trigger_time,''MM'') = TO_DATE('''||p_date||''',''RRRR/MM'') ';

                   
      sql_end := 'ORDER BY et_trigger_time ';

   END IF;
   --<< END MONTH OPERATION

   
   -- build complete statement
   --
   FOR from_clause IN from_clause_cur LOOP
    
      IF from_cnt = 0 THEN
         sql_union := 'SELECT ';
      ELSE
         sql_union := 'UNION ALL SELECT ';
      END IF;
      
      sql_all := sql_all||
                 sql_union||
                 sql_select||
                 'FROM '||from_clause.tab_name||' '||
                 sql_where;
      
      from_cnt := from_cnt + 1;
   
   END LOOP;

   -- complete inline view
   --
   sql_all := sql_all||') '||sql_end;
   
   -- only call glob_web_pkg.exec_sql
   -- if there are snapshots found
   IF from_cnt != 0 THEN
      l_cur := dbms_sql.open_cursor;
      dbms_sql.parse(
         l_cur
      ,  sql_all
      ,  dbms_sql.native);
      glob_web_pkg.exec_sql(p_cursor=>l_cur, p_heading=>'NONE');
      dbms_sql.close_cursor(l_cur);
   ELSE
      htp.p('<b>No data found ...</b>');
   END IF;
   
   web_std_pkg.footer;
END trend_analyzer;


END coll_web_pkg;
/
show error
