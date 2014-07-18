-- see http://ora.hashjoin.com/tp/2995.aleppe_periodic_alert_scheduler_-_program_was_terminated_by_signal_11_.html
--

set lines 132
set trims on

select a.application_id, a.alert_id, a.alert_name, a.next_scheduled_check, a.check_time  
from apps.alr_periodic_alerts_view a,
(   select count(*) total_runs, to_char(r.request_date,'YYYY/MM/DD') req_day, 
           r.description, to_number(r.argument1) argument1, to_number(r.argument2) argument2
    from apps.fnd_concurrent_programs p
    ,    apps.fnd_concurrent_requests r
    where r.concurrent_program_id = p.concurrent_program_id
    and   r.program_application_id = p.application_id
    and   p.concurrent_program_name = 'ALECDC'
    group by to_char(r.request_date,'YYYY/MM/DD'), r.description, r.argument1, r.argument2) r
where a.type = 'A'
and a.next_scheduled_check <> 'O' /* on demand */
and a.application_id = r.argument1(+)
and a.alert_id = r.argument2(+)
and a.next_scheduled_check = 'T' /* Today; it does change to T when it's time -- trust me :) */
and r.total_runs is null
order by a.application_id, a.alert_id;

