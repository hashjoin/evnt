#!/bin/ksh
#
# File:
#       dblogsw.sh
# EVNT_REG:	DB_LOG_SWITCH SEEDMON 1.2
# <EVNT_NAME>High Log Switches</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks for high number of log switches per hour, drills down
# to session SQL and APPS level
# connections
# 
# REPORT ATTRIBUTES:
# -----------------------------
# switch date
# number of switches
# thread#
# 
# PARAMETER       DESCRIPTION                            EXAMPLE
# --------------  -------------------------------------  --------
# LOOKBACK_MIN    number of minutes to look back in      30
#                 V$LOGHIST view
#                 DEFAULT=60
#                 
# LOG_SWITCHES    threshold for # or log switches per    8
#                 hour
#                 DEFAULT=4
# 
# APPS_TYPE       Set this parameter if APPS related     11i
#                 session details are nessesary. 
#                 Allowable values are - "11i"
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        11/08/2002      v1.1 Created
#       VMOGILEV        11/08/2002      v1.2 Made RAC aware
#

chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__LOOKBACK_MIN" ]; then
        echo "using default lookback minutes parameter: 60 "
        PARAM__LOOKBACK_MIN=60
fi

if [ ! "$PARAM__LOG_SWITCHES" ]; then
        echo "using default log-switches parameter: 4 "
        PARAM__LOG_SWITCHES=4
fi

if [ "$PARAM__APPS_TYPE" ]; then
        APPS_TYPE=$PARAM__APPS_TYPE
fi



sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set lines 2000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $chkfile
SELECT
COUNT(*)
||' log switches in the last $PARAM__LOOKBACK_MIN minutes SYSDATE='||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS')
||', THREAD# '||h.thread#
FROM v\$loghist h, v\$instance i
WHERE TRUNC(((SYSDATE-h.first_time)/(1/24))*60) < $PARAM__LOOKBACK_MIN
and h.thread# = i.thread#
and i.INSTANCE_NUMBER = sys_context('userenv','instance')
GROUP BY
   h.thread#
HAVING COUNT(*) > $PARAM__LOG_SWITCHES
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


sqlplus -s $MON__CONNECT_STRING <<REPORT >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
set lines 132
set trims on
ALTER SESSION SET NLS_DATE_FORMAT='RRRR-MON-DD HH24:MI:SS';
spool $outfile
SELECT h.* 
FROM v\$loghist h, v\$instance i
WHERE TRUNC(((SYSDATE-first_time)/(1/24))*60) < $PARAM__LOOKBACK_MIN
and h.thread# = i.thread#
and i.INSTANCE_NUMBER = sys_context('userenv','instance')
ORDER BY h.first_time DESC
/
spool off
exit
REPORT

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

##
## GET THE SIDS WITH HIGHEST REDO SIZES
## 
sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
set lines 2000
set verify off
set pages 0
set head off
set feed off
set trims on
set echo off
spool $chkfile.sid
-- ABS(value) here is to avoid NEGATIVE
-- REDO SIZEs, I've noticed it with
-- frequent commits
--
SELECT sid||', TOTAL REDO: '||ABS(value)||'  PCT: '||TO_CHAR(((ABS(value) * 100) / total.val),'99.00')
FROM v\$sesstat
,    (select sum(ABS(value)) val
      FROM v\$sesstat
      WHERE statistic# in (select statistic# from v\$statname where name like 'redo size')) total
WHERE statistic# in (select statistic# from v\$statname where name like 'redo size')
AND   ((ABS(value) * 100) / total.val) > 0.5
ORDER BY ABS(value) desc
/
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

echo " " >> $outfile
echo "SIDS with highest REDO SIZES: " >> $outfile
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $outfile
echo " " >> $outfile
cat $chkfile.sid >> $outfile
echo " " >> $outfile


# get sql for these sessions
#
$SEEDMON/drilsql.sh $chkfile.sid $outfile.tmp.drilsql
if [ $? -gt 0 ]; then
        exit 1;
fi
cat $outfile.tmp.drilsql >> $outfile


dril_apps11i()
{
# get APPS 11i details for these sessions
#
$SEEDMON/drilapps11i.sh $chkfile.sid $outfile.tmp.drilapps11i
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
rm -f $outfile.tmp.drilsql $chkfile.sid

