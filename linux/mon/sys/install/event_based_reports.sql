set scan off

-- COLL_SNAP
-- X
-- Collection data by snapshoot
-- Displays all data from a single collection snapshoot
--
SELECT * FROM COLL_PULL__&SNAPSHOOT_TABLE


-- TBSP_GROWTH
-- E
-- Tablespace growth rate
-- Reports tablespace growth rate over a time period
--
SELECT /*+ ORDERED */
   et_attribute1||DECODE(et_attribute2,NULL,NULL,':'||et_attribute2) "Target"
,  '<a href="evnt_web_pkg.get_trigger?p_et_id='||et.et_id||'"><font class="TRL">'||et.et_id||'</font></a>' "Trigger"
,  et_trigger_time "Time"
,  etd_attribute1 "Tablespace"
,  TO_NUMBER(etd_attribute3) "Total KB"
,  TO_NUMBER(etd_attribute4) "Free KB"
,  TO_NUMBER(etd_attribute2) "PCT"
FROM event_triggers et
,    event_trigger_details etd
WHERE et.e_id = (SELECT e_id FROM events WHERE e_code = 'TABSP_USAGE')
AND   et.s_id = :p_s_id
AND   etd_attribute1 LIKE(:p_tabsp_name)
AND   et.et_id = etd.et_id
ORDER BY et_trigger_time



-- RUNAWAY_PROCS
-- E
-- Runaway processes report
-- Reports historical runaway processes
--
SELECT /*+ ORDERED */
   et_attribute1||DECODE(et_attribute2,NULL,NULL,':'||et_attribute2) "Target"
,  '<a href="evnt_web_pkg.get_trigger?p_et_id='||et.et_id||'"><font class="TRL">'||et.et_id||'</font></a>' "Trigger"
,  et_trigger_time "Time"
,  etd_status "Threshold"
,  etd_attribute3 "User"
,  htf.escape_sc(etd_attribute4) "Module/Action"
FROM event_triggers et
,    event_trigger_details etd
WHERE et.e_id IN (SELECT e_id FROM events 
                  WHERE e_code LIKE 'RUNAWAY_PROC%')
AND   et.s_id = :p_s_id
AND   LTRIM(etd_attribute4) LIKE(:p_module_name)
AND   et.et_id = etd.et_id
ORDER BY et_trigger_time


-- LGRSEG_GROWTH
-- E
-- Large segment growth
-- Reports growth history of segments with high number of extents
--
SELECT /*+ ORDERED */
   et_attribute1||DECODE(et_attribute2,NULL,NULL,':'||et_attribute2) "Target"
,  '<a href="evnt_web_pkg.get_trigger?p_et_id='||et.et_id||'"><font class="TRL">'||et.et_id||'</font></a>' "Trigger"
,  et_trigger_time "Time"
,  etd_status "Threshold"
,  etd_attribute1 "Owner"
,  etd_attribute2 "Segment Name"
,  etd_attribute3 "Segment Type"
,  etd_attribute4 "Tablespace"
,  TO_NUMBER(etd_attribute5)/1024 "KBytes"
,  TO_NUMBER(etd_attribute6) "Extents"
,  TO_NUMBER(etd_attribute7) "Max Extents"
,  TO_NUMBER(etd_attribute8)/1024 "Initial KB"
,  TO_NUMBER(etd_attribute9)/1024 "Next KB"
,  TO_NUMBER(etd_attribute10) "PCT"
FROM event_triggers et
,    event_trigger_details etd
WHERE et.e_id = (SELECT e_id FROM events 
                 WHERE e_code = 'HIGH_EXTENTS')
AND   et.s_id = :p_s_id
AND   et.et_id = etd.et_id
AND   etd_attribute2 LIKE (:p_segment_name)
ORDER BY et_trigger_time


-- FASTEXT_SEGS
-- E
-- Fast extending segments
-- Reports segment extent history
--
SELECT /*+ ORDERED */
   et_attribute1||DECODE(et_attribute2,NULL,NULL,':'||et_attribute2) "Target"
,  '<a href="evnt_web_pkg.get_trigger?p_et_id='||et.et_id||'"><font class="TRL">'||et.et_id||'</font></a>' "Trigger"
,  et_trigger_time "Time"
,  etd_status "Threshold"
,  etd_attribute1 "Owner"
,  etd_attribute2 "Segment Type"
,  etd_attribute3 "Segment Name"
,  etd_attribute4 "Tablespace"
,  TO_NUMBER(etd_attribute5) "Start KB"
,  TO_NUMBER(etd_attribute6) "End KB"
,  TO_NUMBER(etd_attribute6) -
   TO_NUMBER(etd_attribute5) "Diff KB"
,  TO_NUMBER(etd_attribute7) "Start Ext"
,  TO_NUMBER(etd_attribute8) "End Ext"
,  TO_NUMBER(etd_attribute8) -
   TO_NUMBER(etd_attribute7) "Diff Ext"
,  TO_NUMBER(etd_attribute9)/1024 "Next KB"
,  TO_NUMBER(etd_attribute10) "PCT"
FROM event_triggers et
,    event_trigger_details etd
WHERE et.e_id = (SELECT e_id FROM events 
                 WHERE e_code = 'DB_SEGEX')
AND   et.s_id = :p_s_id
AND   et.et_id = etd.et_id
AND   etd_attribute3 LIKE (:p_segment_name)
ORDER BY et_trigger_time


-- HIGH_SORTS
-- E
-- High sort usage
-- Reports history of sessions with high sort usage
--
SELECT /*+ ORDERED */
   et_attribute1||DECODE(et_attribute2,NULL,NULL,':'||et_attribute2) "Target"
