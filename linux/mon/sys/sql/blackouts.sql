SELECT
   to_char(SYSDATE+:extra_hours/24,'RRRR-MM-DD HH24:MI') frame_time
,  eb_id
,  eb_code
,  eb_type_name
,  start_date||' '||start_time bstart_time
,  end_date||' '||end_time bend_time
,  day
,  eb_desc
/*,  DECODE(eb_type,
       'H', 'Host Level Blackout',
       'S', 'Sid Level Blackout',
       'E', 'Event Level Blackout',
       'X', 'Event Assigment Level Blackout',
       'P', 'Pager/Email Blackout',
       'A', 'Admin Level Blackout',
       'C', 'Collection Level Blackout',
            'Unknown Blackout')||' '||
    eb_code||' is active EB_ID='||TO_CHAR(eb_id) blackout_reason*/
FROM   event_blackouts_v
WHERE
/* this is the original where clause for the SYSDATE */
(
       (
        DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),
          '0001-01-01', TO_DATE(TO_CHAR(SYSDATE,'RRRR-MM-DD')||' '||TO_CHAR(eb_start_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
                                      eb_start_date) <= TRUNC(SYSDATE,'MI')
AND
        DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),
          '9000-01-01', TO_DATE(TO_CHAR(SYSDATE,'RRRR-MM-DD')||' '||TO_CHAR(eb_end_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
                                      eb_end_date) >= TRUNC(SYSDATE,'MI')
AND
        DECODE(eb_week_day,-1,TO_CHAR(SYSDATE,'D'),TO_CHAR(eb_week_day)) = TO_CHAR(SYSDATE,'D')
       )
/* and here's the "SYSDATE +" where clause that enables to scroll through the blackout periods */
OR
       (
        DECODE(TO_CHAR(eb_start_date,'RRRR-MM-DD'),
          '0001-01-01', TO_DATE(TO_CHAR(SYSDATE+:extra_hours/24,'RRRR-MM-DD')||' '||TO_CHAR(eb_start_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
                                      eb_start_date) <= TRUNC(SYSDATE+:extra_hours/24,'MI')
   AND
        DECODE(TO_CHAR(eb_end_date,'RRRR-MM-DD'),
          '9000-01-01', TO_DATE(TO_CHAR(SYSDATE+:extra_hours/24,'RRRR-MM-DD')||' '||TO_CHAR(eb_end_date,'HH24:MI'),'RRRR-MM-DD HH24:MI'),
                                      eb_end_date) >= TRUNC(SYSDATE+:extra_hours/24,'MI')
   AND
        DECODE(eb_week_day,-1,TO_CHAR(SYSDATE+:extra_hours/24,'D'),TO_CHAR(eb_week_day)) = TO_CHAR(SYSDATE+:extra_hours/24,'D')
        )
)
AND    eb_active_flag = 'Y'
-- and upper(eb_code) like '%NET_UPGRADE%'
/
