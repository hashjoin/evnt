#!/bin/ksh
#
# File:
#       dbtopses.sh
# EVNT_REG:	DB_TOP_SESS SEEDMON 1.11
# <EVNT_NAME>DB Top Sessions</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Reports TOP Sessions from ASH
#
# REPORT ATTRIBUTES:
# -----------------------------
# MACHINE
# SQL_ID
# SQL_HASH_VALUE
# SPID
#
#
# PARAMETER       DESCRIPTION                                 EXAMPLE
# --------------  ------------------------------------------  --------
# SECS_ACTIVE     Active ASH Seconds Threshold                30
#			[default=30]
# TSEC_WARN       Warning Level of seconds spent on event     3000
#			[default=3000]
# TSEC_CRIT       Critical Level of seconds spent on event    7000
#			[default=7000]
# HOST_DOMAIN     Domain Name to Filter out from hostname
#                 for purly cosmetic reasons to shorten the
#                 column of the report                        .eharmony.com
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        03/10/2014      v1.0	Created
#       VMOGILEV        03/12/2014      v1.3	Pushed back the start window by 45 seconds
#       VMOGILEV        03/13/2014      v1.4	Fixed logic to pull machine name and added sid||_||serial to attribute list
#       VMOGILEV        03/13/2014      v1.5	Added CLIENT_ID to attribute list
#       VMOGILEV        03/14/2014      v1.6	Increased event column sizing
#       VMOGILEV        03/14/2014      v1.7	Switched to UNION from UNION ALL on attributes
#       VMOGILEV        03/17/2014      v1.8	Added Blocks
#       VMOGILEV        03/18/2014      v1.9	Added CRITICAL|WARNING_LEVEL
#       VMOGILEV        03/18/2014      v1.10	Increased P1 width
#       VMOGILEV        07/03/2014      v1.11	Added save to REPDB
#


chkfile=$1
outfile=$2
clrfile=$3

REMOTE_HOST="$MON__H_NAME"
SHORT_HOST=${REMOTE_HOST%%.*}
REPDB_CONNECT=${PARAM__REPDB_CONNECT}
SECS_ACTIVE=${PARAM__SECS_ACTIVE}
HOST_DOMAIN=${PARAM__HOST_DOMAIN}
TSEC_CRIT=${PARAM__TSEC_CRIT}
TSEC_WARN=${PARAM__TSEC_WARN}
LOOK_BACK=${MON__EA_MIN_INTERVAL}

if [ ${SECS_ACTIVE}"x" == "x" ]; then
	SECS_ACTIVE=30
fi

if [ ${HOST_DOMAIN}"x" == "x" ]; then
	HOST_DOMAIN=".null.com"
fi

if [ ${TSEC_CRIT}"x" == "x" ]; then
	TSEC_CRIT=7000
fi

if [ ${TSEC_WARN}"x" == "x" ]; then
	TSEC_WARN=30
fi

sqlplus -s $MON__CONNECT_STRING <<CHK > $chkfile.err
WHENEVER SQLERROR EXIT FAILURE

insert into top_sessions
select $MON__EA_ID,
       w.secs ash_secs,
       s.machine,
       s.process,
       s.OSUSER,
       s.PADDR,
       s.LOGON_TIME,
       nvl(s.service_name,ds.name),
       ash.*
from v\$active_session_history ash
,    (
        select count(*) secs, min(sample_id) mins, max(sample_id) maxs, session_id,session_serial#
        from v\$active_session_history
        where sample_time > sysdate-(${LOOK_BACK}/24/60)-(45/24/60/60)
        --and session_type <> 'BACKGROUND'
        group by session_id,session_serial#
        having count(*) > ${SECS_ACTIVE}
     ) w
,    v\$session s
,    dba_services ds
where ash.sample_time > sysdate-(${LOOK_BACK}/24/60)-(45/24/60/60)
  -- (ash.sample_id between w.mins and w.maxs)
  and ash.session_id = w.session_id
  and ash.session_serial# = w.session_serial#
  and ash.session_id = s.sid(+)
  and ash.session_serial# = s.serial#(+)
  and ash.SERVICE_HASH = ds.NAME_HASH(+)
;

set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
set lines 1000
spool $chkfile
select x from (
select
   case
      when max(tsecs) >= ${TSEC_CRIT} then 'CRITICAL_LEVEL'
      when max(tsecs) >= ${TSEC_WARN} then 'WARNING_LEVEL'
   end as x
from
              (select count(*) tsecs
               ,      event
               from top_sessions
               where ea_id = $MON__EA_ID
               group by event
               order by 1 desc)
where rownum < 11
union
select distinct nvl(rtrim(substr(machine,1,instr(machine,'${HOST_DOMAIN}')),'.'),nvl(machine,substr(program,nvl(instr(program,'@'),0)+1))) from top_sessions where ea_id = $MON__EA_ID union
select distinct decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-')) from top_sessions where ea_id = $MON__EA_ID union
select distinct nvl(sql_id,'null') from top_sessions where ea_id = $MON__EA_ID union
select distinct nvl(event,'ON CPU') from top_sessions where ea_id = $MON__EA_ID union
select distinct nvl(module,'null') from top_sessions where ea_id = $MON__EA_ID union
select distinct session_id||'_'||session_serial# from top_sessions where ea_id = $MON__EA_ID union
select distinct CLIENT_ID from top_sessions where ea_id = $MON__EA_ID and CLIENT_ID is not null union
select distinct nvl(program,'null') from top_sessions where ea_id = $MON__EA_ID)
where x is not null
order by 1;
spool off

