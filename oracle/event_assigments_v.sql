CREATE OR REPLACE VIEW event_assigments_v AS
SELECT /*+ ORDERED */ 
       eas.ea_id 
,      eas.date_modified
,      eas.modified_by
,      eas.date_created
,      eas.created_by
,      eas.e_id 
,      eas.ep_id 
,      eas.h_id 
,      eas.s_id 
,      eas.sc_id 
,      eas.pl_id 
,      SUBSTR(evnt.e_code_base,INSTR(evnt.e_code_base,'*')+1) e_code_base
,      DECODE(INSTR(evnt.e_code_base,'*'),0,'NO','YES') remote
,      evnt.e_file_name 
,      hst.h_name            
,      scred.sc_username
,      scred.sc_password 
,      scred.sc_tns_alias
,      scred.sc_username||'/'||scred.sc_password||'@'||scred.sc_tns_alias connect_string
,      scred.sc_db_link_name 
,      sid.s_name 
,      eas.ea_min_interval
,      eas.ea_status
,      eas.ea_start_time
,      eas.ea_started_time
,      eas.ea_finished_time
,      eas.ea_last_runtime_sec
,      eas.ea_purge_freq
FROM event_assigments eas 
,    hosts hst 
,    sids sid 
,    sid_credentials scred 
,    events evnt 
WHERE eas.h_id = hst.h_id 
AND   eas.s_id = sid.s_id(+) 
AND   eas.sc_id = scred.sc_id(+) 
AND   eas.e_id = evnt.e_id
/


CREATE OR REPLACE VIEW event_triggers_all_v AS
SELECT
--SELECT /*+ RULE */
   et.ea_id
,  et.pl_id
,  et.e_id
,  ep.ep_id
,  et.h_id
,  et.s_id
,  et.sc_id
,  et_attribute1||DECODE(et_attribute2,null,null,':'||et_attribute2) target
,  et_trigger_time
,  et_status
,  ep_code
,  ep_desc
,  NVL(et.modified_by,et.created_by) last_update_by
,  et.date_modified
,  et_id
,  et_orig_et_id
,  et_clr_et_id
,  et_prev_et_id
,  et_prev_status
,  et_phase_status phase
,  decode(et_phase_status,'P','P',null) et_pending
,  et_mail_status  mail
,  et_ack_flag
,  et_ack_date
,  et_ack_by_a_id
FROM event_parameters ep
,    event_assigments ea
,    event_triggers et
WHERE et.ea_id = ea.ea_id
AND   ea.ep_id = ep.ep_id
AND   ea.e_id = ep.e_id;


CREATE OR REPLACE VIEW event_trig_outdet_all_v AS          
SELECT
1 s_order, et_id trig_id, etd_id line_id,
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
  etd_attribute20   output_line
FROM event_trigger_details
UNION ALL
SELECT 
MAX(2) s_order, et_id trig_id, MAX(etd_id) line_id, ' ' output FROM event_trigger_details
GROUP BY et_id
UNION ALL
SELECT
3 s_order,  et_id trig_id, eto_id line_id,
   eto_output_line
FROM event_trigger_output
ORDER BY s_order, trig_id, line_id
/



CREATE OR REPLACE VIEW event_blackouts_v AS
SELECT eb_id
,      eb.date_created 
,      eb.date_modified
,      eb.modified_by  
,      eb.created_by  
,      DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),'0001-01-01','NOBOUND',TO_CHAR(eb_start_date,'RRRR-MM-DD')) start_date
,      DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),'9000-01-01','NOBOUND',TO_CHAR(eb_end_date,'RRRR-MM-DD')) end_date
,      TO_CHAR(eb_start_date,'HH24:MI') start_time
,      TO_CHAR(eb_end_date,'HH24:MI') end_time
,      DECODE(eb_week_day,
          -1,'Every Day',
           1,'Sunday',
           2,'Monday',
           3,'Tuesday',
           4,'Wednesday',
           5,'Thursday',
           6,'Friday',
           7,'Saturday') day
