set scan off

CREATE OR REPLACE PACKAGE BODY evnt_web_pkg AS
--    2013-Nov-27   v4.1   VMOGILEVSKIY    Removed CID, PID, OID added CNT
--    2013-Nov-30   v4.2   VMOGILEVSKIY    Removed TID - moved the link to "Status" column
--    2013-Nov-30   v4.3   VMOGILEVSKIY    Changed PND link to go directly to trigger view
--    2014-Jan-14   v4.4   VMOGILEVSKIY    history - added union all to split out SQL_SCRIPT + CHK_OS_LOG
--    2014-Feb-26   v4.5   VMOGILEVSKIY    disp_triggers - increased sizes of text fields
--    2014-Apr-02   v4.6   VMOGILEVSKIY    disp_triggers - added pend_triggers_cur to speed up performace
--    2014-Apr-02   v4.7   VMOGILEVSKIY    disp_triggers - added e_triggers_cur to speed up performace
--    2014-Apr-04   v4.8   VMOGILEVSKIY    disp_triggers - added date_triggers_cur to speed up performace
--    2014-Apr-07   v4.9   VMOGILEVSKIY    disp_triggers - switched to top_sess_triggers_cur (from date_triggers_cur)
--    2014-Aug-01   v4.10  VMOGILEVSKIY    ea_form - switched to event_triggers_sum
--    2014-Aug-01   v4.11  VMOGILEVSKIY    ea_form - reversed PEND counts to use event_triggers
--    2014-Aug-01   v4.12  VMOGILEVSKIY    get_trig_output - added check for e_print_attr
--    2014-Aug-01   v4.13  VMOGILEVSKIY    ea_form - switched to using EVENT_TRIGGERS_FBI01 index for max ET_ID lookups


--
/* GLOBAL FORMATING */
   d_THC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('THC');  /* Table Header Color     */
   d_TRC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRC');  /* Table Row Color        */
   d_TRSC web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRSC'); /* Table SubRow Color        */
   d_PHCM web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCM'); /* Page Header Main Color */
   d_PHCS web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCS'); /* Page Header Sub Color  */

   d_TRC_P web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRC_P'); /* Trigger Row Color PENDING STATUS */
   d_TRC_C web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRC_C'); /* Trigger Row Color CLEARED STATUS */
   d_TRC_O web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRC_O'); /* Trigger Row Color OLD STATUS */
   d_ARC_A web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('ARC_A'); /* Assigment Row Color ACTIVE */
   d_ARC_I web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('ARC_I'); /* Assigment Row Color INACTIVE */
   d_ARC_B web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('ARC_B'); /* Assigment Row Color BROKEN */
   d_ARC_R web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('ARC_R'); /* Assigment Row Color RUNNING */

/* PRIVATE PROCS */
PROCEDURE compare_button(p_cur_id IN NUMBER)
IS
BEGIN
   htp.p('<table cellpadding="0" cellspacing="2" border="0">');
   htp.p('<tr>');

   htp.p('<td>');
   htp.p('<form method="POST" action="evnt_web_pkg.get_trigger">');
   htp.p('<input type="SUBMIT" value="Compare '||p_cur_id||' with ...">');
   htp.p('<input type="hidden" name="p_et_id" value="'||p_cur_id||'">');
   htp.p('<input type="hidden" name="p_diff_with" value="-1">');
   htp.p('</form>');
   htp.p('</td>');

   htp.p('</tr>');
   htp.p('</table>');
END compare_button;


PROCEDURE show_ea_cnt
IS
BEGIN
   web_std_pkg.header('Event System - Host Assignments');

   htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Host</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Cnt</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Action</font></TH>');

   FOR ass IN (SELECT
                  h.h_id
               ,  h.h_name
               ,  NVL(COUNT(ea_id),0) cnt
               FROM hosts h
               ,    event_assigments ea
               WHERE h.h_id = ea.h_id(+)
               GROUP BY h.h_id, h_name
               ORDER BY h_name)
   LOOP
      htp.p('<TR>');
      htp.p('<TD nowrap><font class="TRT">'||ass.h_name||'</font></TD>');
      htp.p('<TD nowrap><font class="TRT">'||ass.cnt||'</font></TD>');
      IF ass.cnt = 0 THEN
         htp.p('<TD nowrap><a href="evnt_web_pkg.ea_form?p_h_id='||ass.h_id||'&p_operation=N"><font class="TRL">Create</font></a></TD>');
      ELSE
         htp.p('<TD nowrap><a href="evnt_web_pkg.ea_form?p_h_id='||ass.h_id||'"><font class="TRL">View</font></a></TD>');
      END IF;
      htp.p('</TR>');
   END LOOP;

   htp.p('</TABLE>');
   web_std_pkg.footer;
END show_ea_cnt;


PROCEDURE event_header(
   p_e_id    IN NUMBER
,  p_colspan IN NUMBER)
IS
   CURSOR e_desc_cur IS
      SELECT e_code
      ,      e_name
      ,      DECODE(INSTR(e_code_base,'*'),0,'Local','Remote') evnt_type
      ,      DECODE(e_coll_flag,'Y','Yes','No') coll_type
      ,      REPLACE(e_code_base,'*')||'/'||e_file_name efil
      ,      REPLACE(e_desc,'<','&lt') description
      FROM events e
      WHERE e_id = p_e_id;
   e_desc e_desc_cur%ROWTYPE;
BEGIN

   OPEN e_desc_cur;
   FETCH e_desc_cur INTO e_desc;
   CLOSE e_desc_cur;

   htp.p('<TR>');
   htp.p('<TH colspan="'||p_colspan||'" ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">Event Description</font></TH>');
   htp.p('</TR>');

   htp.p('<TR>');
   htp.p('<TD colspan="'||p_colspan||'">');
   htp.p('<PRE><b>Event      </b>: '||e_desc.e_code);
   htp.p('<b>Name       </b>: '||e_desc.e_name);
   htp.p('<b>File       </b>: '||e_desc.efil);
   htp.p('<b>Agent      </b>: '||e_desc.evnt_type);
   htp.p('<b>Collection </b>: '||e_desc.coll_type);
   htp.p(' ');
   htp.p(e_desc.description);
   htp.p('</PRE>');
   htp.p('</TD>');
   htp.p('</TR>');
END event_header;

PROCEDURE get_trig_diff(
   p_trig_id_high IN NUMBER,
   p_trig_id_low  IN NUMBER)
IS
   CURSOR attributes_hl_diff_cur IS
      SELECT
        '<TD nowrap><font class="TRT">'||
        REPLACE(etd_attribute1 ,'<','&lt')   ||DECODE(etd_attribute2 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute2 ,'<','&lt')   ||DECODE(etd_attribute3 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute3 ,'<','&lt')   ||DECODE(etd_attribute4 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute4 ,'<','&lt')   ||DECODE(etd_attribute5 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute5 ,'<','&lt')   ||DECODE(etd_attribute6 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute6 ,'<','&lt')   ||DECODE(etd_attribute7 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute7 ,'<','&lt')   ||DECODE(etd_attribute8 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute8 ,'<','&lt')   ||DECODE(etd_attribute9 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute9 ,'<','&lt')   ||DECODE(etd_attribute10,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute10,'<','&lt')   ||DECODE(etd_attribute11,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute11,'<','&lt')   ||DECODE(etd_attribute12,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute12,'<','&lt')   ||DECODE(etd_attribute13,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute13,'<','&lt')   ||DECODE(etd_attribute14,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute14,'<','&lt')   ||DECODE(etd_attribute15,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute15,'<','&lt')   ||DECODE(etd_attribute16,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute16,'<','&lt')   ||DECODE(etd_attribute17,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute17,'<','&lt')   ||DECODE(etd_attribute18,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute18,'<','&lt')   ||DECODE(etd_attribute19,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute19,'<','&lt')   ||DECODE(etd_attribute20,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute20,'<','&lt')   ||'</TD>' output_line
      FROM event_trigger_details
      WHERE et_id = p_trig_id_high
      MINUS
      SELECT
        '<TD nowrap><font class="TRT">'||
        REPLACE(etd_attribute1 ,'<','&lt')   ||DECODE(etd_attribute2 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute2 ,'<','&lt')   ||DECODE(etd_attribute3 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute3 ,'<','&lt')   ||DECODE(etd_attribute4 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute4 ,'<','&lt')   ||DECODE(etd_attribute5 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute5 ,'<','&lt')   ||DECODE(etd_attribute6 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute6 ,'<','&lt')   ||DECODE(etd_attribute7 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute7 ,'<','&lt')   ||DECODE(etd_attribute8 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute8 ,'<','&lt')   ||DECODE(etd_attribute9 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute9 ,'<','&lt')   ||DECODE(etd_attribute10,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute10,'<','&lt')   ||DECODE(etd_attribute11,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute11,'<','&lt')   ||DECODE(etd_attribute12,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute12,'<','&lt')   ||DECODE(etd_attribute13,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute13,'<','&lt')   ||DECODE(etd_attribute14,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute14,'<','&lt')   ||DECODE(etd_attribute15,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute15,'<','&lt')   ||DECODE(etd_attribute16,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute16,'<','&lt')   ||DECODE(etd_attribute17,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute17,'<','&lt')   ||DECODE(etd_attribute18,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute18,'<','&lt')   ||DECODE(etd_attribute19,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute19,'<','&lt')   ||DECODE(etd_attribute20,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute20,'<','&lt')   ||'</TD>' output_line
      FROM event_trigger_details
      WHERE et_id = p_trig_id_low
      ORDER BY 1;

   CURSOR attributes_lh_diff_cur IS
      SELECT
        '<TD nowrap><font class="TRT">'||
        REPLACE(etd_attribute1 ,'<','&lt')   ||DECODE(etd_attribute2 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute2 ,'<','&lt')   ||DECODE(etd_attribute3 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute3 ,'<','&lt')   ||DECODE(etd_attribute4 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute4 ,'<','&lt')   ||DECODE(etd_attribute5 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute5 ,'<','&lt')   ||DECODE(etd_attribute6 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute6 ,'<','&lt')   ||DECODE(etd_attribute7 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute7 ,'<','&lt')   ||DECODE(etd_attribute8 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute8 ,'<','&lt')   ||DECODE(etd_attribute9 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute9 ,'<','&lt')   ||DECODE(etd_attribute10,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute10,'<','&lt')   ||DECODE(etd_attribute11,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute11,'<','&lt')   ||DECODE(etd_attribute12,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute12,'<','&lt')   ||DECODE(etd_attribute13,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute13,'<','&lt')   ||DECODE(etd_attribute14,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute14,'<','&lt')   ||DECODE(etd_attribute15,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute15,'<','&lt')   ||DECODE(etd_attribute16,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute16,'<','&lt')   ||DECODE(etd_attribute17,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute17,'<','&lt')   ||DECODE(etd_attribute18,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute18,'<','&lt')   ||DECODE(etd_attribute19,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute19,'<','&lt')   ||DECODE(etd_attribute20,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute20,'<','&lt')   ||'</TD>' output_line
      FROM event_trigger_details
      WHERE et_id = p_trig_id_low
      MINUS
      SELECT
        '<TD nowrap><font class="TRT">'||
        REPLACE(etd_attribute1 ,'<','&lt')   ||DECODE(etd_attribute2 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute2 ,'<','&lt')   ||DECODE(etd_attribute3 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute3 ,'<','&lt')   ||DECODE(etd_attribute4 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute4 ,'<','&lt')   ||DECODE(etd_attribute5 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute5 ,'<','&lt')   ||DECODE(etd_attribute6 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute6 ,'<','&lt')   ||DECODE(etd_attribute7 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute7 ,'<','&lt')   ||DECODE(etd_attribute8 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute8 ,'<','&lt')   ||DECODE(etd_attribute9 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute9 ,'<','&lt')   ||DECODE(etd_attribute10,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute10,'<','&lt')   ||DECODE(etd_attribute11,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute11,'<','&lt')   ||DECODE(etd_attribute12,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute12,'<','&lt')   ||DECODE(etd_attribute13,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute13,'<','&lt')   ||DECODE(etd_attribute14,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute14,'<','&lt')   ||DECODE(etd_attribute15,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute15,'<','&lt')   ||DECODE(etd_attribute16,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute16,'<','&lt')   ||DECODE(etd_attribute17,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute17,'<','&lt')   ||DECODE(etd_attribute18,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute18,'<','&lt')   ||DECODE(etd_attribute19,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute19,'<','&lt')   ||DECODE(etd_attribute20,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute20,'<','&lt')   ||'</TD>' output_line
      FROM event_trigger_details
      WHERE et_id = p_trig_id_high
      ORDER BY 1;

BEGIN
   htp.p('<TR>');
   htp.p('<TD ALIGN="left" bgcolor='||d_PHCS||' height=15 colspan="22"><font color="#000000" size="2" face="Arial">&nbsp;[NEW VALUES] ('||p_trig_id_high||'-'||p_trig_id_low||') Trigger Attribute Comparison:</font></TD>');
   htp.p('</TR>');

   FOR attributes_hl_diff IN attributes_hl_diff_cur LOOP
      htp.p('<TR>');
      htp.p(attributes_hl_diff.output_line);
      htp.p('</TR>');
   END LOOP;

   htp.p('<TR>');
   htp.p('<TD ALIGN="left" height=15 colspan="22">&nbsp;</TD>');
   htp.p('</TR>');
   htp.p('<TR>');
   htp.p('<TD ALIGN="left" bgcolor='||d_PHCS||' height=15 colspan="22"><font color="#000000" size="2" face="Arial">&nbsp;[OLD VALUES] ('||p_trig_id_low||'-'||p_trig_id_high||') Trigger Attribute Comparison:</font></TD>');
   htp.p('</TR>');

   FOR attributes_lh_diff IN attributes_lh_diff_cur LOOP
      htp.p('<TR>');
      htp.p(attributes_lh_diff.output_line);
      htp.p('</TR>');
   END LOOP;
   htp.p('<TR>');
   htp.p('<TD ALIGN="left" height=15 colspan="22">&nbsp;</TD>');
   htp.p('</TR>');

END get_trig_diff;


PROCEDURE get_trig_output(
   p_trig_id IN NUMBER
,  p_prev_id IN NUMBER DEFAULT NULL)
IS
   CURSOR attributes_cur IS
      SELECT
        '<TD nowrap><font class="TRT">'||
        REPLACE(etd_attribute1 ,'<','&lt')   ||DECODE(etd_attribute2 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute2 ,'<','&lt')   ||DECODE(etd_attribute3 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute3 ,'<','&lt')   ||DECODE(etd_attribute4 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute4 ,'<','&lt')   ||DECODE(etd_attribute5 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute5 ,'<','&lt')   ||DECODE(etd_attribute6 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute6 ,'<','&lt')   ||DECODE(etd_attribute7 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute7 ,'<','&lt')   ||DECODE(etd_attribute8 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute8 ,'<','&lt')   ||DECODE(etd_attribute9 ,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute9 ,'<','&lt')   ||DECODE(etd_attribute10,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute10,'<','&lt')   ||DECODE(etd_attribute11,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute11,'<','&lt')   ||DECODE(etd_attribute12,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute12,'<','&lt')   ||DECODE(etd_attribute13,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute13,'<','&lt')   ||DECODE(etd_attribute14,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute14,'<','&lt')   ||DECODE(etd_attribute15,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute15,'<','&lt')   ||DECODE(etd_attribute16,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute16,'<','&lt')   ||DECODE(etd_attribute17,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute17,'<','&lt')   ||DECODE(etd_attribute18,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute18,'<','&lt')   ||DECODE(etd_attribute19,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute19,'<','&lt')   ||DECODE(etd_attribute20,NULL,NULL,'</TD><TD nowrap><font class="TRT">')||
        REPLACE(etd_attribute20,'<','&lt')   ||'</TD>' output_line
      FROM event_trigger_details
      WHERE et_id = p_trig_id
      ORDER BY etd_id;

   CURSOR output_cur IS
      SELECT eto_output_line
      FROM   event_trigger_output
      WHERE  et_id = p_trig_id
      ORDER BY eto_id;

    l_print_attr events.e_print_attr%type;

BEGIN

   select e_print_attr into l_print_attr
     from events
    where e_id = (select e_id from event_triggers where et_id = p_trig_id);

   if ( l_print_attr = 'Y' )
   then
       htp.p('<TABLE  cellpadding=0 cellspacing=0 border=1>');

       IF p_prev_id IS NOT NULL AND
          p_prev_id != p_trig_id THEN

          get_trig_diff(p_trig_id,p_prev_id);
       END IF;

       htp.p('<TR>');
       htp.p('<TD ALIGN="left" bgcolor='||d_PHCS||' height=15 colspan="22"><font color="#000000" size="2" face="Arial">&nbsp;[ALL VALUES] ('||p_trig_id||') Trigger Attributes:</font></TD>');
       htp.p('</TR>');
       FOR attributes IN attributes_cur LOOP
          htp.p('<TR>');
          htp.p(attributes.output_line);
          htp.p('</TR>');
       END LOOP;

       htp.p('</TABLE>');

       htp.p('<BR>');
   end if;


   htp.p('<TABLE  cellpadding=0 cellspacing=0 border=1>');
   htp.p('<TR>');
   htp.p('<TD ALIGN="left" bgcolor='||d_PHCS||' height=15><font color="#000000" size="2" face="Arial">&nbsp;('||p_trig_id||') Trigger Output:</font></TD>');
   htp.p('</TR>');

   htp.p('<TR>');
   htp.p('<TD>');
   htp.p('<PRE>');
   FOR output IN output_cur LOOP
      -- VM 02/03/2003
      --   "<" char needs to be replaced
      --   to avoid meesing up HTML
      htp.p(REPLACE(output.eto_output_line,'<','&lt'));
   END LOOP;
   htp.p('</PRE>');
   htp.p('</TD>');
   htp.p('</TR>');

   htp.p('</TABLE>');

END get_trig_output;



/* PUBLIC MODULES */

