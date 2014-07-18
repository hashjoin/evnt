CREATE OR REPLACE PACKAGE BODY web_nav_pkg AS

  d_THC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('THC');  /* Table Header Color     */
  d_TRC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRC');  /* Table Row Color        */
  d_PHCM web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCM'); /* Page Header Main Color */
  d_PHCS web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCS'); /* Page Header Sub Color  */
  d_PHMA web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHMA'); /* Page Header Menu Color ACTIVE  */
  
/* private proc */
PROCEDURE nav(
   p_location IN VARCHAR2)
IS
   l_mdesc web_menus.wm_desc%TYPE;
BEGIN
   SELECT wm_desc INTO l_mdesc
   FROM (SELECT wm_desc
         FROM web_menus
         WHERE wm_code = p_location)
   WHERE ROWNUM = 1;
   
   web_std_pkg.header(
      p_message  => l_mdesc
   ,  p_location => p_location
   ,  p_menu => TRUE);
END nav;


PROCEDURE evnt
IS
   l_num INTEGER;
BEGIN
   nav('MAIN');
   
   htp.p('<h3><center>At A Glance</center></h3>');
   htp.p('<ul>');


   SELECT cnt INTO l_num
   FROM (select count(*) cnt
         from event_assigments);
         
   htp.p('<li><font class="TRT">found <b>'||l_num||'</b> event assigments</font></li>');

   htp.p('<ul>');
      FOR asts IN (select
                       decode(ea_status,
                          'R','running',
                          'I','inactive',
                          'A','pending',
                          'B','failed',
                          'l','scheduled (local agent)',
                          'r','scheduled (remote agent)') typ
                   ,   count(*) cnt
                   from event_assigments 
                   group by ea_status
                   union all
                   select 
                      'behind schedule' typ
                   ,   count(*) cnt
                   from event_assigments
                   where ea_status = 'A'
                   and SYSDATE >= ea_start_time+2/24/60
                   union all
                   select 
                      'stale [running > 15 min]' typ
                   ,   count(*) cnt
                   from event_assigments
                   where ea_status = 'R'
                   and  SYSDATE - ea_started_time >= 15/24/60)
      LOOP
         htp.p('<li><font class="TRT"><b>'||asts.cnt||'</b> <i>'||asts.typ||'</i></font></li>');
      END LOOP;
   htp.p('</ul>');
   
   
   FOR atim IN (select min(decode(ea_last_runtime_sec,
                              0,1,ea_last_runtime_sec)) tim
                ,      'fastest' typ
                from event_assigments
                where ea_status = 'A'
                union all
                select max(ea_last_runtime_sec) tim
                ,      'slowest' typ
                from event_assigments
                where ea_status = 'A'
                union all
                select round(avg(decode(ea_last_runtime_sec,
                                    0,1,ea_last_runtime_sec)),0) tim
                ,      'average' typ
                from event_assigments
                where ea_status = 'A')
   LOOP
      htp.p('<li><font class="TRT">the <b><i>'||atim.typ||'</i></b> processing time was <b>'||atim.tim||' sec</b></font></li>');
   END LOOP;
   
   SELECT cnt INTO l_num
   FROM (select count(*) cnt
         from event_triggers
         where et_phase_status='P');
   
   htp.p('<li><font class="TRT">there are <b>'||l_num||' <i>pending event triggers </i></b>...</font></li>');

   SELECT cnt INTO l_num
   FROM (select count(*) cnt
         from event_triggers
         where TRUNC(et_trigger_time)=TRUNC(SYSDATE));
   
   htp.p('<li><font class="TRT"><b>'||l_num||' <i>event triggers </i></b> were created today</font></li>');
   
   
   FOR hist IN (select to_char(min(et_trigger_time),'RRRR-MON-DD HH24:MI:SS') tim
                ,      'oldest' typ
                from event_triggers
                union all
                select to_char(max(et_trigger_time),'RRRR-MON-DD HH24:MI:SS') tim
                ,      'newest' typ
                from event_triggers)
   LOOP
      htp.p('<li><font class="TRT">the <b><i>'||hist.typ||'</i></b> event trigger was created on <b>'||hist.tim||'</b></font></li>');
   END LOOP;
                


   htp.p('</ul>');   
   web_std_pkg.footer;
END evnt;

      
PROCEDURE coll
IS
BEGIN
   nav('COLL');
   web_std_pkg.footer;
END coll;


PROCEDURE glob
IS
BEGIN
   nav('GLOB');
   web_std_pkg.footer;
END glob;


END web_nav_pkg;
/
show errors
