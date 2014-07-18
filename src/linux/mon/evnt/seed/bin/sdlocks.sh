#!/bin/ksh
#
# File:
#       sdlocks.sh
# EVNT_REG:	DB_LOCKS SEEDMON 1.1
# <EVNT_NAME>Database Locks</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (hashjoin.com)
#
# Usage:
# <EVNT_DESC>
# Reports blocked sessions
# 
# REPORT ATTRIBUTES:
# -----------------------------
# INST_ID
# sid
# event
# MACHINE
# nvl(nvl(SQL_ID,PREV_SQL_ID),'null')
# 
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  -----------
# TIMETRES        < gv$session.seconds_in_wait                        20
# 
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        19-DEC-2013      (v1.0) created
#       VMOGILEV        19-DEC-2013      (v1.1) switched to v$session
#


chkfile=$1
outfile=$2
clrfile=$3
prevfile=$4

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
select INST_ID||','||sid||','||event||','||MACHINE||','||nvl(nvl(SQL_ID,PREV_SQL_ID),'null')
from gv\$session
where wait_time = 0
and event like 'enq: TX%'
and seconds_in_wait > $PARAM__TIMETRES
order by INST_ID,sid,event;
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
	echo "sdlocks.sh: new values found - doing drilldowns ..."
else
	echo "sdlocks.sh: same trigger attributes - existing ..."
	exit 0 ;
fi


# get locks for these sessions
#
$SEEDMON/drillock.sh $chkfile $outfile.tmp.drillock
if [ $? -gt 0 ]; then
	cat $outfile.tmp.drillock
        exit 1;
fi
cat $outfile.tmp.drillock >> $outfile


# cleanup temp files
#
rm -f $outfile.tmp.drilsql $outfile.tmp.drilwait $outfile.tmp.drillock

