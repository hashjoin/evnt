ttit "Top 9 wait events over the past &&1 minutes"
set pages 100
set lines 98

col Wait_Time_sec       format 9999999999

select * from (
SELECT
h.event "Wait Event",
SUM(h.wait_time + h.time_waited)/1000000 Wait_Time_sec,
count(*) sess_cnt
FROM
v$active_session_history h,
v$event_name e
WHERE
h.sample_time < (select max(sample_time) from v$active_session_history)
and h.sample_time > (select max(sample_time)-decode(&&1,0,1,&&1)/24/60 from v$active_session_history)
AND h.event_id = e.event_id
AND e.wait_class <> 'Idle'
GROUP BY h.event
ORDER BY 2 DESC)
where rownum <9
/