,      eb_code
,      DECODE(eb_type,
          'H', 'Host Level Blackout',
          'S', 'Sid Level Blackout',
          'E', 'Event Level Blackout',
          'X', 'Event Assigment Level Blackout',
          'P', 'Pager/Email Blackout',
          'A', 'Admin Level Blackout',
          'C', 'Collection Level Blackout',
               'Unknown Blackout') eb_type_long
,      eb_type
,      eb_type_id
,      NVL(h.h_name,'MISSING_ID: '||TO_CHAR(eb_type_id))  eb_type_name
,      eb_start_date
,      eb_end_date
,      eb_week_day
,      eb_active_flag
,      eb_desc
FROM   event_blackouts eb
    ,      hosts h
WHERE  eb_type = 'H'
AND    eb_type_id = h.h_id(+)
UNION ALL
SELECT eb_id
,      eb.date_created 
,      eb.date_modified
,      eb.modified_by  
,      eb.created_by  
,      DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),'0001-01-01','NOBOUND',TO_CHAR(eb_start_date,'RRRR-MM-DD')) start_date
,      DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),'9000-01-01','NOBOUND',TO_CHAR(eb_end_date,'RRRR-MM-DD')) end_date
,      TO_CHAR(eb_start_date,'HH24:MI') start_time
,      TO_CHAR(eb_end_date,'HH24:MI') end_time
,      DECODE(eb_week_day,
          -1,'Every Day',
           1,'Sunday',
           2,'Monday',
           3,'Tuesday',
           4,'Wednesday',
           5,'Thursday',
           6,'Friday',
           7,'Saturday') day
,      eb_code
,      DECODE(eb_type,
          'H', 'Host Level Blackout',
          'S', 'Sid Level Blackout',
          'E', 'Event Level Blackout',
          'X', 'Event Assigment Level Blackout',
          'P', 'Pager/Email Blackout',
          'A', 'Admin Level Blackout',
          'C', 'Collection Level Blackout',
               'Unknown Blackout') eb_type_long
,      eb_type
,      eb_type_id
,      NVL(s.s_name,'MISSING_ID: '||TO_CHAR(eb_type_id))  eb_type_name
,      eb_start_date
,      eb_end_date
,      eb_week_day
,      eb_active_flag
,      eb_desc
FROM   event_blackouts eb
    ,      sids s
WHERE  eb_type = 'S'
AND    eb_type_id = s.s_id(+)
UNION ALL
SELECT eb_id
,      eb.date_created 
,      eb.date_modified
,      eb.modified_by  
,      eb.created_by  
,      DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),'0001-01-01','NOBOUND',TO_CHAR(eb_start_date,'RRRR-MM-DD')) start_date
,      DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),'9000-01-01','NOBOUND',TO_CHAR(eb_end_date,'RRRR-MM-DD')) end_date
,      TO_CHAR(eb_start_date,'HH24:MI') start_time
,      TO_CHAR(eb_end_date,'HH24:MI') end_time
,      DECODE(eb_week_day,
          -1,'Every Day',
           1,'Sunday',
           2,'Monday',
           3,'Tuesday',
           4,'Wednesday',
           5,'Thursday',
           6,'Friday',
           7,'Saturday') day
,      eb_code
,      DECODE(eb_type,
          'H', 'Host Level Blackout',
          'S', 'Sid Level Blackout',
          'E', 'Event Level Blackout',
          'X', 'Event Assigment Level Blackout',
          'P', 'Pager/Email Blackout',
          'A', 'Admin Level Blackout',
          'C', 'Collection Level Blackout',
               'Unknown Blackout') eb_type_long
,      eb_type
,      eb_type_id
,      NVL(e.e_code,'MISSING_ID: '||TO_CHAR(eb_type_id))  eb_type_name
,      eb_start_date
,      eb_end_date
,      eb_week_day
,      eb_active_flag
,      eb_desc
FROM   event_blackouts eb
,      events e
WHERE  eb_type = 'E'
AND    eb_type_id = e.e_id(+)
UNION ALL
SELECT eb_id
,      eb.date_created 
,      eb.date_modified
,      eb.modified_by  
,      eb.created_by  
,      DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),'0001-01-01','NOBOUND',TO_CHAR(eb_start_date,'RRRR-MM-DD')) start_date
,      DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),'9000-01-01','NOBOUND',TO_CHAR(eb_end_date,'RRRR-MM-DD')) end_date
,      TO_CHAR(eb_start_date,'HH24:MI') start_time
,      TO_CHAR(eb_end_date,'HH24:MI') end_time
,      DECODE(eb_week_day,
          -1,'Every Day',
           1,'Sunday',
           2,'Monday',
           3,'Tuesday',
           4,'Wednesday',
           5,'Thursday',
           6,'Friday',
           7,'Saturday') day
