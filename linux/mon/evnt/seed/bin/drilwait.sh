#!/bin/ksh
#
# $Header drilwait.sh 09/12/2003 1.6
#
# File:
#       drilwait.sh
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV (vit100gain@earthlink.net)
#
# Purpose:
#       Drill script to v$session* and locks
#
# Usage:
#       drilwait.sh <sid_list_comma_sep_file>
#
# History:
#       VMOGILEV        06/11/2002      Created
#       VMOGILEV        09/12/2003      added v$session_event drill
#       VMOGILEV        11/09/2009      added wait_class% columns
#       VMOGILEV        10/23/2013      (1.4)	switched to pt() for v$session_event and added call to topw.sql
#       VMOGILEV        10/29/2013      (1.5)	switched to topwm.sql to show top events from last run minutes
#       VMOGILEV        11/18/2013      (1.6)	pulled locks out


sesfile=$1
outfile=$2


##OSID_LIST=`awk 'BEGIN { FS = "," } { if ( NR == 1 ) { print $1 } if ( NR > 1 ) { print "," $1 } }' $sesfile`
OSID_LIST=`awk 'BEGIN { FS = "," } { if ( NR == 1 ) { printf("%s", $1) } if ( NR > 1 ) { printf(",%s", $1) } }' $sesfile`

sqlplus -s $MON__CONNECT_STRING <<CHK > $outfile.local
WHENEVER SQLERROR EXIT FAILURE
spool $outfile
@$EVNT_TOP/seed/sql/topwm.sql ${MON__EA_MIN_INTERVAL}

set trims on
clear col

prompt V\$SESSION_WAIT Details
prompt ~~~~~~~~~~~~~~~~~~~~~~~~

set serveroutput on size unlimited
exec pt('select * from v\$session_wait where sid IN (${OSID_LIST})');

clear col

col SID               format a80 noprint new_value n_SID
col EVENT             format a35

set lines 100
set trims on
set pages 60
break on sid skip page

prompt V\$SESSION_EVENT Details

ttitle center "*** v\$session_event stats for SID(" n_SID ") ***"

select  to_char(sid) sid,event,total_waits,total_timeouts,
        time_waited,average_wait,max_wait
from v\$session_event
where sid in ($OSID_LIST)
order by sid, event;

spool off
exit
CHK

if [ $? -gt 0 ]; then
	cat $outfile.local >> $outfile
	exit 1;
fi

rm -f $outfile.local

