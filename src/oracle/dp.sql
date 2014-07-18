create or replace procedure dp(tid in number)
as
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
      WHERE et_id = tid
      AND   et.et_ack_by_a_id = a.a_id(+);
   trig_det trig_det_cur%ROWTYPE;

begin
    OPEN trig_det_cur;
    FETCH trig_det_cur INTO trig_det;
    IF trig_det_cur%NOTFOUND THEN
     null;
    END IF;
    CLOSE trig_det_cur;

    -- TRIGGER DETAILS TABLE
    htp.p('<TABLE  border="0" cellspacing=0 cellpadding=2>');

    htp.p('<TR>');
    htp.p('<TH ALIGN="Left""><font class="THT">Target</font></TH>');
    htp.p('<TD nowrap><font class="TRT">'||trig_det.target||'</font></TD>');
    htp.p('</TR>');

    htp.p('<TR>');
    htp.p('<TH ALIGN="Left""><font class="THT">Trigger Time</font></TH>');
    htp.p('<TD nowrap><font class="TRT">'||trig_det.trigger_time||'</font></TD>');
    htp.p('</TR>');

    htp.p('<TR>');
    htp.p('<TH ALIGN="Left""><font class="THT">Status</font></TH>');
    htp.p('<TD nowrap><font class="TRL">'||trig_det.et_status||'</font></TD>');
    htp.p('</TR>');

    htp.p('<TR>');
    htp.p('<TH ALIGN="Left""><font class="THT">Description</font></TH>');
    htp.p('<TD nowrap><font class="TRT">'||trig_det.ep_desc||'</font></TD>');
    htp.p('</TR>');

    htp.p('<TR>');
    htp.p('<TH ALIGN="Left""><font class="THT">Acknowledgement</font></TH>');
    htp.p('<TD nowrap><font class="TRT">'||trig_det.decoded_ack||'</font></TD>');
    htp.p('</TR>');

    htp.p('</TABLE>');

   evnt_web_pkg.get_trig_output(p_trig_id=>tid);
end;
/

show errors