,      eb_code
,      DECODE(eb_type,
          'H', 'Host Level Blackout',
          'S', 'Sid Level Blackout',
          'E', 'Event Level Blackout',
          'X', 'Event Assigment Level Blackout',
          'P', 'Pager/Email Blackout',
          'A', 'Admin Level Blackout',
          'C', 'Collection Level Blackout',
               'Unknown Blackout') eb_type_long
,      eb_type
,      eb_type_id
,      DECODE(ea.h_name,NULL,'MISSING_ID: '||TO_CHAR(eb_type_id),ea.h_name||':'||ea.s_name||'('||e_file_name||')')  eb_type_name
,      eb_start_date
,      eb_end_date
,      eb_week_day
,      eb_active_flag
,      eb_desc
FROM   event_blackouts eb
,      event_assigments_v ea
WHERE  eb_type = 'X'
AND    eb_type_id = ea.ea_id(+)
UNION ALL
SELECT eb_id
,      eb.date_created 
,      eb.date_modified
,      eb.modified_by  
,      eb.created_by  
,      DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),'0001-01-01','NOBOUND',TO_CHAR(eb_start_date,'RRRR-MM-DD')) start_date
,      DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),'9000-01-01','NOBOUND',TO_CHAR(eb_end_date,'RRRR-MM-DD')) end_date
,      TO_CHAR(eb_start_date,'HH24:MI') start_time
,      TO_CHAR(eb_end_date,'HH24:MI') end_time
,      DECODE(eb_week_day,
          -1,'Every Day',
           1,'Sunday',
           2,'Monday',
           3,'Tuesday',
           4,'Wednesday',
           5,'Thursday',
           6,'Friday',
           7,'Saturday') day
,      eb_code
,      DECODE(eb_type,
          'H', 'Host Level Blackout',
          'S', 'Sid Level Blackout',
          'E', 'Event Level Blackout',
          'X', 'Event Assigment Level Blackout',
          'P', 'Pager/Email Blackout',
          'A', 'Admin Level Blackout',
          'C', 'Collection Level Blackout',
               'Unknown Blackout') eb_type_long
,      eb_type
,      eb_type_id
,      NVL(ae.ae_email,'MISSING_ID: '||TO_CHAR(eb_type_id))  eb_type_name
,      eb_start_date
,      eb_end_date
,      eb_week_day
,      eb_active_flag
,      eb_desc
FROM   event_blackouts eb
,      admin_emails ae
WHERE  eb_type = 'P'
AND    eb_type_id = ae.ae_id(+)
UNION ALL
SELECT eb_id
,      eb.date_created 
,      eb.date_modified
,      eb.modified_by  
,      eb.created_by  
,      DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),'0001-01-01','NOBOUND',TO_CHAR(eb_start_date,'RRRR-MM-DD')) start_date
,      DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),'9000-01-01','NOBOUND',TO_CHAR(eb_end_date,'RRRR-MM-DD')) end_date
,      TO_CHAR(eb_start_date,'HH24:MI') start_time
,      TO_CHAR(eb_end_date,'HH24:MI') end_time
,      DECODE(eb_week_day,
          -1,'Every Day',
           1,'Sunday',
           2,'Monday',
           3,'Tuesday',
           4,'Wednesday',
           5,'Thursday',
           6,'Friday',
           7,'Saturday') day
,      eb_code
,      DECODE(eb_type,
          'H', 'Host Level Blackout',
          'S', 'Sid Level Blackout',
          'E', 'Event Level Blackout',
          'X', 'Event Assigment Level Blackout',
          'P', 'Pager/Email Blackout',
          'A', 'Admin Level Blackout',
          'C', 'Collection Level Blackout',
               'Unknown Blackout') eb_type_long
