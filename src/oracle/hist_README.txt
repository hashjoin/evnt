14:13:25 EVNT@EVNT=> @hist
14:13:27 EVNT@EVNT=> col E_ID format a10
14:13:27 EVNT@EVNT=> col e_code format a30 trunc
14:13:27 EVNT@EVNT=> set lines 200
14:13:27 EVNT@EVNT=> set pages 1000
14:13:27 EVNT@EVNT=>
14:13:27 EVNT@EVNT=> SELECT
14:13:27   2            'p_e_id='||e_id e_id
14:13:27   3        ,   NVL(e_name,e_code) e_code
14:13:27   4        ,   MAX(DECODE(day,'PEND',cnt,NULL)) PEND
14:13:27   5        ,   MAX(DECODE(day,'MON',cnt,NULL)) MON
14:13:27   6        ,   MAX(DECODE(day,'TUE',cnt,NULL)) TUE
14:13:27   7        ,   MAX(DECODE(day,'WED',cnt,NULL)) WED
14:13:27   8        ,   MAX(DECODE(day,'THU',cnt,NULL)) THU
14:13:27   9        ,   MAX(DECODE(day,'FRI',cnt,NULL)) FRI
14:13:27  10        ,   MAX(DECODE(day,'SAT',cnt,NULL)) SAT
14:13:27  11        ,   MAX(DECODE(day,'SUN',cnt,NULL)) SUN
14:13:27  12        FROM (
14:13:27  13        SELECT /*+ ORDERED */
14:13:27  14           e.e_id
14:13:27  15        ,  e.e_code
14:13:27  16        ,  e.e_name
14:13:27  17        ,  decode(et.trig_type,'ALL',TO_CHAR(et.et_trigger_time,'DY'),'PEND') day
14:13:27  18        ,  COUNT(*) cnt
14:13:27  19        FROM events e
14:13:27  20        ,    (select 'ALL' trig_type, e.* from event_triggers e where TRUNC(e.et_trigger_time,'IW') = TRUNC(TRUNC(SYSDATE,'IW'),'IW')
14:13:27  21              union all
14:13:27  22              select 'PEND' trig_type, e.* from event_triggers e where decode(et_phase_status,'P','P',null) = 'P') et
14:13:27  23        WHERE e.e_id = et.e_id
14:13:27  24        and e.e_code != 'SQL_SCRIPT'
14:13:27  25        and e.e_code != 'CHK_OS_LOG'
14:13:27  26        GROUP BY
14:13:27  27           e.e_id
14:13:27  28        ,  e.e_code
14:13:27  29        ,  e.e_name
14:13:27  30        ,  decode(et.trig_type,'ALL',TO_CHAR(et.et_trigger_time,'DY'),'PEND'))
14:13:27  31        GROUP BY
14:13:27  32            e_id
14:13:27  33        ,   NVL(e_name,e_code)
14:13:27  34        union all
14:13:27  35        SELECT
14:13:27  36            'p_ep_id='||ep_id e_id
14:13:27  37        ,   NVL(ep_desc,ep_code) e_code
14:13:27  38        ,   MAX(DECODE(day,'PEND',cnt,NULL)) PEND
14:13:27  39        ,   MAX(DECODE(day,'MON',cnt,NULL)) MON
14:13:27  40        ,   MAX(DECODE(day,'TUE',cnt,NULL)) TUE
14:13:27  41        ,   MAX(DECODE(day,'WED',cnt,NULL)) WED
14:13:27  42        ,   MAX(DECODE(day,'THU',cnt,NULL)) THU
14:13:27  43        ,   MAX(DECODE(day,'FRI',cnt,NULL)) FRI
14:13:27  44        ,   MAX(DECODE(day,'SAT',cnt,NULL)) SAT
14:13:27  45        ,   MAX(DECODE(day,'SUN',cnt,NULL)) SUN
14:13:27  46        FROM (
14:13:27  47        SELECT /*+ ORDERED */
14:13:27  48           et.ep_id
14:13:27  49        ,  et.ep_code
14:13:27  50        ,  et.ep_desc
14:13:27  51        ,  decode(et.trig_type,'ALL',TO_CHAR(et.et_trigger_time,'DY'),'PEND') day
14:13:27  52        ,  COUNT(*) cnt
14:13:27  53        FROM events e
14:13:27  54        ,    (select 'ALL' trig_type, e.* from event_triggers_all_v e where TRUNC(e.et_trigger_time,'IW') = TRUNC(TRUNC(SYSDATE,'IW'),'IW')
14:13:27  55              union all
14:13:27  56              select 'PEND' trig_type, e.* from event_triggers_all_v e where et_pending = 'P') et
14:13:27  57        WHERE e.e_id = et.e_id
14:13:27  58        and e.e_code in ('SQL_SCRIPT', 'CHK_OS_LOG')
14:13:27  59        GROUP BY
14:13:27  60           et.ep_id
14:13:27  61        ,  et.ep_code
14:13:27  62        ,  et.ep_desc
14:13:27  63        ,  decode(et.trig_type,'ALL',TO_CHAR(et.et_trigger_time,'DY'),'PEND'))
14:13:27  64        GROUP BY
14:13:27  65            ep_id
14:13:27  66        ,   NVL(ep_desc,ep_code)
14:13:27  67        ORDER BY 2
14:13:27  68  /

E_ID       E_CODE                               PEND        MON        TUE        WED        THU        FRI        SAT        SUN
---------- ------------------------------ ---------- ---------- ---------- ---------- ---------- ---------- ---------- ----------
p_e_id=42  3PAR IOPs Monitor                       1        223        236        171        548        856        856        511
p_ep_id=86 ASM Disk Group Usage Warning            5
p_e_id=50  ASM Log Errors                          1          8                    17         10
p_e_id=7   Alert Log Errors                                  14         54         40         27         18         47          6
p_e_id=55  DB Top Sessions                        20       4098       4108       3989       4561       4854       5110       2976
p_e_id=54  Data Guard Lag                          2
p_e_id=15  Database Down                           3         26                    24         10
p_e_id=43  Database Locks                                    14         10         33         23         27         16         14
p_e_id=56  High Commit Rate                        1        262        253        251        257        252        253        151
p_e_id=57  High Commit Rate [SERVICE]              1        263        252        252        257        252        253        151
p_e_id=19  High Log Switches                                                        5                     4
p_e_id=33  High Sort Usage                         1        116        116        108        102        108        104         71
p_e_id=21  High Undo Usage                                   12         14         21         16         26         21          7
p_e_id=12  High Wait Time                          4        167        149        222        212        184        242        182
p_e_id=58  Load Monitor [SERVICE]                  1        262        252        251        257        252        254        150
p_e_id=53  Os CPU Check                                      79        164        129        199         80        103         30
p_e_id=6   Runaway Session (IO)                    5        242        215        184        184        162        203        116
p_e_id=2   Runaway Session (TIME)                  2        158        188        179        191        174        219        105
p_ep_id=87 SPLEX Event Log Check                             69         52         22         39         42        158         67
p_ep_id=79 SQL_IDs with high Waits (5m/50         22       2992       2899       2920       2975       2945       2968       1757
p_ep_id=99 Shareplex LAG                           1
p_e_id=31  Tablespace Usage                        1         34         34         30         50         37         43          2

22 rows selected.

