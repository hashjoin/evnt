#!/bin/ksh
#
# File:
#       rbspctu.sh
# EVNT_REG:	RBS_SIZE SEEDMON 1.2
# <EVNT_NAME>High Rollback Usage</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks RBS current size if > optimal by a predefined threshold
# If triggered gives detailed report of rollback segments and 
# all active transactions.
# 
# REPORT ATTRIBUTES:
# -----------------------------
# rbs name
# extents
# current size in KB
# optimal size in KB
# status
# 
# PARAMETER       DESCRIPTION                            EXAMPLE
# --------------  -------------------------------------  ---------------
# OVER_OPTIMAL    curr/opt ratio                         5
#                 DEFAULT=2
# 
# EXCLUDE_LIST    rbs name to exclude from check         'RBS01','RBS02'
#                 NO DEFAULT
# 
# APPS_TYPE       Set this parameter if APPS related     11i
#                 session details  
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        11/06/2002      Created
#       VMOGILEV        04/30/2003      1.2 added RBS_LIST filter
#


chkfile=$1
drillfile=$chkfile.drill
outfile=$2
clrfile=$3

if [ ! "$PARAM__EXCLUDE_LIST" ]; then
	PARAM__EXCLUDE_LIST="'x'"
fi

if [ ! "$PARAM__OVER_OPTIMAL" ]; then
	echo "using default over optimal => 2"
	PARAM__OVER_OPTIMAL=2
fi

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
spool $chkfile
select vrn.name
||','||vrs.extents
||','||round(vrs.rssize/1024,2)
||','||round(vrs.optsize/1024,2)
||','||vrs.status
from v\$rollname vrn
,v\$rollstat vrs
where vrs.usn = vrn.usn
and (round(vrs.rssize/1024,2) / 
        round(vrs.optsize/1024,2)) >= $PARAM__OVER_OPTIMAL
and vrn.name NOT IN ($PARAM__EXCLUDE_LIST)
order by 1
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


if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi

sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
spool $outfile
set trims on
@$EVNT_TOP/seed/sql/s_rbs.sql
@$EVNT_TOP/seed/sql/c_user_rbs.sql
spool off
exit
CHK

## check for errors
##
if [ $? -gt 0 ]; then
        cat $outfile.err
        rm $outfile.err
        exit 1;
fi

## if I got here remove error chk file
##
rm $outfile.err

## parse the IN clause for the RBS names
##
RBS_LIST=`awk "BEGIN { FS = \",\" } { if ( NR == 1 ) { print \"'\" \\$1 \"'\" } if ( NR > 1 ) { print \",'\" \\$1 \"'\" } }" $chkfile`

sqlplus -s $MON__CONNECT_STRING <<DRILL >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
set lines 2000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $drillfile
select sid
||','||serial#
from sys.v_\$transaction t
,    sys.v_\$rollname r
,    sys.v_\$session s
where t.xidusn = r.usn
  and r.name in (${RBS_LIST})
  and t.ses_addr = s.saddr
/
spool off
exit
DRILL

## check for errors
##
if [ $? -gt 0 ]; then
        cat $outfile.err
        rm $outfile.err
        exit 1;
fi

## if I got here remove error chk file
##
rm $outfile.err


if [ `cat $drillfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi

# get sql for these sessions
#
echo "##########################################################################" >> $outfile
echo "#######   List below includes only session that use relevant RBS   #######" >> $outfile
echo "##########################################################################" >> $outfile
echo " " >> $outfile
$SEEDMON/drilsql.sh $drillfile $outfile.tmp.drilsql
if [ $? -gt 0 ]; then
        exit 1;
fi
cat $outfile.tmp.drilsql >> $outfile

dril_apps11i()
{
echo " " >> $outfile
# get APPS 11i details for these sessions
#
$SEEDMON/drilapps11i.sh $drillfile $outfile.tmp.drilapps11i
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
rm -f $outfile.tmp.drilsql $outfile.tmp.drilwait