,      eb_type
,      eb_type_id
,      NVL(a.a_name,'MISSING_ID: '||TO_CHAR(eb_type_id))  eb_type_name
,      eb_start_date
,      eb_end_date
,      eb_week_day
,      eb_active_flag
,      eb_desc
FROM   event_blackouts eb
,      admins a
WHERE  eb_type = 'A'
AND    eb_type_id = a.a_id(+)
UNION ALL
SELECT eb_id
,      eb.date_created 
,      eb.date_modified
,      eb.modified_by  
,      eb.created_by  
,      DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),'0001-01-01','NOBOUND',TO_CHAR(eb_start_date,'RRRR-MM-DD')) start_date
,      DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),'9000-01-01','NOBOUND',TO_CHAR(eb_end_date,'RRRR-MM-DD')) end_date
,      TO_CHAR(eb_start_date,'HH24:MI') start_time
,      TO_CHAR(eb_end_date,'HH24:MI') end_time
,      DECODE(eb_week_day,
          -1,'Every Day',
           1,'Sunday',
           2,'Monday',
           3,'Tuesday',
           4,'Wednesday',
           5,'Thursday',
           6,'Friday',
           7,'Saturday') day
,      eb_code
,      DECODE(eb_type,
          'H', 'Host Level Blackout',
          'S', 'Sid Level Blackout',
          'E', 'Event Level Blackout',
          'X', 'Event Assigment Level Blackout',
          'P', 'Pager/Email Blackout',
          'A', 'Admin Level Blackout',
          'C', 'Collection Level Blackout',
               'Unknown Blackout') eb_type_long
,      eb_type
,      eb_type_id
,      NVL(TO_CHAR(ca.ca_id),'MISSING_ID: '||TO_CHAR(eb_type_id))  eb_type_name
,      eb_start_date
,      eb_end_date
,      eb_week_day
,      eb_active_flag
,      eb_desc
FROM   event_blackouts eb
,      coll_assigments ca
WHERE  eb_type = 'C'
AND    eb_type_id = ca.ca_id(+)
UNION ALL
SELECT eb_id
,      eb.date_created 
,      eb.date_modified
,      eb.modified_by  
,      eb.created_by  
,      DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),'0001-01-01','NOBOUND',TO_CHAR(eb_start_date,'RRRR-MM-DD')) start_date
,      DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),'9000-01-01','NOBOUND',TO_CHAR(eb_end_date,'RRRR-MM-DD')) end_date
,      TO_CHAR(eb_start_date,'HH24:MI') start_time
,      TO_CHAR(eb_end_date,'HH24:MI') end_time
,      DECODE(eb_week_day,
          -1,'Every Day',
           1,'Sunday',
           2,'Monday',
           3,'Tuesday',
           4,'Wednesday',
           5,'Thursday',
           6,'Friday',
           7,'Saturday') day
,      eb_code
,      DECODE(eb_type,
          'H', 'Host Level Blackout',
          'S', 'Sid Level Blackout',
          'E', 'Event Level Blackout',
          'X', 'Event Assigment Level Blackout',
          'P', 'Pager/Email Blackout',
          'A', 'Admin Level Blackout',
          'C', 'Collection Level Blackout',
               'Unknown Blackout') eb_type_long
,      eb_type
,      eb_type_id
,      'UKNOWN'  eb_type_name
,      eb_start_date
,      eb_end_date
,      eb_week_day
,      eb_active_flag
,      eb_desc
FROM   event_blackouts eb
WHERE  eb_type NOT IN ('C','H','S','E','X','P','A','C')
/


CREATE OR REPLACE VIEW page_list_definitions_v AS
SELECT pld_id
,      pld.date_created
,      pld.date_modified
,      pld.modified_by
,      pld.created_by
,      pld.pl_id
,      pld.a_id
,      pld.ae_id
,      pl_code
,      a_name
,      ae_email
,      ae_append_logfile
,      ae_desc
,      pld_status
FROM page_list_definitions pld
,    page_lists pl
,    admins a
,    admin_emails ae
WHERE pld.a_id = a.a_id
AND   pld.ae_id = ae.ae_id
AND   pld.a_id = ae.a_id
AND   pld.pl_id = pl.pl_id	  
/
