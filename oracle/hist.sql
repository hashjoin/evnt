col E_ID format a10
col e_code format a30 trunc
set lines 200
set pages 1000

SELECT
          'p_e_id='||e_id e_id
      ,   NVL(e_name,e_code) e_code
      ,   MAX(DECODE(day,'PEND',cnt,NULL)) PEND
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
      ,  decode(et.trig_type,'ALL',TO_CHAR(et.et_trigger_time,'DY'),'PEND') day
      ,  COUNT(*) cnt
      FROM events e
      ,    (select 'ALL' trig_type, e.* from event_triggers e where TRUNC(e.et_trigger_time,'IW') = TRUNC(TRUNC(SYSDATE,'IW'),'IW')
            union all
            select 'PEND' trig_type, e.* from event_triggers e where decode(et_phase_status,'P','P',null) = 'P') et
      WHERE e.e_id = et.e_id
      and e.e_code != 'SQL_SCRIPT'
      and e.e_code != 'CHK_OS_LOG'
      GROUP BY
         e.e_id
      ,  e.e_code
      ,  e.e_name
      ,  decode(et.trig_type,'ALL',TO_CHAR(et.et_trigger_time,'DY'),'PEND'))
      GROUP BY
          e_id
      ,   NVL(e_name,e_code)
      union all
      SELECT
          'p_ep_id='||ep_id e_id
      ,   NVL(ep_desc,ep_code) e_code
      ,   MAX(DECODE(day,'PEND',cnt,NULL)) PEND
      ,   MAX(DECODE(day,'MON',cnt,NULL)) MON
      ,   MAX(DECODE(day,'TUE',cnt,NULL)) TUE
      ,   MAX(DECODE(day,'WED',cnt,NULL)) WED
      ,   MAX(DECODE(day,'THU',cnt,NULL)) THU
      ,   MAX(DECODE(day,'FRI',cnt,NULL)) FRI
      ,   MAX(DECODE(day,'SAT',cnt,NULL)) SAT
      ,   MAX(DECODE(day,'SUN',cnt,NULL)) SUN
      FROM (
      SELECT /*+ ORDERED */
         et.ep_id
      ,  et.ep_code
      ,  et.ep_desc
      ,  decode(et.trig_type,'ALL',TO_CHAR(et.et_trigger_time,'DY'),'PEND') day
      ,  COUNT(*) cnt
      FROM events e
      ,    (select 'ALL' trig_type, e.* from event_triggers_all_v e where TRUNC(e.et_trigger_time,'IW') = TRUNC(TRUNC(SYSDATE,'IW'),'IW')
            union all
            select 'PEND' trig_type, e.* from event_triggers_all_v e where et_pending = 'P') et
      WHERE e.e_id = et.e_id
      and e.e_code in ('SQL_SCRIPT', 'CHK_OS_LOG')
      GROUP BY
         et.ep_id
      ,  et.ep_code
      ,  et.ep_desc
      ,  decode(et.trig_type,'ALL',TO_CHAR(et.et_trigger_time,'DY'),'PEND'))
      GROUP BY
          ep_id
      ,   NVL(ep_desc,ep_code)
      ORDER BY 2
/