spool $outfile
col service_name format a20
col machine format a35 trunc
col wait_class format a12 trunc
col session_id heading "SID"
col session_serial# heading "SERAL#"
col event format a35 trunc
col program format a15
col sql_plan_hash_value format 99999999999 heading "SQL_HASH"
col tsecs format 99999
col ssecs format 99999
col sid format 9999

set lines 171
set trims on
set pages 1000
set head on
set feed on

clear breaks
--break on session_id skip 2
--compute sum of ssecs on session_id
break on session_id on session_serial# skip 2
compute sum of ssecs on session_serial#

select x severity from (
select
   case
      when max(tsecs) >= ${TSEC_CRIT} then 'CRITICAL_LEVEL'
      when max(tsecs) >= ${TSEC_WARN} then 'WARNING_LEVEL'
      else 'MINOR'
   end as x
from
              (select count(*) tsecs
               ,      nvl(event,'ON CPU') event
               from top_sessions
               where ea_id = $MON__EA_ID
               group by event
               order by 1 desc)
where rownum < 11);



select count(*) tsecs
,      decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-')) service_name
,      nvl(sql_id,'null') sql_id
,      sql_plan_hash_value
from top_sessions
where ea_id = $MON__EA_ID
group by
       decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-'))
,      nvl(sql_id,'null')
,      sql_plan_hash_value
order by count(*) desc;


select * from (select count(*) tsecs
               ,      sql_id
               ,      sql_plan_hash_value
               from top_sessions
               where ea_id = $MON__EA_ID
               group by sql_id, sql_plan_hash_value
               order by 1 desc)
where rownum < 11;

select * from (select count(*) tsecs
               ,      nvl(event,'ON CPU') event
               from top_sessions
               where ea_id = $MON__EA_ID
               group by nvl(event,'ON CPU')
               order by 1 desc)
where rownum < 11;

select * from (select count(*) tsecs
               ,      nvl(event,'ON CPU') event
               ,      sql_id
               ,      sql_plan_hash_value
               from top_sessions
               where ea_id = $MON__EA_ID
               group by nvl(event,'ON CPU'), sql_id, sql_plan_hash_value
               order by 1 desc)
where rownum < 11;

prompt blocks ...
col p1text format a15
col p1 format 999999999999999
select * from (
    select count(*), event, p1text,p1, blocking_session, blocking_session_serial#
    from top_sessions
    where ea_id = $MON__EA_ID
    and BLOCKING_SESSION is not null
    group by event, p1text,p1,blocking_session, blocking_session_serial#
    order by 1 desc)
where rownum < 11;



select count(*) tsecs
,      decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-')) service_name
,      nvl(event,'ON CPU') event
,      nvl(wait_class,'null') wait_class
from top_sessions
where ea_id = $MON__EA_ID
group by
       decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-'))
,      nvl(event,'ON CPU')
,      nvl(wait_class,'null')
order by count(*) desc;

select count(*) tsecs
--,      nvl(rtrim(substr(machine,1,instr(machine,'${HOST_DOMAIN}')),'.'),substr(program,nvl(instr(program,'@'),0)+1)) machine
,      nvl(rtrim(substr(machine,1,instr(machine,'${HOST_DOMAIN}')),'.'),nvl(machine,substr(program,nvl(instr(program,'@'),0)+1))) machine
,      decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-')) service_name
from top_sessions
where ea_id = $MON__EA_ID
group by
       nvl(rtrim(substr(machine,1,instr(machine,'${HOST_DOMAIN}')),'.'),nvl(machine,substr(program,nvl(instr(program,'@'),0)+1)))
,      decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-'))
order by count(*) desc;


col min_sample_time format a28
col max_sample_time format a28
col duration_time format a28

select min(sample_time) min_sample_time
,      max(sample_time) max_sample_time
,      max(sample_time) -
       min(sample_time) duration_time
from top_sessions;

select min(SAMPLE_ID) min_sample_id
,      max(SAMPLE_ID) max_SAMPLE_ID
from top_sessions;



select ash_secs tsecs
,      nvl(rtrim(substr(machine,1,instr(machine,'${HOST_DOMAIN}')),'.'),nvl(machine,substr(program,nvl(instr(program,'@'),0)+1))) machine
,      decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-')) service_name
,      session_id
,      session_serial#
,      count(*) ssecs
,      nvl(sql_id,'null') sql_id
,      sql_plan_hash_value
,      nvl(event,'ON CPU') event
,      nvl(wait_class,'null') wait_class
from top_sessions
where ea_id = $MON__EA_ID
group by
       ash_secs,
       nvl(rtrim(substr(machine,1,instr(machine,'${HOST_DOMAIN}')),'.'),nvl(machine,substr(program,nvl(instr(program,'@'),0)+1))),
       decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-')),
       session_id, session_serial#,
       nvl(sql_id,'null'), sql_plan_hash_value,
       nvl(event,'ON CPU'),
       nvl(wait_class,'null')
