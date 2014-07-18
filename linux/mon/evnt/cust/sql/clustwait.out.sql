--    2013-Nov-05	vclustwait	VMOGILEVSKIY	

set lines 80

col avg_wait_microsecond	format 9999999999
col event			format a32
col wait_Class			format a15 trunc

ttit "Breakdown of Cluster Waits in the last &&1 minutes"
select event, count(*), SUM(wait_time + time_waited)/1000000 secs_waited,
       SUM(wait_time + time_waited)/count(*) avg_wait_microsecond
  from v$active_session_history
 where sample_time >= sysdate-&&1/24/60
 --  and wait_Class = 'Cluster'
 having SUM(wait_time + time_waited) > 0
 group by event order by SUM(wait_time + time_waited)/count(*) desc;

prompt acceptible response times are 500 ms or 500000 microseconds
col gc_type	format a11

set lines 159

ttit "SQL IDs with AVG Cluster Waits times > 500 ms in the last &&1 minutes"
select x.*, decode(x.event,
                'gc current block 2-way',       'Block',
                'gc current block 3-way',       'Block',
                'gc cr block 2-way',            'Block',
                'gc cr block 3-way',            'Block',
                'gc current grant 2-way',       'Message',
                'gc cr grant 2-way',            'Message',
                'gc current block busy',        'Contention',
                'gc cr block busy',             'Contention',
                'gc current buffer busy',       'Contention',
                'gc current block congested',   'Load',
                'gc cr block congested',        'Load',
                'Other') gc_type
from (
SELECT count(*) cnt
,      SUM(wait_time + time_waited) total_waits
,      SUM(wait_time + time_waited)/count(*) avg_wait_microsecond
,      h.sql_id
,      h.sql_plan_hash_value
,      h.sql_child_number
,      h.event
,      h.wait_Class
FROM v$active_session_history h
WHERE sample_time >= sysdate-&&1/24/60
--  and wait_Class = 'Cluster'
GROUP BY h.sql_id, h.sql_plan_hash_value, h.sql_child_number, h.event, h.wait_Class
having SUM(wait_time + time_waited)/count(*) >= nvl(&2,500000)
ORDER BY count(*) desc, SUM(wait_time + time_waited)/count(*) DESC) x;

set lines 130

ttit "Top Ten SQL IDs with Cluster Waits in the last &&1 minutes"
select x.*, decode(x.event,
		'gc current block 2-way',	'Block',
		'gc current block 3-way',	'Block',
		'gc cr block 2-way',		'Block',
		'gc cr block 3-way',		'Block',
		'gc current grant 2-way',	'Message',
		'gc cr grant 2-way',		'Message',
		'gc current block busy',	'Contention',
		'gc cr block busy',		'Contention',
		'gc current buffer busy',	'Contention',
		'gc current block congested',	'Load',
		'gc cr block congested',	'Load',
		'Other') gc_type
from (
SELECT count(*) cnt
,      h.sql_id
,      h.sql_plan_hash_value
,      h.sql_child_number
,      h.event
,      h.wait_Class
FROM v$active_session_history h
WHERE sample_time >= sysdate-&&1/24/60
--  and wait_Class = 'Cluster'
GROUP BY h.sql_id, h.sql_plan_hash_value, h.sql_child_number, h.event, h.wait_Class
ORDER BY count(*) DESC) x
where rownum < 11;

set lines 187
set pages 100
ttit "Breakdown of aggregated Connections"
col machine format a45
col service_name format a30

select count(*)
,      translate(machine,1234567890,'XXXXXXXXXX') machine
,       SERVICE_NAME
,       username
,       module
from v$session group by translate(machine,1234567890,'XXXXXXXXXX'), SERVICE_NAME, username, module
order by 2;