,  '<a href="evnt_web_pkg.get_trigger?p_et_id='||et.et_id||'"><font class="TRL">'||et.et_id||'</font></a>' "Trigger"
,  et_trigger_time "Time"
,  etd_status "Threshold"
,  etd_attribute3 "User"
,  etd_attribute4 "Logon Time"
,  etd_attribute5 "Machine"
,  htf.escape_sc(etd_attribute6) "Prog/Mod/Action"
,  etd_attribute7 "Status"
,  etd_attribute8 "Tabsp"
,  etd_attribute10 "Extents"
,  etd_attribute11 "Sort KB"
FROM event_triggers et
,    event_trigger_details etd
WHERE et.e_id IN (SELECT e_id FROM events 
                  WHERE e_code LIKE 'SORT_SIZE')
AND   et.s_id = :p_s_id
AND   LTRIM(etd_attribute6) LIKE(:p_module_name)
AND   et.et_id = etd.et_id
ORDER BY et_trigger_time


-- APPS11I_SES
-- R
-- APPS (11i) - Active forms sessions
-- Application 11i forms connections with APPS level username
--
select
       chr(39)||s.sid||','||s.serial#||chr(39)         "Sid,Serial"
,          to_char(s.logon_time,'DDth HH24:MI:SS')     "LogOn Time"
,          floor(last_call_et/3600)||':'||
              floor(mod(last_call_et,3600)/60)||':'||
              mod(mod(last_call_et,3600),60)           "Idle"
,          s.username                                  "O-User"
,          s.osuser                                    "OS-User"
,          s.status                                    "Status"
,          DECODE(lockwait,'','','Y')                  "Lockwait"
,          u.user_name                                 "APPS-User"
,          s.module||' '||s.action                     "Form Responsibility"
from      v$session@&DB_LINK_NAME  s
,         v$process@&DB_LINK_NAME  p
,         fnd_logins@&DB_LINK_NAME n
,         fnd_user@&DB_LINK_NAME   u
where  s.paddr      = p.addr
and    n.pid        IS NOT NULL
and    n.serial#    IS NOT NULL
and    n.login_name IS NOT NULL
and    n.end_time   IS NULL
and    n.serial#    = p.serial#
and    n.pid        = p.pid
and    n.process_spid = p.spid
and    n.spid         = s.process
and    n.user_id    = u.user_id
and    trunc(s.logon_time) = trunc(n.start_time)
order by  u.user_name
,         s.logon_time


-- TABSP_USAGE
-- R
-- Tablespace Usage
-- Reports current tablespace usage
--
select  
   '<a href="glob_web_pkg.exec_sql'
      ||'?p_report=DFILE_USAGE'
      ||'&p_pag=YES'
      ||'&p_rep_what='||web_std_pkg.encode_ustr(UPPER('&db_link_name'))
      ||'&p_rep_with='||web_std_pkg.encode_ustr('&DB_LINK_NAME')
      ||'&p_bind_names=:p_tabsp_name'
      ||'&p_bind_values='||b.tablespace_name
      ||'&p_heading='||web_std_pkg.encode_ustr('Data File Usage (&DB_LINK_NAME)')
      ||'"><font class="TRL">'||b.tablespace_name||'</font></a>' "TS Name"
,  kbytes_alloc                                            "Total KB"
,  kbytes_alloc-nvl(kbytes_free,0)                         "Used KB"
,  nvl(kbytes_free,0)                                      "Free KB"
,  ROUND(((kbytes_alloc-nvl(kbytes_free,0))/kbytes_alloc)*100,2)    "PCT Used"
,  nvl(largest,0)                                          "Largest KB"
from    (select sum(bytes)/1024                 Kbytes_free
        ,               max(bytes)/1024         largest
        ,               tablespace_name
        from            dba_free_space@&DB_LINK_NAME
        group by        tablespace_name)                        a
,       (select         sum(bytes)/1024         Kbytes_alloc
        ,               tablespace_name
        from            dba_data_files@&DB_LINK_NAME
        group by        tablespace_name)                        b
where   a.tablespace_name (+) = b.tablespace_name
order by 5 desc,1



-- DFILE_USAGE
-- R
-- Data File Usage
-- Reports current datafile usage
--
select /*+ ORDERED */
       df.tablespace_name "TS Name"
,      df.file_name       "File Name"
,      df.bytes/1024                    "Total KB"
,      (df.bytes-nvl(fr.bytes,0))/1024  "Used KB"
,      nvl(fr.bytes/1024,0)      "Free Kb"
,      ROUND(((df.bytes-nvl(fr.bytes,0))/df.bytes)*100,2) "PCT Used"
from   (select sum(bytes) bytes
        ,      file_id
        from   dba_free_space@&DB_LINK_NAME
        group by file_id)     fr
,       dba_data_files@&DB_LINK_NAME        df
where df.file_id = fr.file_id(+)
and   df.tablespace_name like (:p_tabsp_name)
order by 1, df.file_id



/* shared parameters */


-- P_MODULE_NAME
-- Module Name
-- C
-- NULL

-- P_TABSP_NAME
-- Tablespace Name
-- C
-- NULL

--
-- P_SEGMENT_NAME
-- Segment Name
-- C
-- NULL

-- P_E_ID
-- Event Name
-- L
SELECT
   e_id
,  e_code
,  NULL
FROM events
ORDER BY e_code

--
-- P_S_ID
-- Sid Name
-- L

SELECT
   s_id
,  s_name
,  NULL
FROM sids
ORDER BY s_name