PROCEDURE disp_triggers(
   p_h_id  IN VARCHAR2 DEFAULT 'x'
,  p_s_id  IN VARCHAR2 DEFAULT 'x'
,  p_phase IN VARCHAR2 DEFAULT 'x'
,  p_date  IN VARCHAR  DEFAULT NULL
,  p_ea_id IN VARCHAR2 DEFAULT 'x'
,  p_ep_id IN VARCHAR2 DEFAULT 'x'
,  p_e_id  IN VARCHAR2 DEFAULT 'x'
,  p_ack_flag IN VARCHAR2 DEFAULT 'x'
,  p_evnt_cnt in VARCHAR2 default null
,  p_target   in VARCHAR2 default null
,  p_attr_search in VARCHAR2 default null)
IS

    -- WARNING: top_sess_triggers_cur relies on this index:
    --
    -- drop index etd_dbtopses_fbi01;
    -- create index etd_dbtopses_fbi01
    -- on event_trigger_details
    -- ( case when etd_status like '%TOP_SESS%' then to_char(etd_trigger_time,'RRRR-MON-DD') end,
    --   case when etd_status like '%TOP_SESS%' then et_id end,
    --   case when etd_status like '%TOP_SESS%' then etd_attribute1 end )
    -- local;

   l_top_sess_e_id events.e_id%type;
   CURSOR top_sess_triggers_cur IS
      SELECT
         target
      ,  TO_CHAR(et_trigger_time,'MON-DD HH24:MI:SS') trigger_time
      ,  DECODE(et_status,'CLEARED',et_prev_status||' - CLEARED',et_status) et_status
      --,  ep_desc
      ,  et.last_update_by
      ,  e_id
      ,  ep_id
      ,  et.et_id
      ,  et_orig_et_id
      ,  et_clr_et_id
      ,  et_prev_et_id
      --,  et_prev_status
      ,  phase
      ,  mail
      ,  et_ack_flag
      ,  et_ack_date
      ,  TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS') et_ack_date_char
      ,  DECODE(et_ack_flag,
            'Y',DECODE(et_ack_date,
                   NULL,'<TD nowrap BGCOLOR="'||d_ARC_B||'">'||
                        '<a href="evnt_web_pkg.ack_one_trig?p_et_id='||
                        et.et_id||
                        '" target="NEW_W"><font class="TRL">'||
                        'Ackonowledge Now'||
                        '</font></a></TD>'
                       /* other in NULL */
                       ,'<TD nowrap BGCOLOR="'||d_ARC_R||'">'||
                        '<font class="TRL">'||
                        NVL(a.a_name,'UNKNOWN')||
                        '('||
                        TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS')||
                        ')'||
                        '</font></a></TD>'
                )
                /* other in 'Y' */
                ,'<TD nowrap>'||
                 '<font class="TRL">'||
                 'Not Required'||
                 '</font></a></TD>'
         ) html_ack
      ,  a.a_name ack_by_name
      ,  d.attr_cnt
      FROM event_triggers_all_v et
      ,    admins a
      ,    (select count(*) attr_cnt, et_id
              from event_trigger_details
             group by et_id) d
      WHERE TRUNC(et_trigger_time) = TO_DATE(p_date,'RRRR-MON-DD')
      and   et.et_ack_by_a_id = a.a_id(+)
      and   et.et_id = d.et_id(+)
      and   nvl(d.attr_cnt,0) >= DECODE(p_evnt_cnt,null,0,p_evnt_cnt)
      and   target like decode(p_target,null,'%',p_target)
      and   et.et_id in (select distinct et_id
              from event_trigger_details etd
             where case when etd_status like '%TOP_SESS%' then to_char(etd_trigger_time,'RRRR-MON-DD') end = p_date
               and case when etd_status like '%TOP_SESS%' then etd_attribute1 end like p_attr_search)
      ORDER BY et_trigger_time desc, et.et_id desc;

   CURSOR e_triggers_cur IS
      SELECT
         target
      ,  TO_CHAR(et_trigger_time,'MON-DD HH24:MI:SS') trigger_time
      ,  DECODE(et_status,'CLEARED',et_prev_status||' - CLEARED',et_status) et_status
      --,  ep_desc
      ,  et.last_update_by
      ,  e_id
      ,  ep_id
      ,  et.et_id
      ,  et_orig_et_id
      ,  et_clr_et_id
      ,  et_prev_et_id
      --,  et_prev_status
      ,  phase
      ,  mail
      ,  et_ack_flag
      ,  et_ack_date
      ,  TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS') et_ack_date_char
      ,  DECODE(et_ack_flag,
            'Y',DECODE(et_ack_date,
                   NULL,'<TD nowrap BGCOLOR="'||d_ARC_B||'">'||
                        '<a href="evnt_web_pkg.ack_one_trig?p_et_id='||
                        et.et_id||
                        '" target="NEW_W"><font class="TRL">'||
                        'Ackonowledge Now'||
                        '</font></a></TD>'
                       /* other in NULL */
                       ,'<TD nowrap BGCOLOR="'||d_ARC_R||'">'||
                        '<font class="TRL">'||
                        NVL(a.a_name,'UNKNOWN')||
                        '('||
                        TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS')||
                        ')'||
                        '</font></a></TD>'
                )
                /* other in 'Y' */
                ,'<TD nowrap>'||
                 '<font class="TRL">'||
                 'Not Required'||
                 '</font></a></TD>'
         ) html_ack
      ,  a.a_name ack_by_name
      ,  d.attr_cnt
      FROM event_triggers_all_v et
      ,    admins a
      ,    (select count(*) attr_cnt, et_id
              from event_trigger_details
             group by et_id) d
      WHERE e_id = p_e_id
      AND   TRUNC(et_trigger_time) = TO_DATE(p_date,'RRRR-MON-DD')
      AND   et.et_ack_by_a_id = a.a_id(+)
      and   et.et_id = d.et_id(+)
      and   nvl(d.attr_cnt,0) >= DECODE(p_evnt_cnt,null,0,p_evnt_cnt)
      and   target like decode(p_target,null,'%',p_target)
      and    exists (select 1
                       from dual
                      where et.et_status = 'CLEARED'
                        and p_attr_search is null
                      union all
                     select 1
                       from event_trigger_details etd
                      where etd.et_id = et.et_id
                        and etd.etd_attribute1   ||' '||
                            etd.etd_attribute2   ||' '||
                            etd.etd_attribute3   ||' '||
                            etd.etd_attribute4   ||' '||
                            etd.etd_attribute5   ||' '||
                            etd.etd_attribute6   ||' '||
                            etd.etd_attribute7   ||' '||
                            etd.etd_attribute8   ||' '||
                            etd.etd_attribute9   ||' '||
                            etd.etd_attribute10  ||' '||
                            etd.etd_attribute11  ||' '||
                            etd.etd_attribute12  ||' '||
                            etd.etd_attribute13  ||' '||
                            etd.etd_attribute14  ||' '||
                            etd.etd_attribute15  ||' '||
                            etd.etd_attribute16  ||' '||
                            etd.etd_attribute17  ||' '||
                            etd.etd_attribute18  ||' '||
                            etd.etd_attribute19  ||' '||
                            etd.etd_attribute20  like decode(p_attr_search,null,'%',p_attr_search)
                        and rownum = 1)
      ORDER BY et_trigger_time desc, et.et_id desc;


   CURSOR pend_triggers_cur IS
      SELECT
         target
      ,  TO_CHAR(et_trigger_time,'MON-DD HH24:MI:SS') trigger_time
      ,  DECODE(et_status,'CLEARED',et_prev_status||' - CLEARED',et_status) et_status
      --,  ep_desc
      ,  et.last_update_by
      ,  e_id
      ,  ep_id
      ,  et.et_id
      ,  et_orig_et_id
      ,  et_clr_et_id
      ,  et_prev_et_id
      --,  et_prev_status
      ,  phase
      ,  mail
      ,  et_ack_flag
      ,  et_ack_date
      ,  TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS') et_ack_date_char
      ,  DECODE(et_ack_flag,
            'Y',DECODE(et_ack_date,
                   NULL,'<TD nowrap BGCOLOR="'||d_ARC_B||'">'||
                        '<a href="evnt_web_pkg.ack_one_trig?p_et_id='||
                        et.et_id||
                        '" target="NEW_W"><font class="TRL">'||
                        'Ackonowledge Now'||
                        '</font></a></TD>'
                       /* other in NULL */
                       ,'<TD nowrap BGCOLOR="'||d_ARC_R||'">'||
                        '<font class="TRL">'||
                        NVL(a.a_name,'UNKNOWN')||
                        '('||
                        TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS')||
                        ')'||
                        '</font></a></TD>'
                )
                /* other in 'Y' */
                ,'<TD nowrap>'||
                 '<font class="TRL">'||
                 'Not Required'||
                 '</font></a></TD>'
         ) html_ack
      ,  a.a_name ack_by_name
      ,  d.attr_cnt
      FROM event_triggers_all_v et
      ,    admins a
      ,    (select count(*) attr_cnt, et_id
              from event_trigger_details
             group by et_id) d
      WHERE et_pending = 'P'
      AND   et.et_ack_by_a_id = a.a_id(+)
      and   et.et_id = d.et_id(+)
      ORDER BY et_trigger_time desc, et.et_id desc;

   CURSOR triggers_cur IS
      SELECT
         target
      ,  TO_CHAR(et_trigger_time,'MON-DD HH24:MI:SS') trigger_time
      ,  DECODE(et_status,'CLEARED',et_prev_status||' - CLEARED',et_status) et_status
      --,  ep_desc
      ,  et.last_update_by
      ,  e_id
      ,  ep_id
      ,  et.et_id
      ,  et_orig_et_id
      ,  et_clr_et_id
      ,  et_prev_et_id
      --,  et_prev_status
      ,  phase
      ,  mail
      ,  et_ack_flag
      ,  et_ack_date
      ,  TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS') et_ack_date_char
      ,  DECODE(et_ack_flag,
            'Y',DECODE(et_ack_date,
                   NULL,'<TD nowrap BGCOLOR="'||d_ARC_B||'">'||
                        '<a href="evnt_web_pkg.ack_one_trig?p_et_id='||
                        et.et_id||
                        '" target="NEW_W"><font class="TRL">'||
                        'Ackonowledge Now'||
                        '</font></a></TD>'
                       /* other in NULL */
                       ,'<TD nowrap BGCOLOR="'||d_ARC_R||'">'||
                        '<font class="TRL">'||
                        NVL(a.a_name,'UNKNOWN')||
                        '('||
                        TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS')||
                        ')'||
                        '</font></a></TD>'
                )
                /* other in 'Y' */
                ,'<TD nowrap>'||
                 '<font class="TRL">'||
                 'Not Required'||
                 '</font></a></TD>'
         ) html_ack
      ,  a.a_name ack_by_name
      ,  d.attr_cnt
      FROM event_triggers_all_v et
      ,    admins a
      ,    (select count(*) attr_cnt, et_id
              from event_trigger_details
             group by et_id) d
      WHERE DECODE(p_phase,'x','x',phase) = p_phase
      AND   DECODE(p_h_id,'x','x',h_id)   = p_h_id
      AND   DECODE(p_s_id,'x','x',s_id)   = p_s_id
      AND   DECODE(p_ea_id,'x','x',ea_id) = p_ea_id
      AND   DECODE(p_ep_id,'x','x',ep_id) = p_ep_id
      AND   DECODE(p_e_id,'x','x',e_id) = p_e_id
      /*
       * P_ACK_FLAG
       *    P = Pending acks:
       *       et_ack_flag='Y'
       *       et_ack_date IS NULL
       *
       *    C = Closed acks:
       *       et_ack_flag='Y'
       *       et_ack_date IS NOT NULL
       */
      AND   DECODE(p_ack_flag,'x','x',et_ack_flag) = DECODE(p_ack_flag,'x','x','Y')
      AND   DECODE(p_ack_flag,'P',et_ack_date,NULL) IS NULL
      AND   DECODE(p_ack_flag,'C',et_ack_date,SYSDATE) IS NOT NULL
      --AND   DECODE(p_date,NULL,TRUNC(SYSDATE),TRUNC(NVL(et.date_modified,et_trigger_time))) = TO_DATE(NVL(p_date,TO_CHAR(SYSDATE,'RRRR-MON-DD')),'RRRR-MON-DD')
      AND   DECODE(p_date,NULL,TRUNC(SYSDATE),TRUNC(et_trigger_time)) = TO_DATE(NVL(p_date,TO_CHAR(SYSDATE,'RRRR-MON-DD')),'RRRR-MON-DD')
      AND   et.et_ack_by_a_id = a.a_id(+)
      and   et.et_id = d.et_id(+)
      and   nvl(d.attr_cnt,0) >= DECODE(p_evnt_cnt,null,0,p_evnt_cnt)
      and   target like decode(p_target,null,'%',p_target)
      and    exists (select 1
                       from dual
                      where et.et_status = 'CLEARED'
                        and p_attr_search is null
                      union all
                     select 1
                       from event_trigger_details etd
                      where etd.et_id = et.et_id
                        and etd.etd_attribute1   ||' '||
                            etd.etd_attribute2   ||' '||
                            etd.etd_attribute3   ||' '||
                            etd.etd_attribute4   ||' '||
                            etd.etd_attribute5   ||' '||
                            etd.etd_attribute6   ||' '||
                            etd.etd_attribute7   ||' '||
                            etd.etd_attribute8   ||' '||
                            etd.etd_attribute9   ||' '||
                            etd.etd_attribute10  ||' '||
                            etd.etd_attribute11  ||' '||
                            etd.etd_attribute12  ||' '||
                            etd.etd_attribute13  ||' '||
                            etd.etd_attribute14  ||' '||
                            etd.etd_attribute15  ||' '||
                            etd.etd_attribute16  ||' '||
                            etd.etd_attribute17  ||' '||
                            etd.etd_attribute18  ||' '||
                            etd.etd_attribute19  ||' '||
                            etd.etd_attribute20  like decode(p_attr_search,null,'%',p_attr_search)
                        and rownum = 1)
      ORDER BY et_trigger_time desc, et.et_id desc;

   triggers triggers_cur%ROWTYPE;

   -- only return count of pend acks
   -- if p_ack_flag='P' since it's
   -- possible that a trigger is already
   -- closed but unacknowledged
   --
   CURSOR unack_trg_cur IS
      SELECT COUNT(et_id) cnt
      FROM event_triggers
      WHERE et_ack_date IS NULL
      AND   et_ack_flag='Y'
      AND   p_ack_flag = 'P';
   unack_trg unack_trg_cur%ROWTYPE;


   CURSOR head_m_type_cur IS
      SELECT
         DECODE(p_phase,'P','- Pending','C','- Cleared','O','- Old',' -') output
      FROM dual;
   head_m_type head_m_type_cur%ROWTYPE;


   CURSOR head_m_host_cur IS
      SELECT
         DECODE(h_name,NULL,NULL,' For '||h_name) output
      FROM hosts
      WHERE h_id = TO_NUMBER(DECODE(p_h_id,'x','-1',p_h_id));
   head_m_host head_m_host_cur%ROWTYPE;

   CURSOR head_m_sid_cur IS
      SELECT
         DECODE(s_name,NULL,NULL,':'||s_name) output
      FROM sids
      WHERE s_id = TO_NUMBER(DECODE(p_s_id,'x','-1',p_s_id));
   head_m_sid head_m_sid_cur%ROWTYPE;


   CURSOR head_m_date_cur IS
   SELECT
      DECODE(p_ea_id,'x',NULL,' assigment id='||p_ea_id)||
      DECODE(p_ep_id,'x',NULL,' event parameter id='||p_ep_id)||
      DECODE(p_date,NULL,NULL,' created/modified ON '||p_date) output
   FROM dual;
   head_m_date head_m_date_cur%ROWTYPE;

   CURSOR notif_cnt_cur(p_et_id IN NUMBER) IS
      SELECT COUNT(et_id) value
      FROM event_trigger_notif
      WHERE et_id = p_et_id;
   notif_cnt notif_cnt_cur%ROWTYPE;

   CURSOR notes_cnt_cur(p_et_id IN NUMBER) IS
      SELECT DECODE(COUNT(tn_id),0,'Add','View') value
      FROM event_trigger_notes
      WHERE et_id = p_et_id;
   notes_cnt notes_cnt_cur%ROWTYPE;

   l_head_message VARCHAR2(256);