order by session_id
,        session_serial#
,        count(*) desc;

--SET SERVEROUTPUT ON size unlimited
--exec pt('select count(*) cnt, ash_secs, service_name, machine, program, session_id, session_serial# from top_sessions where ea_id = $MON__EA_ID group by ash_secs, service_name, machine, program, session_id, session_serial#');

set lines 187
clear breaks
clear col

col cnt format 999999
col ASH_SECS format 999999
col SERVICE_NAME format a25
col MACHINE format a45
col PROGRAM format a50
col SESSION_ID format 99999 heading "SID"
col SESSION_SERIAL# format 999999 heading "SERIAL"
col CLIENT_ID format a30 trunc

select count(*) cnt, ash_secs,
       session_id, session_serial#,
       service_name, machine,
       program, CLIENT_ID
from top_sessions
where ea_id = $MON__EA_ID
group by ash_secs, service_name,
         machine, program, session_id,
         session_serial#, CLIENT_ID
order by session_id;


spool off


-- DAT file generation for remote REPORTING save
--
col min_sample_id new_value _min_sample_id

select min(SAMPLE_ID) min_sample_id
  from top_sessions
 where ea_id = $MON__EA_ID;

set pages 0
set feed off
set head off
set lines 400
set trims on
set verify off

spool $chkfile.dat

select
'${REMOTE_HOST}:${MON__S_NAME}'
||','||&&_min_sample_id
||','||to_char(sysdate,'YYYYMMDDHH24MISS')
||','||x.ASH_SECS
||','||x.MACHINE
||','||x.SERVICE_NAME
||','||x.SESSION_ID
||','||x.SESSION_SERIAL#
||','||x.SSECS
||','||x.SQL_ID
||','||x.SQL_PLAN_HASH_VALUE
||','||x.EVENT
||','||x.WAIT_CLASS
||','||x.CLIENT_ID
from (
		select ash_secs tsecs
		,      nvl(rtrim(substr(machine,1,instr(machine,'${HOST_DOMAIN}')),'.'),nvl(machine,substr(program,nvl(instr(program,'@'),0)+1))) machine
		,      decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-')) service_name
		,      session_id
		,      session_serial#
		,      count(*) ssecs
		,      nvl(sql_id,'null') sql_id
		,      sql_plan_hash_value
		,      nvl(event,'ON CPU') event
		,      nvl(wait_class,'null') wait_class
		,      nvl(CLIENT_ID,'null') CLIENT_ID
		from top_sessions
		where ea_id = $MON__EA_ID
		group by
			   ash_secs,
			   nvl(rtrim(substr(machine,1,instr(machine,'${HOST_DOMAIN}')),'.'),nvl(machine,substr(program,nvl(instr(program,'@'),0)+1))),
			   decode(service_name,'SYS\$BACKGROUND',substr(program,-5,3),nvl(service_name,'-EXPIRED-')),
			   session_id, session_serial#,
			   nvl(sql_id,'null'), sql_plan_hash_value,
			   nvl(event,'ON CPU'),
			   nvl(wait_class,'null'),
			   nvl(CLIENT_ID,'null')
		order by session_id
		,        session_serial#
		,        count(*) desc
) x;

spool off

exit
CHK

if [ $? -gt 0 ]; then
	cat $chkfile.err
	rm -f $chkfile.err
	exit 1;
fi

rm -f $chkfile.err


if [ ${REPDB_CONNECT}"x" == "x" ]; then
    rm -f $chkfile.dat
    exit;
fi

if [ `cat $chkfile.dat | wc -l` -gt 0 ]; then
	echo "dat file has rows loading to reporting ..."
else
	echo "NO dat file -- exiting ..."
	exit;
fi


echo "
LOAD DATA
INTO TABLE ash_monitor_all
APPEND
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(
  db_name
, sample_id
, trigger_time			\"to_date(:trigger_time, 'YYYYMMDDHH24MISS')\"
, ash_secs
, machine
, service_name
, session_id
, session_serial#
, ssecs
, sql_id
, sql_plan_hash_value
, event
, wait_class
, client_id
)" > $chkfile.sqlldr.ctl

sqlldr ${REPDB_CONNECT} \
    data=$chkfile.dat \
    control=$chkfile.sqlldr.ctl \
    log=$chkfile.sqlldr.log \
    discard=$chkfile.sqlldr.bad

## check for errors
##
if [ $? -gt 0 ]; then
	head $chkfile.dat
	tail $chkfile.dat
    cat $chkfile.sqlldr.bad
    cat $chkfile.sqlldr.log
    rm -f $chkfile.sqlldr.ctl
    rm -f $chkfile.sqlldr.bad
    rm -f $chkfile.sqlldr.log
    exit 1;
fi

rm -f $chkfile.dat
rm -f $chkfile.sqlldr.ctl
rm -f $chkfile.sqlldr.bad
rm -f $chkfile.sqlldr.log

