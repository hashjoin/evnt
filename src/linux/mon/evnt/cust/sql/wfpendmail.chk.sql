-- make sure to grant the following to MON user:
--    grant select on WF_NOTIFICATIONS to mon;
--
-- 02-AUG-2007	VMOGILEV	Put NVL on context


select notification_id
||','||message_type
||','||message_name
||','||recipient_role
||','||mail_status
||','||to_char(begin_date,'YYYY-MON-DD HH24:MI:SS')
||','||nvl(context,'NULL')
||','||to_user
||','||subject
from applsys.WF_NOTIFICATIONS
where mail_status = 'MAIL'
  and begin_date >= trunc(sysdate-1) /* check only a day old records */
  and begin_date <= sysdate-(30/24/60) /* wait 30 minutes before raising an alert */
order by notification_id desc;

