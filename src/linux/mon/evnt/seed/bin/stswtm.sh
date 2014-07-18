#!/bin/ksh
#
# File:
#       stswtm.sh
# EVNT_REG:	WAIT_TIME SEEDMON 1.8
# <EVNT_NAME>High Wait Time</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (hashjoin.com)
#
# Usage:
# <EVNT_DESC>
# Reports sessions with long wait times gives details of the sessions
# 
# REPORT ATTRIBUTES:
# -----------------------------
# sid
# event
# MACHINE
# nvl(nvl(SQL_ID,PREV_SQL_ID),'null')
# 
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  -----------
# TIMETRES        < v$session_wait.seconds_in_wait                    20
# 
# APPS_TYPE       Set this parameter if APPS related session details  11i
#                 are nessesary.  Allowable values are - "11i"
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        19-AUG-2002      (v1.1) Created
#       VMOGILEV        16-APR-2007      (v1.2) Filtered out Queue Monitor Wait
#						and jobq slave wait (10g)
#       VMOGILEV        03-SEP-2009      (v1.3) filtered out RAC/ASM idle events
#       VMOGILEV        20-NOV-2009      (v1.3) filtered out EMON idle wait
#       VMOGILEV        23-OCT-2013      (v1.4) switched to WAIT_CLASS <> 'Idle'
#       VMOGILEV        18-OCT-2013      (v1.6) added lock drills (pulled from drilwait)
#       VMOGILEV        02-DEC-2013      (v1.7) removed drillocks
#       VMOGILEV        28-JAN-2014      (v1.8) switched to v$session
#


chkfile=$1
outfile=$2
clrfile=$3
prevfile=$4

if [ "$PARAM__APPS_TYPE" ]; then
        APPS_TYPE=$PARAM__APPS_TYPE
fi

sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
set lines 500
spool $chkfile
select sid||','||event||','||MACHINE||','||nvl(nvl(SQL_ID,PREV_SQL_ID),'null')
from v\$session
where wait_time = 0
and WAIT_CLASS <> 'Idle'
and seconds_in_wait > $PARAM__TIMETRES
order by sid,event;
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


if [ `cat $chkfile | wc -l` -eq 0 ]; then
	exit 0 ;
fi


## only do the expensive drilldowns if this is a new trigger
if [ `diff $prevfile $chkfile | wc -l` -gt 0 ]; then
	echo "stswtm.sh: new values found - doing drilldowns ..."
else
	echo "stswtm.sh: same trigger attributes - existing ..."
	exit 0 ;
fi


echo "List of sessions with WAIT > $PARAM__TIMETRES sec" > $outfile
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $outfile

# get wait for these sessions
#
$SEEDMON/drilwait.sh $chkfile $outfile.tmp.drilwait
if [ $? -gt 0 ]; then
	cat $outfile.tmp.drilwait >> $outfile
        exit 1;
fi
cat $outfile.tmp.drilwait >> $outfile

# get sql for these sessions
#
$SEEDMON/drilsql.sh $chkfile $outfile.tmp.drilsql
if [ $? -gt 0 ]; then
	cat $outfile.tmp.drilsql >> $outfile
        exit 1;
fi
cat $outfile.tmp.drilsql >> $outfile

# get locks for these sessions
#
##VM $SEEDMON/drillock.sh $chkfile $outfile.tmp.drillock
##VM if [ $? -gt 0 ]; then
##VM 	cat $outfile.tmp.drillock
##VM         exit 1;
##VM fi
##VM cat $outfile.tmp.drillock >> $outfile

dril_apps11i()
{
# get APPS 11i details for these sessions
#
$SEEDMON/drilapps11i.sh $chkfile $outfile.tmp.drilapps11i
if [ $? -gt 0 ]; then
        exit 1;
fi
cat $outfile.tmp.drilapps11i >> $outfile
rm -f $outfile.tmp.drilapps11i
}

# check if APPS level drills are required
#
case "$APPS_TYPE" in
11i)   dril_apps11i ;;
OTHER)  dril_apps11i ;;
esac


# cleanup temp files
#
rm -f $outfile.tmp.drilsql $outfile.tmp.drilwait $outfile.tmp.drillock

