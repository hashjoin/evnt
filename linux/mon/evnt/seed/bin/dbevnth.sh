#!/bin/ksh
#
# File:
#       dbevnth.sh
# EVNT_REG:	DB_EVNT SEEDMON 1.3 Y
# <EVNT_NAME>High Avg Wait Time</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports database events with high number of average wait time
# REQUIRES COLLECTION from v$system_event view .  Makes comparison
# of previous and current snapshots from v$system_event.
# 
# The following events are ignored:
#    'rdbms ipc message'
#    'pmon timer'
#    'smon timer'
#    'pipe get'
#    'pipe put'
#    'wakeup time manager'
#    'PL/SQL lock timer'
#    'single-task message'
#    'queue messages'
#    'PX Idle Wait'
# 9i specific
#    'virtual circuit status'
#    'dispatcher timer'
#    'jobq slave wait'
# 10g specific
#    'Streams AQ%'
#
# REPORT ATTRIBUTES:
# -----------------------------
# event_count
# sec_avg_evnt
# TOT_sec_in_wait
# TOT_min_in_wait
# event
#
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  -----------
# AVG_WAIT        threshold for average wait time per all events      5
#                 if time_waited/event_count > <AVG_WAIT> then
#                 the event will be set (fire).
#                 DEFAULT=0 (sec)
#
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        12/17/2002      Created
#       VMOGILEV        01/28/2003      Made compatible with 1.8.1
#       VMOGILEV        01/21/2004      added 9i idle event filters
#       VMOGILEV        05/19/2008      added 10g idle event filters
#


chkfile=$1
outfile=$2
clrfile=$3

if [ "$PARAM__AVG_WAIT" ]; then
	AVG_WAIT="$PARAM__AVG_WAIT"
else
	echo "using default value (0 sec) for AVG_WAIT ..."
	AVG_WAIT="0"
fi

if [ "$CA_ID" ]; then
	echo "CA_ID=${CA_ID}"
else
	echo "CA_ID is not set, exiting ..."
	exit 1;
fi

if [ "$PARAM__cp_code" ]; then
	COLL_CODE="$PARAM__cp_code"
else
	echo "PARAM__cp_code is not set, exiting ..."
	exit 1;
fi


sqlplus -s $uname_passwd <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
set lines 2000

--
-- call collection parser
-- to get curr/prev table names
--
@$EVNT_TOP/seed/sql/getsnp.sql $COLL_CODE $MON__S_ID $CA_ID

set verify off

spool $chkfile

SELECT event_count
||','||LTRIM(TO_CHAR(time_waited/event_count/100,'99,999,999'))
||','||LTRIM(TO_CHAR(time_waited/100,'99,999,999.99'))
||','||LTRIM(TO_CHAR(time_waited/100/60,'99,999,999.99'))
||','||event
from (
  select  e.total_waits-b.total_waits event_count,
          e.time_waited-b.time_waited time_waited,
          e.event
    from  &&X_out_psnp b , &&X_out_csnp e
    where b.event = e.event
  union all
  select  e.total_waits event_count,
          e.time_waited time_waited,
          e.event
    from  &&X_out_csnp e
    where e.event not in (select b.event from &&X_out_psnp b))
WHERE event not like 'SQL*Net%'
and event != 'rdbms ipc message'
and event != 'pmon timer'
and event != 'smon timer'
and event != 'pipe get'
and event != 'pipe put'
and event != 'wakeup time manager'
and event != 'PL/SQL lock timer'
and event != 'single-task message'
and event != 'queue messages'
and event != 'PX Idle Wait'
and event != 'virtual circuit status'
and event != 'dispatcher timer'
and event != 'jobq slave wait'
and event not like 'Streams AQ%'
and time_waited > 0
and event_count > 0
-- only show events that had
-- a an average wait time > 0 sec
and trunc(time_waited/100/decode(event_count,0,1,event_count)) > $AVG_WAIT
order by time_waited desc
/


spool off
exit
CHK


## check for errors
##
if [ $? -gt 0 ]; then
        cat $chkfile.err
        rm $chkfile.err
        exit 1;
fi


## if I got here remove error chk file
##
rm $chkfile.err

