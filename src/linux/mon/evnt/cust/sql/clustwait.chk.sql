select distinct event from (
select event, count(*), SUM(wait_time + time_waited)/1000000 secs_waited,
       SUM(wait_time + time_waited)/count(*) avg_wait_microsecond
  from v$active_session_history
 where sample_time >= sysdate-nvl(&&1,5)/24/60
   --and wait_Class = 'Cluster'
 having SUM(wait_time + time_waited)/count(*) >= nvl(&&2,500000)
 group by event order by SUM(wait_time + time_waited)/count(*) desc);
