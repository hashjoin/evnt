-- make sure to grant the following to MON user:
--    grant select on WF_NOTIFICATIONS to mon;

set lines 132
set trims on

col subject format a35 trunc
col recipient_role format a15 trunc

select notification_id,
       message_type,
       message_name,
       recipient_role,
       subject
from applsys.WF_NOTIFICATIONS
where mail_status = 'MAIL'
  and begin_date >= trunc(sysdate-1) /* check only a day old records */
  and begin_date <= sysdate-(30/24/60) /* wait 30 minutes before raising an alert */
order by notification_id desc;

