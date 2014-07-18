insert into event_blackouts values
(
   event_blackouts_S.nextval,
   sysdate,
   null,
   null,
   'VMOGILEV',
   'VMOGILEV-VAC01-2006',
   'A', -- admin
   4, -- VMOGILEV
   to_date('15-JUN-2006 00:00','DD-MON-YYYY HH24:MI'), -- start date
   to_date('25-JUN-2006 23:59','DD-MON-YYYY HH24:MI'), -- end date
   -1, -- week day
   'A', -- active
   'VMOGILEV Vacation July 2006'
)
/