BEGIN
   OPEN head_m_type_cur;
   FETCH head_m_type_cur INTO head_m_type;
   CLOSE head_m_type_cur;

   OPEN head_m_host_cur;
   FETCH head_m_host_cur INTO head_m_host;
   CLOSE head_m_host_cur;

   OPEN head_m_sid_cur;
   FETCH head_m_sid_cur INTO head_m_sid;
   CLOSE head_m_sid_cur;

   OPEN head_m_date_cur;
   FETCH head_m_date_cur INTO head_m_date;
   CLOSE head_m_date_cur;

   l_head_message := 'Event System '||
                     head_m_type.output||
                     ' Triggers '||
                     head_m_host.output||
                     head_m_sid.output||
                     head_m_date.output;

   web_std_pkg.header(l_head_message);

   -- check for unack trigs
   -- if any are present give link
   -- to ack them all
   OPEN unack_trg_cur;
   FETCH unack_trg_cur INTO unack_trg;
   CLOSE unack_trg_cur;
   IF unack_trg.cnt > 0 THEN
      htp.p('<a href="evnt_web_pkg.ack_all_trigs" target="NEW_W"><font class="TRL">Acknowledge All</font></a>');
   END IF;

   -- check if p_date is present
   -- if so allow for date stepping
   IF p_date IS NOT NULL THEN
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');
      htp.p('<tr>');

      -- day back
      htp.p('<td>');
      htp.p('<form method="POST" action="evnt_web_pkg.disp_triggers">');
      htp.p('<input type="SUBMIT" value="'||TO_CHAR(TO_DATE(p_date,'RRRR-MON-DD')-1,'RRRR-MON-DD')||' <<<">');
      htp.p('<input type="hidden" name="p_date" value="'||TO_CHAR(TO_DATE(p_date,'RRRR-MON-DD')-1,'RRRR-MON-DD')||'">');
      htp.p('<input type="hidden" name="p_h_id" value="'||p_h_id||'">');
      htp.p('<input type="hidden" name="p_s_id" value="'||p_s_id||'">');
      htp.p('<input type="hidden" name="p_phase" value="'||p_phase||'">');
      htp.p('<input type="hidden" name="p_ea_id" value="'||p_ea_id||'">');
      htp.p('<input type="hidden" name="p_ep_id" value="'||p_ep_id||'">');
      htp.p('<input type="hidden" name="p_e_id" value="'||p_e_id||'">');
      htp.p('<input type="hidden" name="p_ack_flag" value="'||p_ack_flag||'">');
      htp.p('<input type="hidden" name="p_evnt_cnt" value="'||p_evnt_cnt||'">');
      htp.p('<input type="hidden" name="p_target" value="'||p_target||'">');
      htp.p('<input type="hidden" name="p_attr_search" value="'||p_attr_search||'">');
      htp.p('</form>');
      htp.p('</td>');

      -- refresh current day
      htp.p('<td>');
      htp.p('<form method="POST" action="evnt_web_pkg.disp_triggers">');
      htp.p('<input type=text name=p_date size=11 maxlength=11 value="'||p_date||'">');
      htp.p('<font class="TRT">Cnt:</font><input type=text name=p_evnt_cnt size=5 maxlength=11 value="'||p_evnt_cnt||'">');
      htp.p('<font class="TRT">Target:</font><input type=text name=p_target size=15 maxlength=30 value="'||p_target||'">');
      htp.p('<font class="TRT">Search:</font><input type=text name=p_attr_search size=20 maxlength=100 value="'||p_attr_search||'">');
      htp.p('<input type="SUBMIT" value="Refresh">');
      htp.p('<input type="hidden" name="p_h_id" value="'||p_h_id||'">');
      htp.p('<input type="hidden" name="p_s_id" value="'||p_s_id||'">');
      htp.p('<input type="hidden" name="p_phase" value="'||p_phase||'">');
      htp.p('<input type="hidden" name="p_ea_id" value="'||p_ea_id||'">');
      htp.p('<input type="hidden" name="p_ep_id" value="'||p_ep_id||'">');
      htp.p('<input type="hidden" name="p_e_id" value="'||p_e_id||'">');
      htp.p('<input type="hidden" name="p_ack_flag" value="'||p_ack_flag||'">');
      htp.p('</form>');
      htp.p('</td>');

      -- day forward
      htp.p('<td>');
      htp.p('<form method="POST" action="evnt_web_pkg.disp_triggers">');
      htp.p('<input type="SUBMIT" value=">>> '||TO_CHAR(TO_DATE(p_date,'RRRR-MON-DD')+1,'RRRR-MON-DD')||'">');
      htp.p('<input type="hidden" name="p_date" value="'||TO_CHAR(TO_DATE(p_date,'RRRR-MON-DD')+1,'RRRR-MON-DD')||'">');
      htp.p('<input type="hidden" name="p_h_id" value="'||p_h_id||'">');
      htp.p('<input type="hidden" name="p_s_id" value="'||p_s_id||'">');
      htp.p('<input type="hidden" name="p_phase" value="'||p_phase||'">');
      htp.p('<input type="hidden" name="p_ea_id" value="'||p_ea_id||'">');
      htp.p('<input type="hidden" name="p_ep_id" value="'||p_ep_id||'">');
      htp.p('<input type="hidden" name="p_e_id" value="'||p_e_id||'">');
      htp.p('<input type="hidden" name="p_ack_flag" value="'||p_ack_flag||'">');
      htp.p('<input type="hidden" name="p_evnt_cnt" value="'||p_evnt_cnt||'">');
      htp.p('<input type="hidden" name="p_target" value="'||p_target||'">');
      htp.p('<input type="hidden" name="p_attr_search" value="'||p_attr_search||'">');
      htp.p('</form>');
      htp.p('</td>');

      htp.p('</tr>');
      htp.p('</table>');
   END IF;


   htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Target</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Trigger</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Time</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Status</font></TH>');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">TID</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">CNT</font></TH>');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">OID</font></TH>');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">CID</font></TH>');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">PID</font></TH>');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">TID-PID<br>DIFF.</font></TH>');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Description</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Acknowledgement</font></TH> ');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">AckBy</font></TH> ');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">AckDate</font></TH> ');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">NOTIF</font></TH> ');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">NOTES</font></TH> ');
   --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Prev Status</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">P</font></TH>      ');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">M</font></TH>     ');


   -- htp.p('p_phase    ='|| DECODE(p_phase,'x','x',p_phase));
   -- htp.p('p_h_id     ='|| DECODE(p_h_id,'x','x',p_h_id)  );
   -- htp.p('p_s_id     ='|| DECODE(p_s_id,'x','x',p_s_id)  );
   -- htp.p('p_ea_id    ='|| DECODE(p_ea_id,'x','x',p_ea_id));
   -- htp.p('p_ep_id    ='|| DECODE(p_ep_id,'x','x',p_ep_id));
   -- htp.p('p_e_id     ='|| DECODE(p_e_id,'x','x',p_e_id));
   -- htp.p('p_ack_flag ='|| DECODE(p_ack_flag,'x','x','Y') );
   -- htp.p('p_ack_flag ='|| DECODE(p_ack_flag,'P','et_ack_date IS NULL','NULL')                                 );
   -- htp.p('p_ack_flag ='|| DECODE(p_ack_flag,'C','et_ack_date IS NOT NULL','SYSDATE')                          );
   -- htp.p('p_date     ='|| DECODE(p_date,NULL,'TRUNC(SYSDATE)','TRUNC(NVL(et.date_modified,et_trigger_time))') );


    /*
    ||     p_h_id  IN VARCHAR2 DEFAULT 'x'
    ||     p_s_id  IN VARCHAR2 DEFAULT 'x'
    ||     p_phase IN VARCHAR2 DEFAULT 'x'
    ||     p_date  IN VARCHAR  DEFAULT NULL
    ||     p_ea_id IN VARCHAR2 DEFAULT 'x'
    ||     p_ep_id IN VARCHAR2 DEFAULT 'x'
    ||     p_e_id  IN VARCHAR2 DEFAULT 'x'
    ||     p_ack_flag IN VARCHAR2 DEFAULT 'x'
    */

    select e_id into l_top_sess_e_id
      from events where e_file_name = 'dbtopses.sh';

    if ( ( p_e_id != 'x' ) and
         ( p_e_id = l_top_sess_e_id ) and
         ( p_date is not null ) and
         ( p_attr_search is not null ) )
    then
        open top_sess_triggers_cur;

    elsif ( p_phase = 'P' )
    then
        open pend_triggers_cur;

    elsif ( ( p_e_id != 'x' ) and
            ( p_date is not null ) )
    then
        open e_triggers_cur;

    else
        open triggers_cur;
    end if;

    LOOP
        if ( ( p_e_id != 'x' ) and
             ( p_e_id = l_top_sess_e_id ) and
             ( p_date is not null ) and
             ( p_attr_search is not null ) )
        then
            fetch top_sess_triggers_cur into triggers;
            EXIT WHEN top_sess_triggers_cur%NOTFOUND;

        elsif ( p_phase = 'P' )
        then
            fetch pend_triggers_cur into triggers;
            EXIT WHEN pend_triggers_cur%NOTFOUND;

        elsif ( ( p_e_id != 'x' ) and
                ( p_date is not null ) )
        then
            fetch e_triggers_cur into triggers;
            EXIT WHEN e_triggers_cur%NOTFOUND;

        else
            fetch triggers_cur into triggers;
            EXIT WHEN triggers_cur%NOTFOUND;
        end if;

        OPEN notif_cnt_cur(triggers.et_id);
        FETCH notif_cnt_cur INTO notif_cnt;
        CLOSE notif_cnt_cur;

        OPEN notes_cnt_cur(triggers.et_id);
        FETCH notes_cnt_cur INTO notes_cnt;
        CLOSE notes_cnt_cur;


        htp.p('<TR>');
        htp.p('<TD nowrap><font class="TRT">'||triggers.target||'</font></TD>');
        htp.p('<TD nowrap><font class="TRT">'||triggers.et_id||'</font></TD>');
        htp.p('<TD nowrap><font class="TRT">'||triggers.trigger_time||'</font></TD>');
        --htp.p('<TD nowrap><a href="evnt_web_pkg.epv_form?p_ep_id='||triggers.ep_id||'&p_e_id='||triggers.e_id||'"><font class="TRL">'||triggers.et_status||'</font></a></TD>');
        htp.p('<TD nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||triggers.et_id||'"><font class="TRL">'||triggers.et_status||'</font></a></TD>');
        --htp.p('<TD nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||triggers.et_id||'"><font class="TRL">'||triggers.et_id||'</font></a></TD>');
        htp.p('<TD nowrap><font class="TRL">'||triggers.attr_cnt||'</font></TD>');

        --htp.p('<TD nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||triggers.et_orig_et_id||'"><font class="TRL">'||triggers.et_orig_et_id||'</font></a></TD>');
        --htp.p('<TD nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||triggers.et_clr_et_id ||'"><font class="TRL">'||triggers.et_clr_et_id ||'</font></a></TD>');
        --htp.p('<TD nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||triggers.et_prev_et_id||'"><font class="TRL">'||triggers.et_prev_et_id||'</font></a></TD>');
        --htp.p('<TD nowrap><a href="evnt_web_pkg.get_trig_diff?p_trig_id_high='||triggers.et_id||'&p_trig_id_low='||triggers.et_prev_et_id||'" target="NEW_W"><font class="TRL">'||triggers.et_id||'-'||triggers.et_prev_et_id||'</font></a></TD>');
        htp.p(triggers.html_ack);
        --htp.p('<TD nowrap><font class="TRT">'||triggers.et_ack_flag||'</font></TD>');
        --htp.p('<TD nowrap><font class="TRT">'||triggers.ack_by_name||'</font></TD>');
        --htp.p('<TD nowrap><font class="TRT">'||triggers.et_ack_date_char||'</font></TD>');
        --htp.p('<TD nowrap><font class="TRT">'||triggers.et_status||'</font></TD>');
        --htp.p('<TD nowrap><font class="TRT">'||triggers.ep_desc||'</font></TD>');
        --htp.p('<TD nowrap><font class="TRT">'||triggers.last_update_by||'</font></TD>');
        htp.p('<TD nowrap><a href="evnt_web_pkg.display_notif?p_et_id='||triggers.et_id||'" target="NEW_W"><font class="TRL">'||notif_cnt.value||'</font></a></TD>');
        htp.p('<TD nowrap><a href="evnt_web_pkg.trg_notes?p_et_id='||triggers.et_id||'" target="NEW_W"><font class="TRL">'||notes_cnt.value||'</font></a></TD>');
        --htp.p('<TD nowrap><font class="TRT">'||triggers.et_prev_status||'</font></TD>');
        htp.p('<TD nowrap><font class="TRT">'||triggers.phase||'</font></TD>');
        htp.p('<TD nowrap><font class="TRT">'||triggers.mail||'</font></TD>');
        htp.p('</TR>');

    END LOOP;

    if ( ( p_e_id != 'x' ) and
         ( p_e_id = l_top_sess_e_id ) and
         ( p_date is not null ) and
         ( p_attr_search is not null ) )
    then
        close top_sess_triggers_cur;

    elsif ( p_phase = 'P' )
    then
        close pend_triggers_cur;

    elsif ( ( p_e_id != 'x' ) and
            ( p_date is not null ) )
    then
        close e_triggers_cur;

    else
        close triggers_cur;
    end if;


    htp.p('</TABLE>');
    web_std_pkg.footer;
END disp_triggers;


PROCEDURE ack_all_trigs(
   p_out_type IN VARCHAR2 DEFAULT 'HTML')
IS
   CURSOR all_pend_cur IS
      SELECT et_id
      FROM event_triggers
      WHERE et_ack_flag='Y'
      AND   et_ack_date IS NULL;

   l_row_cnr INTEGER DEFAULT 0;
BEGIN
   FOR all_pend IN all_pend_cur LOOP
      evnt_web_pkg.ack_one_trig(all_pend.et_id,p_out_type);
      l_row_cnr := l_row_cnr + 1;
   END LOOP;

   IF l_row_cnr = 0 THEN
      IF p_out_type = 'HTML' THEN
         web_std_pkg.print_styles;
         htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
         htp.p('<TR><TH nowrap BGCOLOR="'||d_THC||'"><font class="THT">Found no Unacknowledged Triggers.</font></TD>');
         htp.p('</TABLE>');
      ELSE
         dbms_output.put_line('Found no Unacknowledged Triggers.');
      END IF;
   END IF;
END ack_all_trigs;


PROCEDURE ack_one_trig(
   p_et_id IN NUMBER
,  p_out_type IN VARCHAR2 DEFAULT 'HTML')
IS
   CURSOR trig_det_cur IS
      SELECT et_id
      ,      TO_CHAR(et_ack_date,'RRRR-MON-DD HH24:MI:SS') et_ack_date
      ,      a_name
      ,      et_ack_flag
      FROM   event_triggers et
      ,      admins a
      WHERE  et.et_ack_by_a_id = a.a_id(+)
      AND    et.et_id = p_et_id;
   trig_det trig_det_cur%ROWTYPE;

   CURSOR trig_chk_cur IS
      SELECT et_id
      FROM event_triggers
      WHERE et_ack_flag='Y'
      AND et_ack_date IS NULL
      AND et_id = p_et_id
      FOR UPDATE OF et_ack_date;
   trig_chk trig_chk_cur%ROWTYPE;

BEGIN
   -- check trigger's acknowledgment status
   -- to avoid double acknowledgment
   -- by different admins
   --
   OPEN trig_chk_cur;
   FETCH trig_chk_cur INTO trig_chk;
   IF trig_chk_cur%FOUND THEN
      UPDATE event_triggers
      SET et_ack_date = SYSDATE
      ,   et_ack_by_a_id = (SELECT a_id
                            FROM admins
                            WHERE a_name = USER)
      ,   date_modified = SYSDATE
      ,   modified_by = USER
      WHERE CURRENT OF trig_chk_cur;

      CLOSE trig_chk_cur;

      IF p_out_type = 'HTML' THEN
         web_std_pkg.print_styles;
         htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
         htp.p('<TR><TH nowrap BGCOLOR="'||d_THC||'"><font class="THT">Successfully Acknowledged Trigger Id: '||p_et_id||'</font></TD>');
         htp.p('</TABLE>');
      ELSE
         dbms_output.put_line('Successfully Acknowledged Trigger Id: '||p_et_id);
      END IF;


   ELSE
      -- either invalid trigger
      -- or already acknowledged
      --
      CLOSE trig_chk_cur;

      OPEN trig_det_cur;
      FETCH trig_det_cur INTO trig_det;

      IF trig_det_cur%FOUND AND
         trig_det.et_ack_flag = 'Y' THEN

         CLOSE trig_det_cur;

         IF p_out_type = 'HTML' THEN
            web_std_pkg.print_styles;
            htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
            htp.p('<TR><TH nowrap colspan="2" BGCOLOR="'||d_THC||'"><font class="THT">Trigger Is Already Acknowledged:</font></TD>');
            htp.p('<TR><TD nowrap><font class="TRT">Triger Id:</font></TD>');
            htp.p('    <TD nowrap><font class="TRT">'||trig_det.et_id||'</font></TD>');
            htp.p('<TR><TD nowrap><font class="TRT">Date:</font></TD>');
            htp.p('    <TD nowrap><font class="TRT">'||trig_det.et_ack_date||'</font></TD>');
            htp.p('<TR><TD nowrap><font class="TRT">Admin:</font></TD>');
            htp.p('    <TD nowrap><font class="TRT">'||trig_det.a_name||'</font></TD>');
            htp.p('</TABLE>');
         ELSE
      	    dbms_output.put_line('================================');
            dbms_output.put_line('Trigger Is Already Acknowledged:');
            dbms_output.put_line('================================');
            dbms_output.put_line('Triger Id: '||trig_det.et_id);
            dbms_output.put_line('Date: '||trig_det.et_ack_date);
            dbms_output.put_line('Admin: '||trig_det.a_name);
            dbms_output.put_line('================================');
         END IF;

      ELSIF trig_det_cur%FOUND AND
            trig_det.et_ack_flag != 'Y' THEN

         CLOSE trig_det_cur;

         IF p_out_type = 'HTML' THEN
            web_std_pkg.print_styles;
            htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
            htp.p('<TR><TH nowrap BGCOLOR="'||d_THC||'"><font class="THT">Trigger Id: '||p_et_id||' Doesn''t Require Acknowledgement</font></TD>');
            htp.p('</TABLE>');
         ELSE
            dbms_output.put_line('Trigger Id: '||p_et_id||' Doesn''t Require Acknowledgement');
         END IF;

      ELSE
         CLOSE trig_det_cur;

         RAISE_APPLICATION_ERROR(-20001,'Invalid Trigger Id='||p_et_id);
      END IF;

   END IF;
END ack_one_trig;



PROCEDURE get_trigger(
   p_et_id     IN NUMBER DEFAULT NULL
,  p_diff_with IN NUMBER DEFAULT NULL
,  p_pag_str   IN NUMBER DEFAULT 1
,  p_pag_int   IN NUMBER DEFAULT 19)
IS
   CURSOR trig_det_cur IS
      SELECT
         target
      ,  TO_CHAR(et_trigger_time,'RRRR-MON-DD HH24:MI:SS') trigger_time
      ,  DECODE(et_status,'CLEARED',et_prev_status||' - CLEARED',et_status) et_status
      ,  ep_desc
      ,  et.last_update_by
      ,  h_id
      ,  s_id
      ,  e_id
      ,  ep_id
      ,  et_id
      ,  et_orig_et_id
      ,  et_clr_et_id
      ,  et_prev_et_id
      --,  et_prev_status
      ,  phase
      ,  mail
      ,  et_ack_flag
      ,  et_ack_date
      ,  TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS') et_ack_date_char
      ,  DECODE(et_ack_flag,
            'Y',DECODE(et_ack_date,
                   NULL,'REQUIRED'
                       /* other in NULL */
                       ,NVL(a.a_name,'UNKNOWN')||
                        '('||
                        TO_CHAR(et_ack_date,'RRRR-DD-MON HH24:MI:SS')||
                        ')'
                )
                /* other in 'Y' */
                ,'NOT REQUIRED'
         ) decoded_ack
      ,  a.a_name ack_by_name
      FROM event_triggers_all_v et
      ,    admins a
      WHERE et_id = p_et_id
      AND   et.et_ack_by_a_id = a.a_id(+);
   trig_det trig_det_cur%ROWTYPE;

   CURSOR notif_cnt_cur IS
      SELECT COUNT(et_id) value
      FROM event_trigger_notif
      WHERE et_id = p_et_id;
   notif_cnt notif_cnt_cur%ROWTYPE;

   CURSOR notes_cnt_cur IS
      SELECT DECODE(COUNT(tn_id),0,'Add','View') value
      FROM event_trigger_notes
      WHERE et_id = p_et_id;
   notes_cnt notes_cnt_cur%ROWTYPE;

   CURSOR next_trig_cur IS
      SELECT et_id
      FROM event_triggers
      WHERE et_prev_et_id = p_et_id;
   next_trig next_trig_cur%ROWTYPE;

   CURSOR last_trig_cur(p_orig_et_id IN NUMBER) IS
      SELECT MAX(et_id) et_id
      FROM event_triggers
      WHERE et_orig_et_id = p_orig_et_id;
   last_trig last_trig_cur%ROWTYPE;

   INVALID_TRIGGER BOOLEAN DEFAULT FALSE;
   LOOKUP_TRIGGER  BOOLEAN DEFAULT FALSE;

   row_cnt INTEGER DEFAULT 0;
   lrow_id INTEGER;

BEGIN
   IF p_et_id IS NULL THEN
      LOOKUP_TRIGGER := TRUE;
   ELSE
      OPEN trig_det_cur;
      FETCH trig_det_cur INTO trig_det;
      IF trig_det_cur%NOTFOUND THEN
         INVALID_TRIGGER := TRUE;
      END IF;
      CLOSE trig_det_cur;
   END IF;

   IF LOOKUP_TRIGGER THEN
      web_std_pkg.header('Event System - Event Trigger Lookup');

      htp.p('<form method="POST" action="evnt_web_pkg.get_trigger">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');

      htp.p('<tr>');
      htp.p('<td><font class="TRT">Event Trigger ID: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_et_id size=7 maxlength=15 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Lookup">');
      htp.p('</td>');
      htp.p('</tr>');

      -- END
      htp.p('</form>');
      htp.p('</table>');


   ELSIF INVALID_TRIGGER THEN

      web_std_pkg.header('Event System - Invalid Event Trigger');
      htp.p('<font class="TRT"><b>Invalid Trigger</b><br>(possibly it has been purged.)</font></TD>');

   ELSE

      OPEN notif_cnt_cur;
      FETCH notif_cnt_cur INTO notif_cnt;
      CLOSE notif_cnt_cur;

      OPEN notes_cnt_cur;
      FETCH notes_cnt_cur INTO notes_cnt;
      CLOSE notes_cnt_cur;

      OPEN next_trig_cur;
      FETCH next_trig_cur INTO next_trig;
      CLOSE next_trig_cur;

      IF trig_det.et_clr_et_id IS NULL THEN
         OPEN last_trig_cur(trig_det.et_orig_et_id);
         FETCH last_trig_cur INTO last_trig;
         CLOSE last_trig_cur;
      ELSE
         last_trig.et_id := trig_det.et_clr_et_id;
      END IF;


      web_std_pkg.header('Event System - '||p_et_id||' Trigger Details');

      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');

      htp.p('<TR>');
      htp.p('<TH colspan=5 ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">Trigger Navigator['||trig_det.et_id||']</font></TH>');
      htp.p('</TR>');

      htp.p('<TR>');
      htp.p('<TH ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">|<< STR</font></TH>');
      htp.p('<TH ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT"><< REW</font></TH>');
      htp.p('<TH ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT"> CUR </font></TH>');
      htp.p('<TH ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">FRW >></font></TH>');
      htp.p('<TH ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">END >>|</font></TH>');
      htp.p('</TR>');

      htp.p('<TR>');
      htp.p('<TD ALIGN="Center" nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||trig_det.et_orig_et_id||'"><font class="TRL">'||trig_det.et_orig_et_id||'</font></a></TD>');
      htp.p('<TD ALIGN="Center" nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||trig_det.et_prev_et_id||'"><font class="TRL">'||trig_det.et_prev_et_id||'</font></a></TD>');
      htp.p('<TD ALIGN="Center" nowrap><font class="TRT"><b>'||trig_det.et_id||'</b></font></TD>');
      htp.p('<TD ALIGN="Center" nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||next_trig.et_id||'"><font class="TRL">'||next_trig.et_id||'</font></a></TD>');
      htp.p('<TD ALIGN="Center" nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||last_trig.et_id||'"><font class="TRL">'||last_trig.et_id||'</font></a></TD>');
      htp.p('</TR>');

      htp.p('<TR>');
      htp.p('<TD ALIGN="Center" colspan=5>');
      htp.p('<BR>');

         -- TRIGGER DETAILS TABLE
         htp.p('<TABLE  border="0" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');

         htp.p('<TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Target</font></TH>');
         htp.p('<TD nowrap><a href="evnt_web_pkg.ea_form?p_h_id='||trig_det.h_id||'"><font class="TRL">'||trig_det.target||'</font></a></TD>');
         --htp.p('<TD nowrap><font class="TRT">'||trig_det.target||'</font></TD>');
         htp.p('</TR>');

         htp.p('<TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Trigger Time</font></TH>');
         htp.p('<TD nowrap><font class="TRT">'||trig_det.trigger_time||'</font></TD>');
         htp.p('</TR>');

         htp.p('<TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Status</font></TH>');
         htp.p('<TD nowrap><a href="evnt_web_pkg.epv_form?p_ep_id='||trig_det.ep_id||'&p_e_id='||trig_det.e_id||'"><font class="TRL">'||trig_det.et_status||'</font></a></TD>');
         htp.p('</TR>');

         htp.p('<TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Description</font></TH>');
         htp.p('<TD nowrap><font class="TRT">'||trig_det.ep_desc||'</font></TD>');
         htp.p('</TR>');

         htp.p('<TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Acknowledgement</font></TH>');
         htp.p('<TD nowrap><font class="TRT">'||trig_det.decoded_ack||'</font></TD>');
         htp.p('</TR>');

         htp.p('<TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Notifications</font></TH>');
         htp.p('<TD nowrap><a href="evnt_web_pkg.display_notif?p_et_id='||trig_det.et_id||'" target="NEW_W"><font class="TRL">'||notif_cnt.value||'</font></a></TD>');
         htp.p('</TR>');

         htp.p('<TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Notes</font></TH>');
         htp.p('<TD nowrap><a href="evnt_web_pkg.trg_notes?p_et_id='||trig_det.et_id||'" target="NEW_W"><font class="TRL">'||notes_cnt.value||'</font></a></TD>');
         htp.p('</TR>');

         htp.p('</TABLE>');

      htp.p('</TD>');
      htp.p('</TR>');
      htp.p('</TABLE>');

      htp.p('<BR>');


      IF p_diff_with IS NULL THEN
         -- first pass give compare button
         --
         compare_button(trig_det.et_id);
         get_trig_output(trig_det.et_id,trig_det.et_prev_et_id);

      ELSIF p_diff_with = '-1' THEN
         -- print the table of all prev trigs
         --
         htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
         htp.p('<TR>');
         htp.p('<TH colspan=5 ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">Pick any trigger below to compare with ['||trig_det.et_id||']</font></TH>');
         htp.p('</TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Target</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Date</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Trigger</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Status</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Description</font></TH>');

         FOR prevs IN (SELECT *
                       FROM (
                          SELECT ROWNUM r, a.*
                          FROM (SELECT
                                   et_id
                                ,  target
                                ,  TO_CHAR(et_trigger_time,'RRRR-MON-DD HH24:MI:SS') trigger_time
                                ,  DECODE(et_status,'CLEARED',et_prev_status||' - CLEARED',et_status) et_status
                                ,  ep_desc
                                FROM event_triggers_all_v
                                WHERE e_id = trig_det.e_id
                                AND h_id = trig_det.h_id
                                AND DECODE(trig_det.s_id,NULL,-1,s_id) = NVL(trig_det.s_id,-1)
                                ORDER BY et_trigger_time DESC) a
                          WHERE ROWNUM <= (p_pag_str + p_pag_int))
                       WHERE r >= p_pag_str)
         LOOP

            IF trig_det.et_id = prevs.et_id THEN
               htp.p('<TR BGCOLOR="'||d_ARC_R||'">');
            ELSE
               htp.p('<TR>');
            END IF;

            htp.p('<TD nowrap><font class="TRT">'||prevs.target||'</font></TD>');
            htp.p('<TD nowrap><font class="TRT">'||prevs.trigger_time||'</font></TD>');
            htp.p('<TD nowrap><a href="evnt_web_pkg.get_trigger?p_et_id='||trig_det.et_id||'&p_diff_with='||prevs.et_id||'"><font class="TRL">'||prevs.et_id||'</font></a></TD>');
            htp.p('<TD nowrap><font class="TRT">'||prevs.et_status||'</font></TD>');
            htp.p('<TD nowrap><font class="TRT">'||prevs.ep_desc||'</font></TD>');
            htp.p('</TR>');

            row_cnt := row_cnt + 1;
            lrow_id := prevs.r;
         END LOOP;
         htp.p('</TABLE>');

         -- paginate controls
         -- open paginate table
         htp.p('<table cellpadding="0" cellspacing="2" border="0">');
         htp.p('<tr>');

         -- PREV
         IF p_pag_str > 1 THEN
            htp.p('<form method="POST" action="evnt_web_pkg.get_trigger">');
            htp.p('<input type="hidden" name="p_et_id" value="'||htf.escape_sc(p_et_id)||'">');
            htp.p('<input type="hidden" name="p_diff_with" value="'||htf.escape_sc(p_diff_with)||'">');
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
            htp.p('<form method="POST" action="evnt_web_pkg.get_trigger">');
            htp.p('<input type="hidden" name="p_et_id" value="'||htf.escape_sc(p_et_id)||'">');
            htp.p('<input type="hidden" name="p_diff_with" value="'||htf.escape_sc(p_diff_with)||'">');
            htp.p('<input type="hidden" name="p_pag_str" value="'||htf.escape_sc(TO_CHAR(p_pag_str+p_pag_int+1))||'">');
            htp.p('<input type="hidden" name="p_pag_int" value="'||htf.escape_sc(p_pag_int)||'">');
            htp.p('<td><input type="SUBMIT" value="['||TO_CHAR(lrow_id+1)||'-'||TO_CHAR(lrow_id+p_pag_int+1)||'] >>"></td>');
            htp.p('</form>');
         END IF;

         -- close paginate table
         htp.p('</tr>');
         htp.p('</table>');

      ELSE
         -- if I got here p_diff_with was passed
         -- get diff of curr trig with p_diff_with
         --
         compare_button(trig_det.et_id);
         get_trig_output(trig_det.et_id,p_diff_with);

      -- END DIFF
      END IF;

   END IF;

   web_std_pkg.footer;

END get_trigger;


PROCEDURE history(
   p_week IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR week_cur(p_week IN DATE) IS
      SELECT
          'p_e_id='||e_id e_id
      ,   NVL(e_name,e_code) e_code
      ,   MAX(DECODE(day,'MON',cnt,NULL)) MON
      ,   MAX(DECODE(day,'TUE',cnt,NULL)) TUE
      ,   MAX(DECODE(day,'WED',cnt,NULL)) WED
      ,   MAX(DECODE(day,'THU',cnt,NULL)) THU
      ,   MAX(DECODE(day,'FRI',cnt,NULL)) FRI
      ,   MAX(DECODE(day,'SAT',cnt,NULL)) SAT
      ,   MAX(DECODE(day,'SUN',cnt,NULL)) SUN
      FROM (
      SELECT /*+ ORDERED */
         e.e_id
      ,  e.e_code
      ,  e.e_name
      ,  TO_CHAR(et.et_trigger_time,'DY') day
      ,  COUNT(*) cnt
      FROM event_triggers et
      ,    events e
      WHERE et.e_id = e.e_id
      and e.e_code != 'SQL_SCRIPT'
      and e.e_code != 'CHK_OS_LOG'
      AND TRUNC(et.et_trigger_time,'IW') = TRUNC(p_week,'IW')
      GROUP BY
         e.e_id
      ,  e.e_code
      ,  e.e_name
      ,  TO_CHAR(et.et_trigger_time,'DY'))
      GROUP BY
          e_id
      ,   NVL(e_name,e_code)
      union all
      SELECT
          'p_ep_id='||ep_id e_id
      ,   NVL(ep_desc,ep_code) e_code
      ,   MAX(DECODE(day,'MON',cnt,NULL)) MON
      ,   MAX(DECODE(day,'TUE',cnt,NULL)) TUE
      ,   MAX(DECODE(day,'WED',cnt,NULL)) WED
      ,   MAX(DECODE(day,'THU',cnt,NULL)) THU
      ,   MAX(DECODE(day,'FRI',cnt,NULL)) FRI
      ,   MAX(DECODE(day,'SAT',cnt,NULL)) SAT
      ,   MAX(DECODE(day,'SUN',cnt,NULL)) SUN
      FROM (
      SELECT /*+ ORDERED */
         ep.ep_id
      ,  ep.ep_code
      ,  ep.ep_desc
      ,  TO_CHAR(et.et_trigger_time,'DY') day
      ,  COUNT(*) cnt
      FROM event_triggers et
      ,    events e
      ,    event_parameters ep
      ,    event_assigments ea
      WHERE et.e_id = e.e_id
      and et.ea_id = ea.ea_id
      and ea.ep_id = ep.ep_id
      and ea.e_id = e.e_id
      and e.e_id = ep.e_id
      and e.e_code in ('SQL_SCRIPT', 'CHK_OS_LOG')
      AND TRUNC(et.et_trigger_time,'IW') = TRUNC(p_week,'IW')
      GROUP BY
         ep.ep_id
      ,  ep.ep_code
      ,  ep.ep_desc
      ,  TO_CHAR(et.et_trigger_time,'DY'))
      GROUP BY
          ep_id
      ,   NVL(ep_desc,ep_code)
      ORDER BY 2;


--      SELECT
--          e_id
--      ,   NVL(e_name,e_code) e_code
--      ,   MAX(DECODE(day,'MON',cnt,NULL)) MON
--      ,   MAX(DECODE(day,'TUE',cnt,NULL)) TUE
--      ,   MAX(DECODE(day,'WED',cnt,NULL)) WED
--      ,   MAX(DECODE(day,'THU',cnt,NULL)) THU
--      ,   MAX(DECODE(day,'FRI',cnt,NULL)) FRI
--      ,   MAX(DECODE(day,'SAT',cnt,NULL)) SAT
--      ,   MAX(DECODE(day,'SUN',cnt,NULL)) SUN
--      FROM (
--      SELECT /*+ ORDERED */
--         e.e_id
--      ,  e.e_code
--      ,  e.e_name
--      ,  TO_CHAR(et.et_trigger_time,'DY') day
--      ,  COUNT(*) cnt
--      FROM event_triggers et
--      ,    events e
--      WHERE et.e_id = e.e_id
--      AND TRUNC(et.et_trigger_time,'IW') = TRUNC(p_week,'IW')
--      GROUP BY
--         e.e_id
--      ,  e.e_code
--      ,  e.e_name
--      ,  TO_CHAR(et.et_trigger_time,'DY'))
--      GROUP BY
--          e_id
--      ,   e_code
--      ,   e_name
--      ORDER BY NVL(e_name,e_code);


   l_week DATE;
BEGIN
   IF p_week IS NULL THEN
      l_week := TRUNC(SYSDATE,'IW');
   ELSE
      l_week := TO_DATE(p_week,'RRRR-MON-DD');
   END IF;

   web_std_pkg.header('Event System - History (week of '||TO_CHAR(TRUNC(l_week,'IW'),'RRRR-MON-DD')||')');

   -- allow for week stepping
   htp.p('<table cellpadding="0" cellspacing="2" border="0">');
   htp.p('<tr>');

   -- week back
   htp.p('<td>');
   htp.p('<form method="POST" action="evnt_web_pkg.history">');
   htp.p('<input type="SUBMIT" value="'||TO_CHAR(TRUNC(l_week,'IW')-7,'RRRR-MON-DD')||' <<<">');
   htp.p('<input type="hidden" name="p_week" value="'||TO_CHAR(TRUNC(l_week,'IW')-7,'RRRR-MON-DD')||'">');
   htp.p('</form>');
   htp.p('</td>');

   -- refresh current week
   htp.p('<td>');
   htp.p('<form method="POST" action="evnt_web_pkg.history">');
   htp.p('<input type=text name=p_week size=11 maxlength=11 value="'||TO_CHAR(TRUNC(l_week,'IW'),'RRRR-MON-DD')||'">');
   htp.p('<input type="SUBMIT" value="Refresh">');
   htp.p('</form>');
   htp.p('</td>');

   -- week forward
   htp.p('<td>');
   htp.p('<form method="POST" action="evnt_web_pkg.history">');
   htp.p('<input type="SUBMIT" value=">>> '||TO_CHAR(TRUNC(l_week,'IW')+7,'RRRR-MON-DD')||'">');
   htp.p('<input type="hidden" name="p_week" value="'||TO_CHAR(TRUNC(l_week,'IW')+7,'RRRR-MON-DD')||'">');
   htp.p('</form>');
   htp.p('</td>');

   htp.p('</tr>');
   htp.p('</table>');


   htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Event</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">MON<br>'||TO_CHAR(TRUNC(l_week,'IW')+0,'MON-DD')||'</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">TUE<br>'||TO_CHAR(TRUNC(l_week,'IW')+1,'MON-DD')||'</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">WED<br>'||TO_CHAR(TRUNC(l_week,'IW')+2,'MON-DD')||'</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">THU<br>'||TO_CHAR(TRUNC(l_week,'IW')+3,'MON-DD')||'</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">FRI<br>'||TO_CHAR(TRUNC(l_week,'IW')+4,'MON-DD')||'</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">SAT<br>'||TO_CHAR(TRUNC(l_week,'IW')+5,'MON-DD')||'</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">SUN<br>'||TO_CHAR(TRUNC(l_week,'IW')+6,'MON-DD')||'</font></TH>');

   FOR week IN week_cur(l_week) LOOP

      htp.p('<TR>');
      htp.p('<TD nowrap><font class="TRT">'||week.e_code||'</font></TD>');
      htp.p('<TD nowrap><a href="evnt_web_pkg.disp_triggers?'||week.e_id||
                                      '&p_date='||TO_CHAR(TRUNC(l_week,'IW')+0,'RRRR-MON-DD')||
                                      '"><font class="TRL">'||
                                      week.MON||'</font></a></TD>');
      htp.p('<TD nowrap><a href="evnt_web_pkg.disp_triggers?'||week.e_id||
                                      '&p_date='||TO_CHAR(TRUNC(l_week,'IW')+1,'RRRR-MON-DD')||
                                      '"><font class="TRL">'||
                                      week.TUE||'</font></a></TD>');
      htp.p('<TD nowrap><a href="evnt_web_pkg.disp_triggers?'||week.e_id||
                                      '&p_date='||TO_CHAR(TRUNC(l_week,'IW')+2,'RRRR-MON-DD')||
                                      '"><font class="TRL">'||
                                      week.WED||'</font></a></TD>');
      htp.p('<TD nowrap><a href="evnt_web_pkg.disp_triggers?'||week.e_id||
                                      '&p_date='||TO_CHAR(TRUNC(l_week,'IW')+3,'RRRR-MON-DD')||
                                      '"><font class="TRL">'||
                                      week.THU||'</font></a></TD>');
      htp.p('<TD nowrap><a href="evnt_web_pkg.disp_triggers?'||week.e_id||
                                      '&p_date='||TO_CHAR(TRUNC(l_week,'IW')+4,'RRRR-MON-DD')||
                                      '"><font class="TRL">'||
                                      week.FRI||'</font></a></TD>');
      htp.p('<TD nowrap><a href="evnt_web_pkg.disp_triggers?'||week.e_id||
                                      '&p_date='||TO_CHAR(TRUNC(l_week,'IW')+5,'RRRR-MON-DD')||
                                      '"><font class="TRL">'||
                                      week.SAT||'</font></a></TD>');
      htp.p('<TD nowrap><a href="evnt_web_pkg.disp_triggers?'||week.e_id||
                                      '&p_date='||TO_CHAR(TRUNC(l_week,'IW')+6,'RRRR-MON-DD')||
                                      '"><font class="TRL">'||
                                      week.SUN||'</font></a></TD>');

      htp.p('</TR>');
  END LOOP;

  htp.p('</TABLE>');
  web_std_pkg.footer;

END history;


PROCEDURE ep_form(
   p_ep_id          IN VARCHAR2 DEFAULT NULL
,  p_e_id           IN VARCHAR2 DEFAULT NULL
,  p_e_code         IN VARCHAR2 DEFAULT NULL
,  p_date_modified  IN VARCHAR2 DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_ep_code        IN VARCHAR2 DEFAULT NULL
,  p_ep_hold_level  IN VARCHAR2 DEFAULT NULL
,  p_ep_desc        IN VARCHAR2 DEFAULT NULL
,  p_ep_coll_cp_id  IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT NULL)
IS

   CURSOR code_bases_cur IS
      SELECT DISTINCT
         REPLACE(e_code_base,'*') code_base
      ,  DECODE(REPLACE(e_code_base,'*'),
            'APPSMON','Application Events',
            'SEEDMON','Database Events',
            'SIEBMON','Siebel Events',
            'CUSTMON','Custom Events') base_name
      FROM events
      ORDER BY
         DECODE(REPLACE(e_code_base,'*'),
            'APPSMON',2,
            'SEEDMON',1,
            'SIEBMON',3,
            'CUSTMON',4);

   CURSOR events_all(p_code_base IN VARCHAR2) IS
      SELECT
         e_id
      ,  date_created
      ,  date_modified
      ,  modified_by
      ,  created_by
      ,  e_code
      ,  e_name
      ,  e_desc
      ,  DECODE(INSTR(e_code_base,'*'),0,'Local','Remote') evnt_type
      ,  REPLACE(e_code_base,'*') code_base
      ,  e_code_base
      ,  e_file_name
      ,  DECODE(e_coll_flag,'Y','Yes','No') coll_type
      FROM events
      WHERE REPLACE(e_code_base,'*') = p_code_base
      ORDER BY
         e_code_base
      ,  e_code;

   CURSOR one_event_cur IS
      SELECT
         e_id
      ,  e_code
      ,  e_name
      ,  e_desc
      ,  DECODE(INSTR(e_code_base,'*'),0,'Local','Remote') evnt_type
      ,  REPLACE(e_code_base,'*') code_base
      ,  e_code_base
      ,  e_file_name
      ,  e_coll_flag
      FROM events
      WHERE e_id = p_e_id;
   one_event one_event_cur%ROWTYPE;


   CURSOR ep_all_cur(p_e_id IN NUMBER) IS
      SELECT e_id
      ,      ep_id
      ,      ep_code
      ,      ep_hold_level
      ,      rc.rv_meaning ep_hold_level_m
      ,      ep_desc
      ,      NVL(cp.cp_code,'NOT APPLICABLE') cp_code
      ,      ep_coll_cp_id
      FROM   event_parameters ep
      ,      cg_ref_codes rc
      ,      coll_parameters cp
      WHERE  ep_hold_level = rc.rv_low_value(+)
      AND    rc.rv_domain(+) = 'EVENT_PARAMETERS.EP_HOLD_LEVEL'
      AND    ep.ep_coll_cp_id = cp.cp_id(+)
      AND    e_id = p_e_id
      ORDER BY ep_code;

   CURSOR ep_one_cur IS
      SELECT ep_id
      ,      e.e_id
      ,      e.e_coll_flag
      ,      e_code
      ,      e_code_base
      ,      e_file_name
      ,      ep_code
      ,      ep_hold_level
      ,      ep_desc
      ,      TO_CHAR(ep.date_modified,'RRRR-MON-DD HH24:MI:SS') date_modified
      ,      NVL(cp.cp_code,'NOT APPLICABLE') cp_code
      ,      ep_coll_cp_id
      FROM   event_parameters ep
      ,      events e
      ,      coll_parameters cp
      WHERE  ep.e_id = e.e_id
      AND    ep.ep_coll_cp_id = cp.cp_id(+)
      AND    ep.ep_id = p_ep_id
      AND    ep.e_id = p_e_id;
   ep_one ep_one_cur%ROWTYPE;


   CURSOR hold_level_cur IS
      SELECT rv_meaning meaning
      ,      rv_low_value value
      FROM   cg_ref_codes
      WHERE  rv_domain = 'EVENT_PARAMETERS.EP_HOLD_LEVEL';


   PRINT_REPORT BOOLEAN DEFAULT TRUE;
   PRINT_DETAIL BOOLEAN DEFAULT FALSE;
   PRINT_FOOTER BOOLEAN DEFAULT TRUE;
   PRINT_INSERT BOOLEAN DEFAULT FALSE;
   PRINT_UPDATE BOOLEAN DEFAULT FALSE;

BEGIN

   IF (p_operation = 'DETAIL' AND p_e_id IS NOT NULL) OR
      p_operation IN ('D','I','U')
   THEN
      PRINT_DETAIL := TRUE;
      PRINT_REPORT := FALSE;
   END IF;

   IF p_operation = 'E' THEN
      PRINT_UPDATE := TRUE;
      PRINT_REPORT := FALSE;
   END IF;


   IF p_operation = 'N' THEN
      PRINT_INSERT := TRUE;
      PRINT_REPORT := FALSE;
   END IF;


   IF p_operation = 'U' THEN
      BEGIN
         evnt_api_pkg.ep(
            p_ep_id         => p_ep_id
         ,  p_e_id          => p_e_id
         ,  p_e_code        => NULL
         ,  p_date_modified => TO_DATE(p_date_modified,'RRRR-MON-DD HH24:MI:SS')
         ,  p_modified_by   => USER
         ,  p_created_by    => NULL
         ,  p_ep_code       => p_ep_code
         ,  p_ep_hold_level => p_ep_hold_level
         ,  p_ep_desc       => p_ep_desc
         ,  p_ep_coll_cp_id => p_ep_coll_cp_id
         ,  p_operation     => 'U');

      EXCEPTION
         WHEN OTHERS THEN
            PRINT_REPORT := FALSE;
            PRINT_DETAIL := FALSE;
            PRINT_FOOTER := FALSE;
            web_std_pkg.header('Event System - Updating Event Threshold '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;
   END IF;


   IF p_operation = 'I' THEN

      BEGIN
         evnt_api_pkg.ep(
            p_ep_id         => NULL
         ,  p_e_id          => p_e_id
         ,  p_e_code        => NULL
         ,  p_date_modified => NULL
         ,  p_modified_by   => NULL
         ,  p_created_by    => USER
         ,  p_ep_code       => p_ep_code
         ,  p_ep_hold_level => p_ep_hold_level
         ,  p_ep_desc       => p_ep_desc
         ,  p_ep_coll_cp_id => p_ep_coll_cp_id
         ,  p_operation     => 'I');

      EXCEPTION
         WHEN OTHERS THEN
            PRINT_REPORT := FALSE;
            PRINT_DETAIL := FALSE;
            PRINT_FOOTER := FALSE;
            web_std_pkg.header('Event System - Error Creating Event Threshold '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;
   END IF;


   IF p_operation = 'D' THEN

      BEGIN
         evnt_api_pkg.ep(
            p_ep_id         => p_ep_id
         ,  p_e_id          => p_e_id
         ,  p_e_code        => NULL
         ,  p_date_modified => NULL
         ,  p_modified_by   => NULL
         ,  p_created_by    => NULL
         ,  p_ep_code       => NULL
         ,  p_ep_hold_level => NULL
         ,  p_ep_desc       => NULL
         ,  p_ep_coll_cp_id => NULL
         ,  p_operation     => 'D');

      EXCEPTION
         WHEN OTHERS THEN
            PRINT_REPORT := FALSE;
            PRINT_DETAIL := FALSE;
            PRINT_FOOTER := FALSE;
            web_std_pkg.header('Event System - Error Deleting Event Threshold '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;
   END IF;


   IF PRINT_DETAIL THEN
      web_std_pkg.header('Event System - Event Thresholds '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));

      OPEN one_event_cur;
      FETCH one_event_cur INTO one_event;
      CLOSE one_event_cur;

      -- start threshold table
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');

      -- joined table header
      htp.p('<TR>');
      htp.p('<TH colspan=6 ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">Event Thresholds</font></TH>');
      htp.p('</TR>');

      -- epv level header
      htp.p('<TR>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Control Links</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Id</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Threshold</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Collection</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Hold</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Description</font></TH>');
      htp.p('</TR>');

      -- thresholds
      FOR ep_all IN ep_all_cur(one_event.e_id) LOOP


         htp.p('<TR>');

         -- ALL RECORD CONTROL LINKS
         htp.p('<TD nowrap>'||
         /* EDIT */
         '<a href="evnt_web_pkg.ep_form?p_ep_id='||ep_all.ep_id||
                                      '&p_e_id='||ep_all.e_id||
                                      '&p_operation=E">'||
             '<font class="TRL">'||
             'edit</font></a>'||
         '<font class="TRT">|</font>'||
         /* DELETE */
         '<a href="evnt_web_pkg.ep_form?p_ep_id='||ep_all.ep_id||
                                      '&p_e_id='||ep_all.e_id||
                                      '&p_operation=D">'||
             '<font class="TRL">'||
             'del</font></a>'||
         '<font class="TRT">|</font>'||
         /* TRIGGERS */
         '<a href="evnt_web_pkg.disp_triggers?p_ep_id='||ep_all.ep_id||'">'||
             '<font class="TRL">'||
             'triggers</font></a>'||
         /* END */
         '</TD>');

         htp.p('<TD nowrap><font class="TRT">'||ep_all.ep_id||'</font></TD>');
         htp.p('<TD nowrap><a href="evnt_web_pkg.epv_form?p_ep_id='||ep_all.ep_id||'&p_e_id='||ep_all.e_id||'"><font class="TRL">'||ep_all.ep_code||'</font></a></TD>');

         IF one_event.e_coll_flag = 'Y' AND
            ep_all.cp_code = 'NOT APPLICABLE'
         THEN
            htp.p('<TD nowrap><font class="TRT">UNKNOWN</font></TD>');
         ELSE
            htp.p('<TD nowrap><font class="TRT">'||ep_all.cp_code||'</font></TD>');
         END IF;


         htp.p('<TD nowrap><font class="TRT">'||ep_all.ep_hold_level_m||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||ep_all.ep_desc||'</font></TD>');
         htp.p('</TR>');

      -- thresholds loop
      END LOOP;

      -- control row
      htp.p('<TR>');
      htp.p('<TD colspan=6 ALIGN="Center" BGCOLOR="#FFFFFF" nowrap>');

         -- CONTROL
         htp.p('<table cellpadding="0" cellspacing="2" border="0">');
         htp.p('<tr>');

         htp.p('<td>');
         htp.p('<form method="POST" action="evnt_web_pkg.ep_form">');
         htp.p('<input type="SUBMIT" value="New Threshold">');
         htp.p('<input type="hidden" name="p_operation" value="N">');
         htp.p('<input type="hidden" name="p_e_id" value="'||one_event.e_id||'">');
         htp.p('</form>');
         htp.p('</td>');

         htp.p('<td>');
         htp.p('<form method="POST" action="evnt_web_pkg.ep_form">');
         htp.p('<input type="SUBMIT" value="View Events">');
         htp.p('</form>');
         htp.p('</td>');

         htp.p('</tr>');
         htp.p('</table>');

      htp.p('</TD>');
      htp.p('</TR>');


      -- print event description
      event_header(p_e_id,6);

      htp.p('</TABLE>');

   -- END DETAIL
   END IF;


   IF PRINT_REPORT THEN
      web_std_pkg.header('Event System - Installed Events '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));

      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');

      FOR code_bases IN code_bases_cur LOOP

         htp.p('<TR>');
         htp.p('<TH ALIGN="Center" colspan=5 BGCOLOR="'||d_THC||'"><font class="THT">'||code_bases.base_name||'</font></TH>');
         htp.p('</TR>');

         -- event level header
         htp.p('<TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Event</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Event Name</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Event File</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Agent</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Coll</font></TH>');
         htp.p('</TR>');


         FOR events IN events_all(code_bases.code_base) LOOP
            htp.p('<TR>');
            htp.p('<TD nowrap><a href="evnt_web_pkg.ep_form?p_e_id='||events.e_id||'&p_operation=DETAIL"><font class="TRL">'||events.e_code||'</font></a></TD>');
            htp.p('<TD nowrap><font class="TRT">'||events.e_name||'</font></TD>');
            htp.p('<TD nowrap><font class="TRT">'||events.code_base||'/'
                                                 ||events.e_file_name||
                                                 '</font></TD>');
            htp.p('<TD nowrap><font class="TRT">('||events.evnt_type||')</font></TD>');
            htp.p('<TD nowrap><font class="TRT">('||events.coll_type||')</font></TD>');

            htp.p('</TR>');

         -- events loop
         END LOOP;

      -- code bases loop
      END LOOP;
      htp.p('</TABLE>');

   -- PRINT_REPORT
   END IF;


   IF PRINT_INSERT THEN
      web_std_pkg.header('Event System - New Event Threshold '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
      htp.p('<form method="POST" action="evnt_web_pkg.ep_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');

      OPEN one_event_cur;
      FETCH one_event_cur INTO one_event;
      CLOSE one_event_cur;


      -- EVENT CODE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Event</font></td>');
      htp.p('<td><font class="TRL">'||one_event.e_code||'('||one_event.e_file_name||')'||'</font></td>');
      htp.p('</tr>');

      -- EP_CODE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Threshold</font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ep_code size=25 maxlength=50 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- EP_COLL_CP_ID
      IF one_event.e_coll_flag = 'N' THEN
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Collection</font></td>');
         htp.p('<td><font class="TRL">NOT APPLICABLE</font></td>');
         htp.p('<input type="hidden" name="p_ep_coll_cp_id" value="-1">');
         htp.p('</tr>');
      ELSE
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Collection</font></td>');
         htp.p('<td>');
         htp.p('<select name="p_ep_coll_cp_id">');

         htp.p('<option value="-1" >-----------</option>');
         FOR coll IN (SELECT cp_code, cp_id
                      FROM coll_parameters
                      WHERE c_id = (SELECT c_id
                                    FROM collections
                                    WHERE c_code = 'EVENT_COLL')
                      ORDER BY cp_code)
         LOOP
            htp.p('<option value="'||coll.cp_id||'" >'||coll.cp_code||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');
      END IF;


      -- EP_HOLD_LEVEL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Hold Level</font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ep_hold_level">');

      htp.p('<option value="" >-----------</option>');
      FOR hold_level IN hold_level_cur LOOP
         htp.p('<option value="'||hold_level.value||'" >'||hold_level.meaning||'</option>');
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');

      -- EP_DESC
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Description</font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ep_desc size=50 maxlength=512 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Create">');
      htp.p('<input type="RESET" value="Clear">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="I">');
      htp.p('<input type="hidden" name="p_e_id" value="'||p_e_id||'">');

      -- END
      htp.p('</form>');
      htp.p('</table>');

   -- PRINT_INSERT
   END IF;


   IF PRINT_UPDATE THEN
      OPEN ep_one_cur;
      FETCH ep_one_cur INTO ep_one;
      CLOSE ep_one_cur;

      web_std_pkg.header('Event System - Edit Event Threshold '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
      htp.p('<form method="POST" action="evnt_web_pkg.ep_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');

      -- EVENT CODE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Event</font></td>');
      htp.p('<td><font class="TRL">'||ep_one.e_code||'('||ep_one.e_file_name||')'||'</font></td>');
      htp.p('</tr>');

      -- EP_CODE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Threshold</font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ep_code size=25 maxlength=50 value="'||ep_one.ep_code||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- EP_COLL_CP_ID
      IF ep_one.e_coll_flag = 'N' THEN
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Collection</font></td>');
         htp.p('<td><font class="TRL">NOT APPLICABLE</font></td>');
         htp.p('<input type="hidden" name="p_ep_coll_cp_id" value="-1">');
         htp.p('</tr>');
      ELSE
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Collection</font></td>');
         htp.p('<td>');
         htp.p('<select name="p_ep_coll_cp_id">');

         htp.p('<option value="-1" >-----------</option>');
         FOR coll IN (SELECT cp_code, cp_id
                      FROM coll_parameters
                      WHERE c_id = (SELECT c_id
                                    FROM collections
                                    WHERE c_code = 'EVENT_COLL')
                      ORDER BY cp_code)
         LOOP
            IF coll.cp_id = ep_one.ep_coll_cp_id THEN
               htp.p('<option value="'||coll.cp_id||'" selected>'||coll.cp_code||'</option>');
            ELSE
               htp.p('<option value="'||coll.cp_id||'" >'||coll.cp_code||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');
      END IF;


      -- EP_HOLD_LEVEL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Hold Level</font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ep_hold_level">');

      htp.p('<option value="" >-----------</option>');
      FOR hold_level IN hold_level_cur LOOP
         IF hold_level.value = ep_one.ep_hold_level THEN
            htp.p('<option value="'||hold_level.value||'" selected>'||hold_level.meaning||'</option>');
         ELSE
            htp.p('<option value="'||hold_level.value||'" >'||hold_level.meaning||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');

      -- EP_DESC
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Description</font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ep_desc size=50 maxlength=512 value="'||ep_one.ep_desc||'">');
      htp.p('</td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Update">');
      htp.p('<input type="RESET" value="Reset">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="U">');
      htp.p('<input type="hidden" name="p_date_modified" value="'||ep_one.date_modified||'">');
      htp.p('<input type="hidden" name="p_ep_id" value="'||ep_one.ep_id||'">');
      htp.p('<input type="hidden" name="p_e_id" value="'||ep_one.e_id||'">');

      -- END
      htp.p('</form>');
      htp.p('</table>');

   -- PRINT_UPDATE
   END IF;


   IF PRINT_FOOTER THEN
      web_std_pkg.footer;
   END IF;


END ep_form;


PROCEDURE epv_form(
   p_epv_id        IN VARCHAR2 DEFAULT NULL
,  p_date_modified IN VARCHAR2 DEFAULT NULL
,  p_modified_by   IN VARCHAR2 DEFAULT NULL
,  p_created_by    IN VARCHAR2 DEFAULT NULL
,  p_e_id          IN VARCHAR2 DEFAULT NULL
,  p_e_code        IN VARCHAR2 DEFAULT NULL
,  p_ep_id         IN VARCHAR2 DEFAULT NULL
,  p_ep_code       IN VARCHAR2 DEFAULT NULL
,  p_epv_name      IN VARCHAR2 DEFAULT NULL
,  p_epv_value     IN VARCHAR2 DEFAULT NULL
,  p_epv_status    IN VARCHAR2 DEFAULT NULL
,  p_operation     IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR epv_ep_all_cur IS
      SELECT
         epv_id
      ,  epv.date_modified
      ,  epv.modified_by
      ,  epv.e_id
      ,  e_code
      ,  epv.ep_id
      ,  ep_code
      ,  ep_desc
      ,  epv_name
      ,  epv_value
      ,  DECODE(epv_status,'A','Active','I','Inactive') epv_status
      FROM event_parameter_values epv
      ,    event_parameters ep
      ,    events e
      WHERE epv.ep_id = ep.ep_id
      AND   epv.e_id = ep.e_id
      AND   ep.e_id = e.e_id
      AND   epv.ep_id = p_ep_id
      AND   epv.e_id = p_e_id
      ORDER BY epv.e_id, epv.ep_id, epv_name;


   CURSOR epv_ep_one_cur IS
      SELECT
         epv_id
      ,  TO_CHAR(date_modified,'RRRR-MON-DD HH24:MI:SS') date_modified
      ,  e_id
      ,  ep_id
      ,  epv_name
      ,  epv_value
      ,  epv_status
      FROM event_parameter_values
      WHERE epv_id = p_epv_id;
   epv_ep_one epv_ep_one_cur%ROWTYPE;


   CURSOR epv_evnt_cur(p_e_id IN NUMBER, p_ep_id IN NUMBER) IS
      SELECT e_code||'('||e_file_name||'): '||ep_code e_details
      FROM   event_parameters ep
      ,      events e
      WHERE ep.e_id = e.e_id
      AND   ep.e_id = p_e_id
      AND   ep.ep_id = p_ep_id;
   epv_evnt epv_evnt_cur%ROWTYPE;

   CURSOR epv_status_cur IS
      SELECT rv_meaning meaning
      ,      rv_low_value value
      FROM   cg_ref_codes
      WHERE  rv_domain = 'EVENT_PARAMETER_VALUES.EPV_STATUS';

   l_ep_code event_parameters.ep_code%TYPE;
   l_ep_desc event_parameters.ep_desc%TYPE;

   PRINT_REPORT_BANNER BOOLEAN DEFAULT FALSE;
   PRINT_INSERT_BANNER BOOLEAN DEFAULT FALSE;
   PRINT_UPDATE_BANNER BOOLEAN DEFAULT FALSE;

   PRINT_REPORT BOOLEAN DEFAULT TRUE;

   PRINT_REPORT_FOOTER BOOLEAN DEFAULT TRUE;
BEGIN
   IF p_operation IS NULL AND
      p_e_id IS NOT NULL AND
      p_ep_id IS NOT NULL THEN

      PRINT_REPORT_BANNER := TRUE;
   END IF;

   IF p_operation = 'N' AND
      p_e_id IS NOT NULL AND
      p_ep_id IS NOT NULL THEN

      PRINT_INSERT_BANNER := TRUE;
   END IF;

   IF p_operation = 'E' AND
      p_epv_id IS NOT NULL AND
      p_e_id IS NOT NULL AND
      p_ep_id IS NOT NULL THEN

      PRINT_UPDATE_BANNER := TRUE;
   END IF;


   IF PRINT_REPORT_BANNER THEN
      web_std_pkg.header('Event System - Threshold Parameters '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
   END IF;


   IF PRINT_INSERT_BANNER THEN

      web_std_pkg.header('Event System - New Threshold Parameters '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));

      htp.p('<form method="POST" action="evnt_web_pkg.epv_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');

      OPEN epv_evnt_cur(p_e_id, p_ep_id);
      FETCH epv_evnt_cur INTO epv_evnt;
      CLOSE epv_evnt_cur;

      -- EVENT_DETAILS
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Threshold</font></td>');
      htp.p('<td><font class="TRL">'||epv_evnt.e_details||'</font></td>');
      htp.p('</tr>');


      -- EPV_NAME
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Parameter</font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_epv_name size=25 maxlength=50 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- EPV_VALUE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Value</font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_epv_value size=100 maxlength=3999 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- EPV_STATUS
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Status</font></td>');
      htp.p('<td>');
      htp.p('<select name="p_epv_status">');

      FOR epv_status IN epv_status_cur LOOP
         htp.p('<option value="'||epv_status.value||'" >'||epv_status.meaning||'</option>');
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Create">');
      htp.p('<input type="RESET" value="Clear">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="I">');
      htp.p('<input type="hidden" name="p_e_id" value="'||p_e_id||'">');
      htp.p('<input type="hidden" name="p_ep_id" value="'||p_ep_id||'">');

      -- END
      htp.p('</form>');
      htp.p('</table>');
   -- END PRINT_INSERT_BANNER
   END IF;


   IF PRINT_UPDATE_BANNER THEN

      web_std_pkg.header('Event System - Edit Threshold Parameters '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
      htp.p('<form method="POST" action="evnt_web_pkg.epv_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');

      OPEN epv_ep_one_cur;
      FETCH epv_ep_one_cur INTO epv_ep_one;
      CLOSE epv_ep_one_cur;

      OPEN epv_evnt_cur(epv_ep_one.e_id, epv_ep_one.ep_id);
      FETCH epv_evnt_cur INTO epv_evnt;
      CLOSE epv_evnt_cur;

      -- EVENT_DETAILS
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Threshold</font></td>');
      htp.p('<td><font class="TRL">'||epv_evnt.e_details||'</font></td>');
      htp.p('</tr>');


      -- EPV_NAME
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Parameter</font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_epv_name size=25 maxlength=50 value="'||epv_ep_one.epv_name||'">');
      htp.p('</td>');
      htp.p('</tr>');

      -- EPV_VALUE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Value</font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_epv_value size=100 maxlength=3999 value="'||epv_ep_one.epv_value||'">');
      htp.p('</td>');
      htp.p('</tr>');

      -- EPV_STATUS
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Status</font></td>');
      htp.p('<td>');
      htp.p('<select name="p_epv_status">');

      FOR epv_status IN epv_status_cur LOOP
         IF epv_status.value = epv_ep_one.epv_status THEN
            htp.p('<option value="'||epv_status.value||'" selected>'||epv_status.meaning||'</option>');
         ELSE
            htp.p('<option value="'||epv_status.value||'" >'||epv_status.meaning||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Update">');
      htp.p('<input type="RESET" value="Reset">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="U">');
      htp.p('<input type="hidden" name="p_date_modified" value="'||epv_ep_one.date_modified||'">');
      htp.p('<input type="hidden" name="p_e_id" value="'||epv_ep_one.e_id||'">');
      htp.p('<input type="hidden" name="p_ep_id" value="'||epv_ep_one.ep_id||'">');
      htp.p('<input type="hidden" name="p_epv_id" value="'||p_epv_id||'">');

      -- END
      htp.p('</form>');
      htp.p('</table>');
   -- END PRINT_UPDATE_BANNER
   END IF;

   IF p_operation = 'U' THEN
      BEGIN

      PRINT_REPORT := FALSE;
      PRINT_REPORT_FOOTER := FALSE;

         evnt_api_pkg.epv(
            p_epv_id        => p_epv_id
         ,  p_date_modified => TO_DATE(p_date_modified,'RRRR-MON-DD HH24:MI:SS')
         ,  p_modified_by   => USER
         ,  p_created_by    => NULL
         ,  p_e_id          => p_e_id
         ,  p_e_code        => NULL
         ,  p_ep_id         => p_ep_id
         ,  p_ep_code       => NULL
         ,  p_epv_name      => p_epv_name
         ,  p_epv_value     => p_epv_value
         ,  p_epv_status    => p_epv_status
         ,  p_operation     => 'U');

      evnt_web_pkg.epv_form(
         p_e_id => p_e_id
      ,  p_ep_id => p_ep_id);


      EXCEPTION
         WHEN OTHERS THEN
            web_std_pkg.header('Event System - Updating Threshold Parameters '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;


   ELSIF p_operation = 'I' THEN

      PRINT_REPORT := FALSE;
      PRINT_REPORT_FOOTER := FALSE;

      BEGIN
         evnt_api_pkg.epv(
            p_epv_id        => NULL
         ,  p_date_modified => NULL
         ,  p_modified_by   => NULL
         ,  p_created_by    => USER
         ,  p_e_id          => p_e_id
         ,  p_e_code        => NULL
         ,  p_ep_id         => p_ep_id
         ,  p_ep_code       => NULL
         ,  p_epv_name      => p_epv_name
         ,  p_epv_value     => p_epv_value
         ,  p_epv_status    => p_epv_status
         ,  p_operation     => 'I');

      evnt_web_pkg.epv_form(
         p_e_id => p_e_id
      ,  p_ep_id => p_ep_id);

      EXCEPTION
         WHEN OTHERS THEN
            web_std_pkg.header('Event System - Error Creating Threshold Parameters '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;

   ELSIF p_operation = 'D' THEN

      PRINT_REPORT := FALSE;
      PRINT_REPORT_FOOTER := FALSE;

      BEGIN
         evnt_api_pkg.epv(
            p_epv_id        => p_epv_id
         ,  p_date_modified => NULL
         ,  p_modified_by   => NULL
         ,  p_created_by    => NULL
         ,  p_e_id          => NULL
         ,  p_e_code        => NULL
         ,  p_ep_id         => NULL
         ,  p_ep_code       => NULL
         ,  p_epv_name      => NULL
         ,  p_epv_value     => NULL
         ,  p_epv_status    => NULL
         ,  p_operation     => 'D');

      evnt_web_pkg.epv_form(
         p_e_id => p_e_id
      ,  p_ep_id => p_ep_id);

      EXCEPTION
         WHEN OTHERS THEN
            web_std_pkg.header('Event System - Error Deleting Threshold Parameters '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;
   END IF;


   IF PRINT_REPORT THEN

      -- start edit threshold table
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');

      SELECT ep_code, ep_desc
      INTO l_ep_code, l_ep_desc
      FROM (SELECT ep_code, ep_desc
            FROM event_parameters
            WHERE ep_id = p_ep_id
            AND e_id = p_e_id)
      WHERE ROWNUM = 1;

      htp.p('<TR>');
      htp.p('<TH colspan=4 ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">Threshold Parameters</font></TH>');
      htp.p('</TR>');

      htp.p('<TR>');
      htp.p('<TH colspan=4 ALIGN="Center" BGCOLOR="'||d_THC||'"><font class="THT">'||
               '['||l_ep_code||'] '||l_ep_desc||'</font></TH>');
      htp.p('</TR>');

      htp.p('<TR>');
      -- =========================================
      -- 10/31/2002
      -- =========================================
      --    it's too dangerous to let
      --    deletes on this form since
      --    there are no constraints and
      --    someone can easily delete all
      --    thres values "corrupting" the system
      --    ONLY ALLOW DEACTIVATION INSTEAD
      -- =========================================
      --
      --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Control Links</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Id</font></TH>');
      --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Event</font></TH>');
      --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Threshold</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Parameter</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Value</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Status</font></TH>');
      htp.p('</TR>');

      FOR epv_ep_all IN epv_ep_all_cur LOOP
         htp.p('<TR>');
         --htp.p('<TD nowrap><a href="evnt_web_pkg.epv_form?p_epv_id='||epv_ep_all.epv_id||'&p_e_id='||epv_ep_all.e_id||'&p_ep_id='||epv_ep_all.ep_id||'&p_operation=D"><font class="TRL">del</font></a></TD>');
         htp.p('<TD nowrap><font class="TRT">'||epv_ep_all.epv_id||'</font></TD>');
         --htp.p('<TD nowrap><font class="TRT">'||epv_ep_all.e_code||'</font></TD>');
         --htp.p('<TD nowrap><font class="TRT">'||epv_ep_all.ep_code||'</font></TD>');
         htp.p('<TD nowrap><a href="evnt_web_pkg.epv_form?p_epv_id='||epv_ep_all.epv_id||'&p_e_id='||epv_ep_all.e_id||'&p_ep_id='||epv_ep_all.ep_id||'&p_operation=E"><font class="TRL">'||epv_ep_all.epv_name||'</font></a></TD>');
         htp.p('<TD nowrap><font class="TRT">'||epv_ep_all.epv_value||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||epv_ep_all.epv_status||'</font></TD>');
         htp.p('</TR>');
      END LOOP;

      -- control row
      htp.p('<TR>');
      htp.p('<TD colspan=4 ALIGN="Center" BGCOLOR="#FFFFFF" nowrap>');

         -- CONTROL
         htp.p('<table cellpadding="0" cellspacing="2" border="0">');
         htp.p('<tr>');

         htp.p('<td>');
         htp.p('<form method="POST" action="evnt_web_pkg.epv_form">');
         htp.p('<input type="SUBMIT" value="New Parameter">');
         htp.p('<input type="hidden" name="p_operation" value="N">');
         htp.p('<input type="hidden" name="p_e_id" value="'||p_e_id||'">');
         htp.p('<input type="hidden" name="p_ep_id" value="'||p_ep_id||'">');
         htp.p('</form>');
         htp.p('</td>');

         htp.p('<td>');
         htp.p('<form method="POST" action="evnt_web_pkg.ep_form">');
         htp.p('<input type="SUBMIT" value="View Thresholds">');
         htp.p('<input type="hidden" name="p_operation" value="DETAIL">');
         htp.p('<input type="hidden" name="p_e_id" value="'||p_e_id||'">');
         htp.p('</form>');
         htp.p('</td>');

         htp.p('</tr>');
         htp.p('</table>');

      htp.p('</TD>');
      htp.p('</TR>');

      -- call event description
      event_header(p_e_id,4);

      htp.p('</table>');

   -- END PRINT_REPORT
   END IF;


   IF PRINT_REPORT_FOOTER THEN
      web_std_pkg.footer;
   END IF;

END epv_form;


PROCEDURE ea_form(
   p_ea_id            IN VARCHAR2 DEFAULT NULL
,  p_e_id             IN VARCHAR2 DEFAULT NULL
,  p_ep_id            IN VARCHAR2 DEFAULT NULL
,  p_h_id             IN VARCHAR2 DEFAULT NULL
,  p_s_id             IN VARCHAR2 DEFAULT NULL
,  p_sc_id            IN VARCHAR2 DEFAULT NULL
,  p_pl_id            IN VARCHAR2 DEFAULT NULL
,  p_date_modified    IN VARCHAR2 DEFAULT NULL
,  p_ea_min_interval  IN VARCHAR2 DEFAULT NULL
,  p_ea_status        IN VARCHAR2 DEFAULT NULL
,  p_ea_start_time    IN VARCHAR2 DEFAULT NULL
,  p_ea_purge_freq    IN VARCHAR2 DEFAULT NULL
,  p_operation        IN VARCHAR2 DEFAULT NULL
,  p_sort             IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR assigments_cur IS
      SELECT /*+ ORDERED */
        ea.ea_id
      , ea.e_id
      , ea.ep_id
      , TO_CHAR(ea.date_modified,'RRRR-DD-MON HH24:MI:SS') date_modified
      , h_name||DECODE(s_name,NULL,NULL,':')||s_name target
      , DECODE(pend.scnt,NULL,NULL,d_TRC_P) pend_bg
      , DECODE(old.scnt,NULL,NULL,d_TRC_O) old_bg
      , DECODE(cleared.scnt,NULL,NULL,d_TRC_C) clr_bg
      , NVL(pend.scnt,0) pend_cnt
      , NVL(old.scnt,0) old_cnt
      , NVL(cleared.scnt,0) clr_cnt
      , ea.h_id
      , ea.s_id
      , ea.sc_id
      , ea.pl_id
      , ea_min_interval
      , ea_status
      , TO_CHAR(ea_start_time,'RRRR-MON-DD HH24:MI') ea_start_time
      , remote              rmt
      , e_code_base||'/'||
           e_file_name      efil
      , ep_code
      , ea_status           stat
      , ea_min_interval     int
      , TO_CHAR(ea_start_time,'RRRR-MON-DD HH24:MI') sch_t
      , TO_CHAR(ea_started_time,'RRRR-MON-DD HH24:MI') str_t
      , TO_CHAR(ea_finished_time,'RRRR-MON-DD HH24:MI') fin_t
      , ea_last_runtime_sec rt_sec
      , ep_desc
      , pl_code
      , DECODE(SIGN(DECODE(ea_status,'I',0,'R',0,TRUNC(((SYSDATE-ea_start_time)/(1/24))*60))),
           1,d_ARC_B,DECODE(ea_status,
                        'A',d_ARC_A,
                        'I',d_ARC_I,
                        'R',d_ARC_R,
                        'B',d_ARC_B,
                            d_TRC)) rbg_col
      FROM event_assigments_v ea
      ,    event_parameters ep
      ,    page_lists pl
      ,    (SELECT ea_id, count(*) scnt
            FROM   event_triggers
            WHERE  et_phase_status = 'P'
            AND    et_status != 'CLEARED'
            GROUP BY ea_id) pend
      ,    (SELECT ea_id, scnt
            FROM   event_triggers_sum
            WHERE  et_phase_status = 'O') old
      ,    (SELECT ea_id, scnt
            FROM   event_triggers_sum
            WHERE  et_phase_status = 'C') cleared
      WHERE  ea.ep_id = ep.ep_id
      AND    ea.pl_id = pl.pl_id
      AND    ea.ea_id = pend.ea_id(+)
      AND    ea.ea_id = old.ea_id(+)
      AND    ea.ea_id = cleared.ea_id(+)
      AND    DECODE(p_operation,NULL,DECODE(p_h_id,NULL,-1,-1,-1,ea.h_id),-1) = DECODE(p_operation,NULL,DECODE(p_h_id,NULL,-1,p_h_id),-1)
      ORDER BY DECODE(p_sort,
                  '1',h_name||DECODE(s_name,NULL,NULL,':')||s_name,
                  '2',ep_code,
                  '3',pl_code,
                  '4',e_code_base||'/'||e_file_name
                     ,h_name||DECODE(s_name,NULL,NULL,':')||s_name)
      ,        DECODE(p_sort,
                  '1',ep_code,
                  '2',h_name||DECODE(s_name,NULL,NULL,':')||s_name
                     ,h_name||DECODE(s_name,NULL,NULL,':')||s_name);


   CURSOR one_assigments_cur IS
      SELECT /*+ ORDERED */
        ea.ea_id
      , ea.e_id
      , ea.ep_id
      , TO_CHAR(ea.date_modified,'RRRR-DD-MON HH24:MI:SS') date_modified
      , ea.h_id
      , ea.s_id
      , ea.sc_id
      , ea.pl_id
      , ea_min_interval
      , ea_status
      , TO_CHAR(ea_start_time,'RRRR-MON-DD HH24:MI') ea_start_time
      , ea_purge_freq
      FROM event_assigments_v ea
      ,    event_parameters ep
      ,    page_lists pl
      WHERE  ea.ep_id = ep.ep_id
      AND    ea.pl_id = pl.pl_id
      AND    ea.ea_id = p_ea_id;
   one_assigments one_assigments_cur%ROWTYPE;

   CURSOR sort_list_cur IS
      SELECT
         TRIM(TO_CHAR(ROWNUM,'9')) value
      ,  DECODE(TRIM(TO_CHAR(ROWNUM,'9')),
            '1',DECODE(p_sort,'1','selected'),
            '2',DECODE(p_sort,'2','selected'),
            '3',DECODE(p_sort,'3','selected'),
            '4',DECODE(p_sort,'4','selected')) sel_flag
      ,  DECODE(TRIM(TO_CHAR(ROWNUM,'9')),
            '1','SORT By Target',
            '2','SORT By Threshold',
            '3','SORT By Page List',
            '4','SORT By Event') display
      FROM all_objects
      WHERE ROWNUM < 5;

   CURSOR ep_all_cur IS
      SELECT ep_id, ep_code||' ('||ep_desc||')' tres
      FROM   event_parameters
      WHERE  e_id = p_e_id
      ORDER BY ep_code;

   CURSOR ep_one_cur IS
      SELECT ep_id, ep_code||' ('||ep_desc||')' tres
      FROM   event_parameters
      WHERE  e_id = p_e_id
      AND    ep_id = p_ep_id;
   ep_one ep_one_cur%ROWTYPE;

   CURSOR h_all_cur IS
      SELECT h_id, h_name
      FROM   hosts
      ORDER BY h_name;

   CURSOR h_one_cur IS
      SELECT h_id, h_name
      FROM   hosts
      WHERE h_id = p_h_id;
   h_one h_one_cur%ROWTYPE;

   CURSOR s_all_cur IS
      SELECT s_id, s_name
      FROM sids
      WHERE h_id = p_h_id
      ORDER BY s_name;

   CURSOR s_one_cur IS
      SELECT s_id, s_name
      FROM sids
      WHERE s_id = p_s_id;
   s_one s_one_cur%ROWTYPE;

   CURSOR sc_all_cur IS
      SELECT sc_id, sc_username||'@'||sc_tns_alias sc_name
      FROM sid_credentials
      WHERE s_id = p_s_id
      ORDER BY sc_username||'@'||sc_tns_alias;

   CURSOR sc_one_cur IS
      SELECT sc_id, sc_username||'@'||sc_tns_alias sc_name
      FROM sid_credentials
      WHERE s_id = p_s_id
      AND   sc_id = p_sc_id;
   sc_one sc_one_cur%ROWTYPE;

   CURSOR e_all_cur IS
      SELECT e_id, e_code||' - '||e_file_name||' ('||e_name||')' code
      FROM   events
      ORDER BY e_code;

   CURSOR e_one_cur IS
      SELECT e_id, e_code||' - '||e_file_name||' ('||e_name||')' code
      FROM   events
      WHERE  e_id = p_e_id;
   e_one e_one_cur%ROWTYPE;

   CURSOR pl_all_cur IS
      SELECT pl_id, pl_code
      FROM   page_lists
      ORDER BY pl_code;

   CURSOR pl_one_cur IS
      SELECT pl_id, pl_code
      FROM   page_lists
      WHERE  pl_id = p_pl_id;
   pl_one pl_one_cur%ROWTYPE;

   CURSOR ea_status_cur IS
      SELECT rv_meaning meaning
      ,      rv_low_value value
      FROM   cg_ref_codes
      WHERE  rv_domain = 'EVENT_ASSIGMENTS.EA_STATUS';

   l_purge_cnt NUMBER(15,0);

   l_cnt_pnd NUMBER(15,0);
   l_cnt_clr NUMBER(15,0);
   l_cnt_old NUMBER(15,0);

   l_pend_et_id NUMBER(15,0);

   l_bgc_pnd VARCHAR(10) DEFAULT d_TRC_P ;
   l_bgc_clr VARCHAR(10) DEFAULT d_TRC_C ;
   l_bgc_old VARCHAR(10) DEFAULT d_TRC_O ;

   INSERT_READY BOOLEAN DEFAULT FALSE;
   SHOW_REPORT  BOOLEAN DEFAULT FALSE;

BEGIN
   IF p_operation IS NULL THEN
      IF (p_h_id = -1 OR p_h_id IS NOT NULL) THEN
         SHOW_REPORT := TRUE;
      ELSE
         show_ea_cnt;
      END IF;
   END IF;


   IF SHOW_REPORT THEN
      web_std_pkg.header('Event System - Control Panel '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));

      -- CONTROL
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');
      htp.p('<tr>');

      htp.p('<td>');
      htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
      htp.p('<input type="SUBMIT" value="Create New">');
      htp.p('<input type="hidden" name="p_operation" value="N">');
      htp.p('</form>');
      htp.p('</td>');

      htp.p('<td>');
      htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
      htp.p('<select name="p_sort">');
      FOR sort_list IN sort_list_cur LOOP
         htp.p('<option value="'||sort_list.value||'" '||sort_list.sel_flag||'>'||sort_list.display||'</option>');
      END LOOP;
      htp.p('</select>');

      -- where clause HOST
      htp.p('<select name="p_h_id">');
      htp.p('<option value="-1" >ALL</option>');
      FOR h_all IN h_all_cur LOOP
         IF h_all.h_id = p_h_id THEN
            htp.p('<option value="'||h_all.h_id||'" selected>'||h_all.h_name||'</option>');
         ELSE
            htp.p('<option value="'||h_all.h_id||'" >'||h_all.h_name||'</option>');
         END IF;
      END LOOP;
      htp.p('</select>');


      htp.p('<input type="SUBMIT" value="Refresh">');
      htp.p('</form>');
      htp.p('</td>');


      htp.p('</tr>');
      htp.p('</table>');


      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      -- ALL RECORD CONTROL LINKS
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Control Links</font></TH>');

      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Id</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Target</font></TH>');

      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">PND</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">OLD</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">CLR</font></TH>');

      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Threshold</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Page List</font></TH>');

      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">STS</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">INT(M)</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Scheduled</font></TH>');
      --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Started</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Finished</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">RT(S)</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">RMT</font></TH>');
      --htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Event File</font></TH>');

      FOR assigments IN assigments_cur LOOP

         htp.p('<TR BGCOLOR="'||assigments.rbg_col||'">');

         -- ALL RECORD CONTROL LINKS
         /* EDIT LINK */
         htp.p('<TD nowrap><a href='||web_std_pkg.encode_url('"evnt_web_pkg.ea_form?p_ea_id='||assigments.ea_id||
                                                       '&p_operation=xE">')||'<font class="TRL">Edit</font></a>'||
         '<font class="TRT">|</font>'||
         /* COPY LINK */
         '<a href='||web_std_pkg.encode_url('"evnt_web_pkg.ea_form?p_ea_id='||assigments.ea_id||
                                                       '&p_operation=xC1">')||'<font class="TRL">Copy</font></a>'||
         '<font class="TRT">|</font>'||
         /* DELETE LINK */
         '<a href='||web_std_pkg.encode_url('"evnt_web_pkg.ea_form?p_ea_id='||assigments.ea_id||
                                                       '&p_operation=D">')||'<font class="TRL">Delete</font></a>'||
         '<font class="TRT">|</font>'||
         /* PURGE LINK */
         '<a href='||web_std_pkg.encode_url('"evnt_web_pkg.ea_form?p_ea_id='||assigments.ea_id||
                                                       '&p_operation=PURGE">')||'<font class="TRL">Purge</font></a></TD>');



         htp.p('<TD nowrap><font class="TRT">'||assigments.ea_id||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||assigments.target||'</font></TD>');

         -- @HERE
         if ( assigments.pend_cnt > 0 )
         then
            select max(et_id)
              into l_pend_et_id
              from event_triggers
             --where et_phase_status = 'P'
             where decode(et_phase_status,'P','P',null) = 'P'
               and et_status != 'CLEARED'
               and ea_id = assigments.ea_id;

             htp.p('<TD nowrap BGCOLOR="'||NVL(assigments.pend_bg,assigments.rbg_col)||'"><a href="evnt_web_pkg.get_trigger?p_et_id='||l_pend_et_id||'"><font class="TRL">'||assigments.pend_cnt||'</font></a></TD>');
         else
             htp.p('<TD nowrap BGCOLOR="'||NVL(assigments.pend_bg,assigments.rbg_col)||'"><a href="evnt_web_pkg.disp_triggers?p_ea_id='||assigments.ea_id||'&p_phase=P"><font class="TRL">'||assigments.pend_cnt||'</font></a></TD>');
         end if;

         htp.p('<TD nowrap BGCOLOR="'||NVL(assigments.old_bg,assigments.rbg_col)||'"><a href="evnt_web_pkg.disp_triggers?p_ea_id='||assigments.ea_id||'&p_phase=O"><font class="TRL">'||assigments.old_cnt||'</font></a></TD>');
         htp.p('<TD nowrap BGCOLOR="'||NVL(assigments.clr_bg,assigments.rbg_col)||'"><a href="evnt_web_pkg.disp_triggers?p_ea_id='||assigments.ea_id||'&p_phase=C"><font class="TRL">'||assigments.clr_cnt||'</font></a></TD>');
         --htp.p('<TD nowrap BGCOLOR="'||NVL(assigments.clr_bg,assigments.rbg_col)||'"><a href="evnt_web_pkg.disp_triggers?p_ea_id='||assigments.ea_id||'&p_h_id='||assigments.h_id||'&p_phase=C"><font class="TRL">'||assigments.clr_cnt||'</font></a></TD>');



         htp.p('<TD nowrap><a href="evnt_web_pkg.epv_form?p_ep_id='||assigments.ep_id||'&p_e_id='||assigments.e_id||'"><font class="TRL">'||assigments.ep_code||'</font></a></TD>');
         htp.p('<TD nowrap><font class="TRT">'||assigments.pl_code||'</font></TD>');

         htp.p('<TD nowrap><font class="TRT">'||assigments.stat||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||assigments.int||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||assigments.sch_t||'</font></TD>');
         --htp.p('<TD nowrap><font class="TRT">'||assigments.str_t||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||assigments.fin_t||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||assigments.rt_sec||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||assigments.rmt||'</font></TD>');
         --htp.p('<TD nowrap><font class="TRT">'||assigments.efil||'</font></TD>');

         htp.p('</TR>');
      END LOOP;

      htp.p('</TABLE>');


      web_std_pkg.footer;


   ELSIF p_operation = 'xE' THEN
      -- EDIT pass get IDS
      OPEN one_assigments_cur;
      FETCH one_assigments_cur INTO one_assigments;
      CLOSE one_assigments_cur;

      evnt_web_pkg.ea_form(
         p_ea_id => one_assigments.ea_id
      ,  p_e_id  => one_assigments.e_id
      ,  p_ep_id => one_assigments.ep_id
      ,  p_h_id  => one_assigments.h_id
      ,  p_s_id  => one_assigments.s_id
      ,  p_sc_id => one_assigments.sc_id
      ,  p_pl_id => one_assigments.pl_id
      ,  p_date_modified   => one_assigments.date_modified
      ,  p_ea_min_interval => one_assigments.ea_min_interval
      ,  p_ea_status       => one_assigments.ea_status
      ,  p_ea_start_time   => one_assigments.ea_start_time
      ,  p_ea_purge_freq   => one_assigments.ea_purge_freq
      ,  p_sort            => p_sort
      ,  p_operation       => 'E');



   ELSIF p_operation = 'xC1' THEN
      -- COPY-1 pass get IDS
      OPEN one_assigments_cur;
      FETCH one_assigments_cur INTO one_assigments;
      CLOSE one_assigments_cur;

      evnt_web_pkg.ea_form(
         p_ea_id => one_assigments.ea_id
      ,  p_e_id  => one_assigments.e_id
      ,  p_ep_id => one_assigments.ep_id
      ,  p_h_id  => one_assigments.h_id
      ,  p_s_id  => one_assigments.s_id
      ,  p_sc_id => one_assigments.sc_id
      ,  p_pl_id => one_assigments.pl_id
      ,  p_ea_min_interval => one_assigments.ea_min_interval
      ,  p_ea_status       => one_assigments.ea_status
      ,  p_ea_start_time   => one_assigments.ea_start_time
      ,  p_ea_purge_freq   => one_assigments.ea_purge_freq
      ,  p_sort            => p_sort
      ,  p_operation       => 'C1');



   ELSIF p_operation = 'N' THEN
      web_std_pkg.header('Event System - New Event Assignment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
      htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');


      -- HOST
      IF p_h_id IS NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Host: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_h_id">');

         htp.p('<option value="" >------------</option>');
         FOR h_all IN h_all_cur LOOP
            htp.p('<option value="'||h_all.h_id||'" >'||h_all.h_name||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      ELSIF p_h_id IS NOT NULL THEN
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Host: </font></td>');
         OPEN h_one_cur;
         FETCH h_one_cur INTO h_one;
         CLOSE h_one_cur;
         htp.p('<td><font class="TRL">'||h_one.h_name||'</font></td>');
         htp.p('</tr>');
         htp.p('<input type="hidden" name="p_h_id" value="'||h_one.h_id||'">');
      END IF;


      -- SID
      IF p_h_id IS NOT NULL AND
         p_s_id IS NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_s_id">');

         htp.p('<option value="" >------------</option>');
         FOR s_all IN s_all_cur LOOP
            htp.p('<option value="'||s_all.s_id||'" >'||s_all.s_name||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      ELSIF p_h_id IS NOT NULL AND
            p_s_id IS NOT NULL THEN

         OPEN s_one_cur;
         FETCH s_one_cur INTO s_one;
         CLOSE s_one_cur;

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid: </font></td>');
         htp.p('<td><font class="TRL">'||s_one.s_name||'</font></td>');
         htp.p('</tr>');
         htp.p('<input type="hidden" name="p_s_id" value="'||s_one.s_id||'">');

      ELSE
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid: </font></td>');
         htp.p('<td><font class="TRT"></font></td>');
         htp.p('</tr>');
      END IF;



      -- SID CREDENTIAL
      IF p_s_id IS NOT NULL AND
         p_sc_id IS NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_sc_id">');

         FOR sc_all IN sc_all_cur LOOP
            htp.p('<option value="'||sc_all.sc_id||'" >'||sc_all.sc_name||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      ELSIF p_s_id IS NOT NULL AND
            p_sc_id IS NOT NULL THEN

         OPEN sc_one_cur;
         FETCH sc_one_cur INTO sc_one;
         CLOSE sc_one_cur;

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
         htp.p('<td><font class="TRL">'||sc_one.sc_name||'</font></td>');
         htp.p('</tr>');
         htp.p('<input type="hidden" name="p_sc_id" value="'||sc_one.sc_id||'">');

      ELSE
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
         htp.p('<td><font class="TRT"></font></td>');
         htp.p('</tr>');
      END IF;



      -- EVENT
      IF p_e_id IS NULL AND
         p_ep_id IS NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Event: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_e_id">');

         htp.p('<option value="" >------------</option>');
         FOR e_all IN e_all_cur LOOP
            htp.p('<option value="'||e_all.e_id||'" >'||e_all.code||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      ELSIF p_e_id IS NOT NULL THEN
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Event: </font></td>');
         OPEN e_one_cur;
         FETCH e_one_cur INTO e_one;
         CLOSE e_one_cur;
         htp.p('<td><font class="TRL">'||e_one.code||'</font></td>');
         htp.p('</tr>');
         htp.p('<input type="hidden" name="p_e_id" value="'||e_one.e_id||'">');
      END IF;


      -- THRESHOLD
      IF p_e_id IS NOT NULL AND
         p_ep_id IS NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Threshold: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_ep_id">');

         FOR ep_all IN ep_all_cur LOOP
            htp.p('<option value="'||ep_all.ep_id||'" >'||ep_all.tres||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      ELSIF p_e_id IS NOT NULL AND
            p_ep_id IS NOT NULL THEN

         OPEN ep_one_cur;
         FETCH ep_one_cur INTO ep_one;
         CLOSE ep_one_cur;

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Threshold: </font></td>');
         htp.p('<td><font class="TRL">'||ep_one.tres||'</font></td>');
         htp.p('</tr>');
         htp.p('<input type="hidden" name="p_ep_id" value="'||ep_one.ep_id||'">');

      ELSE
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Threshold: </font></td>');
         htp.p('<td><font class="TRT"></font></td>');
         htp.p('</tr>');
      END IF;



      -- PAGE LIST
      IF p_pl_id IS NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Page List: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_pl_id">');

         htp.p('<option value="" >------------</option>');
         FOR pl_all IN pl_all_cur LOOP
            htp.p('<option value="'||pl_all.pl_id||'" >'||pl_all.pl_code||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      ELSIF p_pl_id IS NOT NULL THEN
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Page List: </font></td>');
         OPEN pl_one_cur;
         FETCH pl_one_cur INTO pl_one;
         CLOSE pl_one_cur;
         htp.p('<td><font class="TRL">'||pl_one.pl_code||'</font></td>');
         htp.p('</tr>');
         htp.p('<input type="hidden" name="p_pl_id" value="'||pl_one.pl_id||'">');
      END IF;


      -- EA_MIN_INTERVAL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Interval(MIN): </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_min_interval size=5 maxlength=5 value="'||p_ea_min_interval||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_PURGE_FREQ
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Keep History(DAY): </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_purge_freq size=3 maxlength=3 value="'||NVL(p_ea_purge_freq,'-1')||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_STATUS
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Status: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ea_status">');

      FOR ea_status IN ea_status_cur LOOP
         IF ea_status.value = p_ea_status THEN
            htp.p('<option value="'||ea_status.value||'" selected>'||ea_status.meaning||'</option>');
         ELSE
            htp.p('<option value="'||ea_status.value||'" >'||ea_status.meaning||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_START_TIME
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Start Time: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_start_time size=19 maxlength=19 value="'||NVL(p_ea_start_time,TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI'))||'">');
      htp.p('</td>');
      htp.p('</tr>');

      IF p_e_id            IS NOT NULL AND
         p_ep_id           IS NOT NULL AND
         p_h_id            IS NOT NULL AND
         p_pl_id           IS NOT NULL AND
         p_ea_start_time   IS NOT NULL THEN

         INSERT_READY := TRUE;
      ELSE
         INSERT_READY := FALSE;
      END IF;


      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      IF INSERT_READY THEN
         htp.p('<input type="SUBMIT" value="Create">');
      ELSE
         htp.p('<input type="SUBMIT" value="Next">');
      END IF;
      htp.p('<input type="RESET" value="Reset">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      IF INSERT_READY THEN
         htp.p('<input type="hidden" name="p_operation" value="I">');
      ELSE
         htp.p('<input type="hidden" name="p_operation" value="N">');
      END IF;


      -- END
      htp.p('</form>');
      htp.p('</table>');
      web_std_pkg.footer;
   -- END NEW


   ELSIF p_operation = 'E' THEN
      web_std_pkg.header('Event System - Edit Event Assignment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
      htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');

      -- HOST
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Host: </font></td>');
      OPEN h_one_cur;
      FETCH h_one_cur INTO h_one;
      CLOSE h_one_cur;
      htp.p('<td><font class="TRL">'||h_one.h_name||'</font></td>');
      htp.p('</tr>');
      htp.p('<input type="hidden" name="p_h_id" value="'||h_one.h_id||'">');


      -- SID
      OPEN s_one_cur;
      FETCH s_one_cur INTO s_one;
      CLOSE s_one_cur;

      htp.p('<tr>');
      htp.p('<td><font class="TRT">Sid: </font></td>');
      htp.p('<td><font class="TRL">'||s_one.s_name||'</font></td>');
      htp.p('</tr>');
      htp.p('<input type="hidden" name="p_s_id" value="'||s_one.s_id||'">');


      -- SID CREDENTIAL
      IF p_s_id IS NOT NULL AND
         p_sc_id IS NOT NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_sc_id">');

         FOR sc_all IN sc_all_cur LOOP
            IF sc_all.sc_id = p_sc_id THEN
               htp.p('<option value="'||sc_all.sc_id||'" selected>'||sc_all.sc_name||'</option>');
            ELSE
               htp.p('<option value="'||sc_all.sc_id||'" >'||sc_all.sc_name||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      ELSE
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
         htp.p('<td><font class="TRT"></font></td>');
         htp.p('</tr>');
      END IF;


      -- EVENT
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Event: </font></td>');
      OPEN e_one_cur;
      FETCH e_one_cur INTO e_one;
      CLOSE e_one_cur;
      htp.p('<td><font class="TRL">'||e_one.code||'</font></td>');
      htp.p('</tr>');
      htp.p('<input type="hidden" name="p_e_id" value="'||e_one.e_id||'">');


      -- THRESHOLD
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Threshold: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ep_id">');

      FOR ep_all IN ep_all_cur LOOP
         IF ep_all.ep_id = p_ep_id THEN
            htp.p('<option value="'||ep_all.ep_id||'" selected>'||ep_all.tres||'</option>');
         ELSE
            htp.p('<option value="'||ep_all.ep_id||'" >'||ep_all.tres||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');



      -- PAGE LIST
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Page List: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_pl_id">');

      FOR pl_all IN pl_all_cur LOOP
         IF pl_all.pl_id = p_pl_id THEN
            htp.p('<option value="'||pl_all.pl_id||'" selected>'||pl_all.pl_code||'</option>');
         ELSE
            htp.p('<option value="'||pl_all.pl_id||'" >'||pl_all.pl_code||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_MIN_INTERVAL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Interval(MIN): </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_min_interval size=5 maxlength=5 value="'||p_ea_min_interval||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_PURGE_FREQ
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Keep History(DAY): </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_purge_freq size=3 maxlength=3 value="'||NVL(p_ea_purge_freq,'-1')||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_STATUS
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Status: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ea_status">');

      FOR ea_status IN ea_status_cur LOOP
         IF ea_status.value = p_ea_status THEN
            htp.p('<option value="'||ea_status.value||'" selected>'||ea_status.meaning||'</option>');
         ELSE
            htp.p('<option value="'||ea_status.value||'" >'||ea_status.meaning||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_START_TIME
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Start Time: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_start_time size=19 maxlength=19 value="'||NVL(p_ea_start_time,TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI'))||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Update">');
      htp.p('<input type="RESET" value="Reset">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="U">');
      htp.p('<input type="hidden" name="p_ea_id" value="'||p_ea_id||'">');
      htp.p('<input type="hidden" name="p_date_modified" value="'||p_date_modified||'">');


      -- END
      htp.p('</form>');
      htp.p('</table>');
      web_std_pkg.footer;
   -- END EDIT


   -- COPY FIRST PASS
   ELSIF p_operation = 'C1' THEN
      web_std_pkg.header('Event System - Copy Event Assignment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
      htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');

      -- HOST
      --
      -- NOTE:
      --    first pass let the user change the HOST
      --    second pass set p_ea_id to NULL
      --

      htp.p('<tr>');
      htp.p('<td><font class="TRT">Host: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_h_id">');

      FOR h_all IN h_all_cur LOOP
         IF h_all.h_id = p_h_id THEN
            htp.p('<option value="'||h_all.h_id||'" selected>'||h_all.h_name||'</option>');
         ELSE
            htp.p('<option value="'||h_all.h_id||'" >'||h_all.h_name||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- SID
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Sid: </font></td>');
      htp.p('<td><font class="TRT"></font></td>');
      htp.p('</tr>');


      -- SID CREDENTIAL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
      htp.p('<td><font class="TRT"></font></td>');
      htp.p('</tr>');


      -- EVENT
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Event: </font></td>');
      OPEN e_one_cur;
      FETCH e_one_cur INTO e_one;
      CLOSE e_one_cur;
      htp.p('<td><font class="TRL">'||e_one.code||'</font></td>');
      htp.p('</tr>');
      htp.p('<input type="hidden" name="p_e_id" value="'||e_one.e_id||'">');


      -- THRESHOLD
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Threshold: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ep_id">');

      FOR ep_all IN ep_all_cur LOOP
         IF ep_all.ep_id = p_ep_id THEN
            htp.p('<option value="'||ep_all.ep_id||'" selected>'||ep_all.tres||'</option>');
         ELSE
            htp.p('<option value="'||ep_all.ep_id||'" >'||ep_all.tres||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- PAGE LIST
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Page List: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_pl_id">');

      FOR pl_all IN pl_all_cur LOOP
         IF pl_all.pl_id = p_pl_id THEN
            htp.p('<option value="'||pl_all.pl_id||'" selected>'||pl_all.pl_code||'</option>');
         ELSE
            htp.p('<option value="'||pl_all.pl_id||'" >'||pl_all.pl_code||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_MIN_INTERVAL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Interval(MIN): </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_min_interval size=5 maxlength=5 value="'||p_ea_min_interval||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_PURGE_FREQ
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Keep History(DAY): </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_purge_freq size=3 maxlength=3 value="'||NVL(p_ea_purge_freq,'-1')||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_STATUS
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Status: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ea_status">');

      FOR ea_status IN ea_status_cur LOOP
         IF ea_status.value = p_ea_status THEN
            htp.p('<option value="'||ea_status.value||'" selected>'||ea_status.meaning||'</option>');
         ELSE
            htp.p('<option value="'||ea_status.value||'" >'||ea_status.meaning||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_START_TIME
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Start Time: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_start_time size=19 maxlength=19 value="'||NVL(p_ea_start_time,TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI'))||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Next">');
      htp.p('<input type="RESET" value="Reset">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="C2">');

      -- END
      htp.p('</form>');
      htp.p('</table>');
      web_std_pkg.footer;

   -- END COPY FIRST PASS


   -- COPY SECOND PASS
   ELSIF p_operation = 'C2' OR
         p_operation = 'Next' THEN
      web_std_pkg.header('Event System - Copy Event Assignment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
      htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');

      -- HOST
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Host: </font></td>');
      OPEN h_one_cur;
      FETCH h_one_cur INTO h_one;
      CLOSE h_one_cur;
      htp.p('<td><font class="TRL">'||h_one.h_name||'</font></td>');
      htp.p('</tr>');
      htp.p('<input type="hidden" name="p_h_id" value="'||h_one.h_id||'">');


      -- SID
      IF p_h_id IS NOT NULL AND
         p_s_id IS NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_s_id">');

         htp.p('<option value="" >------------</option>');
         FOR s_all IN s_all_cur LOOP
            htp.p('<option value="'||s_all.s_id||'" >'||s_all.s_name||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      -- just display the
      -- SID after the second pass when
      --
      ELSIF p_h_id IS NOT NULL AND
            p_s_id IS NOT NULL THEN

         OPEN s_one_cur;
         FETCH s_one_cur INTO s_one;
         CLOSE s_one_cur;

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid: </font></td>');
         htp.p('<td><font class="TRL">'||s_one.s_name||'</font></td>');
         htp.p('</tr>');
         htp.p('<input type="hidden" name="p_s_id" value="'||s_one.s_id||'">');

      ELSE
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid: </font></td>');
         htp.p('<td><font class="TRT"></font></td>');
         htp.p('</tr>');
      END IF;



      -- SID CREDENTIAL
      IF p_s_id IS NOT NULL AND
         p_sc_id IS NULL THEN

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
         htp.p('<td>');
         htp.p('<select name="p_sc_id">');

         FOR sc_all IN sc_all_cur LOOP
            htp.p('<option value="'||sc_all.sc_id||'" >'||sc_all.sc_name||'</option>');
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
         htp.p('</tr>');

      ELSIF p_s_id IS NOT NULL AND
            p_sc_id IS NOT NULL THEN

         OPEN sc_one_cur;
         FETCH sc_one_cur INTO sc_one;
         CLOSE sc_one_cur;

         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
         htp.p('<td><font class="TRL">'||sc_one.sc_name||'</font></td>');
         htp.p('</tr>');
         htp.p('<input type="hidden" name="p_sc_id" value="'||sc_one.sc_id||'">');

      ELSE
         htp.p('<tr>');
         htp.p('<td><font class="TRT">Sid Cred.: </font></td>');
         htp.p('<td><font class="TRT"></font></td>');
         htp.p('</tr>');
      END IF;


      -- EVENT
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Event: </font></td>');
      OPEN e_one_cur;
      FETCH e_one_cur INTO e_one;
      CLOSE e_one_cur;
      htp.p('<td><font class="TRL">'||e_one.code||'</font></td>');
      htp.p('</tr>');
      htp.p('<input type="hidden" name="p_e_id" value="'||e_one.e_id||'">');


      -- THRESHOLD
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Threshold: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ep_id">');

      FOR ep_all IN ep_all_cur LOOP
         IF ep_all.ep_id = p_ep_id THEN
            htp.p('<option value="'||ep_all.ep_id||'" selected>'||ep_all.tres||'</option>');
         ELSE
            htp.p('<option value="'||ep_all.ep_id||'" >'||ep_all.tres||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- PAGE LIST
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Page List: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_pl_id">');

      FOR pl_all IN pl_all_cur LOOP
         IF pl_all.pl_id = p_pl_id THEN
            htp.p('<option value="'||pl_all.pl_id||'" selected>'||pl_all.pl_code||'</option>');
         ELSE
            htp.p('<option value="'||pl_all.pl_id||'" >'||pl_all.pl_code||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_MIN_INTERVAL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Interval(MIN): </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_min_interval size=5 maxlength=5 value="'||p_ea_min_interval||'">');
      htp.p('</td>');
      htp.p('</tr>');

      -- EA_PURGE_FREQ
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Keep History(DAY): </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_purge_freq size=3 maxlength=3 value="'||NVL(p_ea_purge_freq,'-1')||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_STATUS
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Status: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ea_status">');

      FOR ea_status IN ea_status_cur LOOP
         IF ea_status.value = p_ea_status THEN
            htp.p('<option value="'||ea_status.value||'" selected>'||ea_status.meaning||'</option>');
         ELSE
            htp.p('<option value="'||ea_status.value||'" >'||ea_status.meaning||'</option>');
         END IF;
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');


      -- EA_START_TIME
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Start Time: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ea_start_time size=19 maxlength=19 value="'||NVL(p_ea_start_time,TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI'))||'">');
      htp.p('</td>');
      htp.p('</tr>');


      -- CONTROLS/OPERATION
      htp.p('<tr>');
      htp.p('<td></td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" name="p_operation" value="Next">');
      htp.p('<input type="SUBMIT" name="p_operation" value="Create">');
      htp.p('<input type="RESET" value="Reset">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN

      -- END
      htp.p('</form>');
      htp.p('</table>');
      web_std_pkg.footer;
   -- END COPY SECOND PASS


   ELSIF p_operation = 'PURGE-INTERNAL' THEN

      delete_commit('DELETE event_trigger_notif '||
                    'WHERE et_id IN (SELECT et_id '||
                                    'FROM event_triggers '||
                                    'WHERE ea_id = '||p_ea_id||')');

      delete_commit('DELETE event_trigger_notes '||
                    'WHERE et_id IN (SELECT et_id '||
                                    'FROM event_triggers '||
                                    'WHERE ea_id = '||p_ea_id||')');

      delete_commit('DELETE /*+ RULE */ event_trigger_output '||
                    'WHERE et_id IN (SELECT et_id '||
                                    'FROM event_triggers '||
                                    'WHERE ea_id = '||p_ea_id||')');

      delete_commit('DELETE /*+ RULE */ event_trigger_details '||
                    'WHERE et_id IN (SELECT et_id '||
                                    'FROM event_triggers '||
                                    'WHERE ea_id = '||p_ea_id||')');

      delete_commit('DELETE event_triggers '||
                    'WHERE ea_id = '||p_ea_id);


      delete_commit('DELETE event_holds '||
                    'WHERE  eh_set_by_type = ''E'' '||
                    'AND    eh_set_by_id = '||p_ea_id);



   ELSIF p_operation = 'PURGE' THEN
      web_std_pkg.header('Event System -  WARNING '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
      htp.p('<b>WARNING</b>: Are you sure you want to purge Event Assigment '||p_ea_id||':');
      htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');
      htp.p('<input type="hidden" name="p_ea_id" value="'||p_ea_id||'">');
      htp.p('<input type="SUBMIT" name="p_operation" value="CONFIRM-Purge">');
      htp.p('<input type="SUBMIT" name="p_operation" value="CANCEL">');
      web_std_pkg.footer;


   -- CONFIRM type actions
   --
   ELSIF p_operation = 'CONFIRM-Purge' THEN
      BEGIN
         evnt_web_pkg.ea_form(
            p_ea_id => p_ea_id
         ,  p_operation => 'PURGE-INTERNAL');

         evnt_web_pkg.ea_form;

      EXCEPTION
         WHEN OTHERS THEN
            web_std_pkg.header('Event System - Error Purging Event Assigment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;


   ELSIF p_operation = 'CONFIRM-Delete/Purge' THEN
      BEGIN
         evnt_web_pkg.ea_form(
            p_ea_id => p_ea_id
         ,  p_operation => 'PURGE-INTERNAL');

         evnt_api_pkg.ea(
            p_ea_id             => p_ea_id
         ,  p_e_id              => NULL
         ,  p_e_code            => NULL
         ,  p_ep_id             => NULL
         ,  p_ep_code           => NULL
         ,  p_h_id              => NULL
         ,  p_h_name            => NULL
         ,  p_s_id              => NULL
         ,  p_s_name            => NULL
         ,  p_sc_id             => NULL
         ,  p_sc_username       => NULL
         ,  p_pl_id             => NULL
         ,  p_pl_code           => NULL
         ,  p_date_modified     => NULL
         ,  p_modified_by       => NULL
         ,  p_created_by        => NULL
         ,  p_ea_min_interval   => NULL
         ,  p_ea_status         => NULL
         ,  p_ea_start_time     => NULL
         ,  p_ea_purge_freq     => NULL
         ,  p_operation         => 'D');

         evnt_web_pkg.ea_form;

      EXCEPTION
         WHEN OTHERS THEN
            web_std_pkg.header('Event System - Error Deleting Event Assigment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;

   ELSIF p_operation = 'CONFIRM-Delete' THEN
      BEGIN
         evnt_api_pkg.ea(
            p_ea_id             => p_ea_id
         ,  p_e_id              => NULL
         ,  p_e_code            => NULL
         ,  p_ep_id             => NULL
         ,  p_ep_code           => NULL
         ,  p_h_id              => NULL
         ,  p_h_name            => NULL
         ,  p_s_id              => NULL
         ,  p_s_name            => NULL
         ,  p_sc_id             => NULL
         ,  p_sc_username       => NULL
         ,  p_pl_id             => NULL
         ,  p_pl_code           => NULL
         ,  p_date_modified     => NULL
         ,  p_modified_by       => NULL
         ,  p_created_by        => NULL
         ,  p_ea_min_interval   => NULL
         ,  p_ea_status         => NULL
         ,  p_ea_start_time     => NULL
         ,  p_ea_purge_freq     => NULL
         ,  p_operation         => 'D');

         evnt_web_pkg.ea_form;
      EXCEPTION
         WHEN OTHERS THEN
            web_std_pkg.header('Event System - Error Deleting Event Assigment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;


   ELSIF p_operation = 'CANCEL' THEN
      evnt_web_pkg.ea_form;


   ELSIF p_operation = 'D' THEN

      SELECT count(*)
      INTO l_purge_cnt
      FROM event_triggers
      WHERE ea_id = p_ea_id;

      IF l_purge_cnt > 0 THEN
         web_std_pkg.header('Event System -  WARNING '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
         htp.p('<b>WARNING</b>: Are you sure you want to delete Event Assigment '||p_ea_id||'?');
         htp.p('<b>WARNING</b>: Event Assigment has active triggers that need to be purged please confirm:');
         htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
         htp.p('<table cellpadding="0" cellspacing="2" border="0">');
         htp.p('<input type="hidden" name="p_ea_id" value="'||p_ea_id||'">');
         htp.p('<input type="SUBMIT" name="p_operation" value="CONFIRM-Delete/Purge">');
         htp.p('<input type="SUBMIT" name="p_operation" value="CANCEL">');
         web_std_pkg.footer;

      ELSE
         web_std_pkg.header('Event System -  WARNING '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
         htp.p('<b>WARNING</b>: Are you sure you want to delete Event Assigment '||p_ea_id||':');
         htp.p('<form method="POST" action="evnt_web_pkg.ea_form">');
         htp.p('<table cellpadding="0" cellspacing="2" border="0">');
         htp.p('<input type="hidden" name="p_ea_id" value="'||p_ea_id||'">');
         htp.p('<input type="SUBMIT" name="p_operation" value="CONFIRM-Delete">');
         htp.p('<input type="SUBMIT" name="p_operation" value="CANCEL">');
         web_std_pkg.footer;

      END IF;

   ELSIF p_operation = 'U' THEN
      BEGIN
         evnt_api_pkg.ea(
            p_ea_id             => p_ea_id
         ,  p_e_id              => p_e_id
         ,  p_e_code            => NULL
         ,  p_ep_id             => p_ep_id
         ,  p_ep_code           => NULL
         ,  p_h_id              => p_h_id
         ,  p_h_name            => NULL
         ,  p_s_id              => p_s_id
         ,  p_s_name            => NULL
         ,  p_sc_id             => p_sc_id
         ,  p_sc_username       => NULL
         ,  p_pl_id             => p_pl_id
         ,  p_pl_code           => NULL
         ,  p_date_modified     => TO_DATE(p_date_modified,'RRRR-DD-MON HH24:MI:SS')
         ,  p_modified_by       => USER
         ,  p_created_by        => NULL
         ,  p_ea_min_interval   => p_ea_min_interval
         ,  p_ea_status         => p_ea_status
         ,  p_ea_start_time     => TO_DATE(p_ea_start_time,'RRRR-MON-DD HH24:MI')
         ,  p_ea_purge_freq     => p_ea_purge_freq
         ,  p_operation         => 'U');

      evnt_web_pkg.ea_form(p_h_id=>p_h_id);

      EXCEPTION
         WHEN OTHERS THEN
            web_std_pkg.header('Event System - Error Updating Event Assigment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;


   ELSIF p_operation = 'I' OR
         p_operation = 'Create' THEN
      BEGIN
         evnt_api_pkg.ea(
            p_ea_id             => NULL
         ,  p_e_id              => p_e_id
         ,  p_e_code            => NULL
         ,  p_ep_id             => p_ep_id
         ,  p_ep_code           => NULL
         ,  p_h_id              => p_h_id
         ,  p_h_name            => NULL
         ,  p_s_id              => p_s_id
         ,  p_s_name            => NULL
         ,  p_sc_id             => p_sc_id
         ,  p_sc_username       => NULL
         ,  p_pl_id             => p_pl_id
         ,  p_pl_code           => NULL
         ,  p_date_modified     => NULL
         ,  p_modified_by       => NULL
         ,  p_created_by        => USER
         ,  p_ea_min_interval   => p_ea_min_interval
         ,  p_ea_status         => p_ea_status
         ,  p_ea_start_time     => TO_DATE(p_ea_start_time,'RRRR-MON-DD HH24:MI')
         ,  p_ea_purge_freq     => p_ea_purge_freq
         ,  p_operation         => 'I');

      evnt_web_pkg.ea_form(p_h_id=>p_h_id);

      EXCEPTION
         WHEN OTHERS THEN
            web_std_pkg.header('Event System - Error Creating Event Assigment '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'));
            htp.p('<b>ERROR</b>: '||SQLERRM);
            web_std_pkg.footer;
      END;



   -- END operation IF
   END IF;

END ea_form;


PROCEDURE display_notif(
   p_et_id IN NUMBER)
IS
   CURSOR notif_cur IS
      SELECT
         etn_id
      ,  et_id
      ,  etn.a_id
      ,  etn.ae_id
      ,  etn_date
      ,  TO_CHAR(etn_date,'RRRR-MON-DD HH24:MI:SS') stn_date_char
      ,  etn_type
      ,  DECODE(etn_type,'P','Primary','S','Secondary') etn_type_long
      ,  etn_status
      ,  DECODE(etn_status,'C','Complete','E','Error') etn_status_long
      ,  a.a_name||'('||ae.ae_email||')' admin_email
      ,  ae.ae_desc
      FROM event_trigger_notif etn
      ,    admins a
      ,    admin_emails ae
      WHERE etn.a_id = ae.a_id
      AND   etn.ae_id = ae.ae_id
      AND   ae.a_id = a.a_id
      AND   etn.et_id = p_et_id
      ORDER BY et_id
      ,        etn_date
      ,        etn.ae_id;
BEGIN
   web_std_pkg.print_styles;

   -- HEADER
   htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
   htp.p('<TR>');
   htp.p('<TH ALIGN="Center" BGCOLOR="'||d_THC||'" colspan=6><font class="THT">Notifications</font></TH>');
   htp.p('</TR>');

   htp.p('<TR>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Id</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Admin</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Name</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Type</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Date</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Status</font></TH>');
   htp.p('</TR>');

   FOR notif IN notif_cur LOOP
      -- DATA
      htp.p('<TR BGCOLOR="'||d_TRC||'">');
      htp.p('<TD nowrap><font class="TRT">'||notif.etn_id||'</font></TD>');
      htp.p('<TD nowrap><font class="TRT">'||notif.admin_email||'</font></TD>');
      htp.p('<TD nowrap><font class="TRT">'||notif.ae_desc||'</font></TD>');
      htp.p('<TD nowrap><font class="TRT">'||notif.etn_type_long||'</font></TD>');
      htp.p('<TD nowrap><font class="TRT">'||notif.stn_date_char||'</font></TD>');
      htp.p('<TD nowrap><font class="TRT">'||notif.etn_status_long||'</font></TD>');
      htp.p('</TR>');
   END LOOP;

   -- CLOSE TABLE
   htp.p('</TABLE>');
END display_notif;


PROCEDURE trg_notes(
   p_et_id     IN VARCHAR2 DEFAULT NULL
,  p_note      IN VARCHAR2 DEFAULT NULL
,  p_operation IN VARCHAR2 DEFAULT NULL
,  p_format    IN VARCHAR2 DEFAULT NULL)
IS
   -- NOTE:
   --    if a user places a string > 32767 (32K)
   --    into p_note OAS/IAS will fail with the
   --    following error:
   --
   --       ORA-01460: unimplemented or unreasonable conversion requested
   --
   --    This errors out before it gets to TRG_NOTES
   --    that's why I don't event check if LENGTH(p_note) > 32767
   --    simply impossible ...
   --
   CURSOR notes_cur IS
      SELECT tn_note lines
      FROM event_trigger_notes
      WHERE et_id = p_et_id
      ORDER BY tn_id;

   l_complete_note VARCHAR2(32767);
BEGIN
   IF p_operation = 'INSERT'
      AND LENGTH(p_note) > 0
      AND p_et_id IS NOT NULL THEN

      evnt_api_pkg.etn(
         p_et_id      => p_et_id
      ,  p_created_by => USER
      ,  p_string     => p_note
      ,  p_format     => p_format);

   END IF;

   htp.p('<HTML>');
   htp.p('<TABLE  cellpadding=0 cellspacing=0 border=0 width="100%">');
   htp.p('<TR>');
   htp.p('<TD ALIGN="left" bgcolor='||d_PHCS||' height=15 colspan="2"><font color="#000000" size="2" face="Arial">&nbsp;('||p_et_id||') Trigger Notes:</font></TD>');
   htp.p('</TR>');
   htp.p('</TABLE>');

   FOR notes IN notes_cur LOOP
      l_complete_note := l_complete_note||notes.lines;
   END LOOP;

   htp.p(l_complete_note);

   -- build insert note form
   htp.p('<form method="POST" action="evnt_web_pkg.trg_notes">');
   htp.p('<textarea COLS=55 ROWS=10 name="p_note"></textarea>');
   htp.p('<br>');
   htp.p('<input type="SUBMIT" value="Add Note">');
   htp.p('<select name="p_format">');
   htp.p('<option value="TEXT" >FORMAT=Text</option>');
   htp.p('<option value="HTML" >FORMAT=Html</option>');
   htp.p('</select>');
   htp.p('<input type="hidden" name="p_et_id" value="'||p_et_id||'">');
   htp.p('<input type="hidden" name="p_operation" value="INSERT">');
   htp.p('</form>');

   htp.p('<form method="POST" action="evnt_web_pkg.trg_notes">');
   htp.p('<input type="hidden" name="p_operation" value="SELECT">');
   htp.p('<input type="hidden" name="p_et_id" value="'||p_et_id||'">');
   htp.p('<input type="SUBMIT" value="Refresh Notes">');

   htp.p('</HTML>');
END trg_notes;

PROCEDURE today(
   p_date IN VARCHAR2 DEFAULT TO_CHAR(SYSDATE,'RRRR-MON-DD'))
IS
   trunc_date DATE DEFAULT TRUNC(TO_DATE(p_date,'RRRR-MON-DD'));
BEGIN
   web_std_pkg.header('Event trends by target on '||p_date);

   htp.p('<table cellpadding="0" cellspacing="2" border="0">');
   htp.p('<tr>');

   -- day back
   htp.p('<td>');
   htp.p('<form method="POST" action="evnt_web_pkg.today">');
   htp.p('<input type="SUBMIT" value="'||TO_CHAR(TO_DATE(p_date,'RRRR-MON-DD')-1,'RRRR-MON-DD')||' <<<">');
   htp.p('<input type="hidden" name="p_date" value="'||TO_CHAR(TO_DATE(p_date,'RRRR-MON-DD')-1,'RRRR-MON-DD')||'">');
   htp.p('</form>');
   htp.p('</td>');

   -- refresh current day
   htp.p('<td>');
   htp.p('<form method="POST" action="evnt_web_pkg.today">');
   htp.p('<input type=text name=p_date size=11 maxlength=11 value="'||p_date||'">');
   htp.p('<input type="SUBMIT" value="Refresh">');
   htp.p('</form>');
   htp.p('</td>');

   -- day forward
   htp.p('<td>');
   htp.p('<form method="POST" action="evnt_web_pkg.today">');
   htp.p('<input type="SUBMIT" value=">>> '||TO_CHAR(TO_DATE(p_date,'RRRR-MON-DD')+1,'RRRR-MON-DD')||'">');
   htp.p('<input type="hidden" name="p_date" value="'||TO_CHAR(TO_DATE(p_date,'RRRR-MON-DD')+1,'RRRR-MON-DD')||'">');
   htp.p('</form>');
   htp.p('</td>');

   htp.p('</tr>');
   htp.p('</table>');


   htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Target</font></TH>');
   htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Events</font></TH>');

   FOR tgr IN (select target, h_id, s_id, count(*) cnt
               from event_triggers_all_v
               where trunc(et_trigger_time) = trunc_date
               group by target, h_id, s_id)
   LOOP
      htp.p('<TR>');
      htp.p('<TD nowrap><font class="TRT">'||tgr.target||'</font></TD>');
      htp.p('<TD nowrap><a href="evnt_web_pkg.disp_triggers?p_h_id='||tgr.h_id||'&p_s_id='||NVL(TO_CHAR(tgr.s_id),'x')||'&p_date='||p_date||'"><font class="TRL">'||tgr.cnt||'</font></a></TD>');
      htp.p('</TR>');
   END LOOP;

   htp.p('<TR>');
   htp.p('<TD colspan="2" nowrap><a href="evnt_web_pkg.disp_triggers?p_date='||p_date||'"><font class="TRL">Show All Events ['||p_date||']</font></a></TD>');
   htp.p('</TR>');

   htp.p('</TABLE>');

   web_std_pkg.footer;

   --disp_triggers(p_date=>TO_CHAR(SYSDATE,'RRRR-MON-DD'));
END today;

END evnt_web_pkg;
/

show errors
