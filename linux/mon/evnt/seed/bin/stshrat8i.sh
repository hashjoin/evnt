#!/bin/ksh
#
# File:
#       stshrat8i.sh
# EVNT_REG:	DB_CACHE_8I SEEDMON 1.1
# <EVNT_NAME>Low Cache Hit Ratio</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks for low "cache hit ratio" (8i+)
# 
# Refer to Metalink Doc ID: 33883.1 STATISTIC "cache hit ratio" 
#       - Reference Note
# 
# 8i hit ratio =                                                                                     
#       1 -  ( physical reads - (physical reads direct + 
#              physical reads direct (lob)) )           
#            -------------------------------------------------------------           
#            ( db block gets + consistent gets - 
#              (physical reads direct + physical reads direct (lob)) )
# 
# REPORT ATTRIBUTES:
# -----------------------------
# ratio
# 
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  --------
# HIT_RATIO_TRES  Alert triggered if calculated ratio is lower then   80
#                 HIT_RATIO_TRES, DEFAULT=90
# 
# APPS_TYPE       Set this parameter if APPS related session details  11i
#                 are nessesary.  Allowable values are - "11i"
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        09/10/2002      Created
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__HIT_RATIO_TRES" ]; then
        PARAM__HIT_RATIO_TRES=90
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
SELECT TO_CHAR(TRUNC(
          (1 - (phy.value - (phyd.value + phydl.value)) /
               (get.value + con.value - (phyd.value + phydl.value))
          ) * 100
               ,0)) hit_ratio
FROM v\$sysstat phy
,    v\$sysstat phyd
,    v\$sysstat phydl
,    v\$sysstat get
,    v\$sysstat con
WHERE phy.name = 'physical reads'
AND   phyd.name = 'physical reads direct'
AND   phydl.name = 'physical reads direct (lob)'
AND   get.name = 'db block gets'
AND   con.name = 'consistent gets'
AND   TRUNC(
          (1 - (phy.value - (phyd.value + phydl.value)) /
               (get.value + con.value - (phyd.value + phydl.value))
          ) * 100
               ,0) < $PARAM__HIT_RATIO_TRES
AND  (1 - (phy.value - (phyd.value + phydl.value)) /
               (get.value + con.value - (phyd.value + phydl.value))) > 0
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
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $outfile.tmp
SELECT phy.sid
||','||TO_CHAR(TRUNC(
          (1 - (phy.value - (phyd.value + phydl.value)) /
               (get.value + con.value - (phyd.value + phydl.value))
          ) * 100
               ,2)) hit_ratio
FROM v\$sesstat phy
,    v\$sesstat phyd
,    v\$sesstat phydl
,    v\$sesstat get
,    v\$sesstat con
WHERE phy.statistic# = 40 /*'physical reads'*/
AND   phyd.statistic# = 86 /*'physical reads direct'*/
AND   phydl.statistic# = 88 /*'physical reads direct (lob)'*/
AND   get.statistic# = 38 /*'db block gets'*/
AND   con.statistic# = 39 /*'consistent gets'*/
AND   (TRUNC(
          (1 - (phy.value - (phyd.value + phydl.value)) /
               (get.value + con.value - (phyd.value + phydl.value))
          ) * 100
               ,0) < $PARAM__HIT_RATIO_TRES AND
      (get.value + con.value - (phyd.value + phydl.value)) != 0)
AND   phy.sid = phyd.sid
AND   phy.sid = phydl.sid
AND   phy.sid = phydl.sid
AND   phy.sid = get.sid
AND   phy.sid = con.sid
ORDER BY
     TRUNC(
          (1 - (phy.value - (phyd.value + phydl.value)) /
               (get.value + con.value - (phyd.value + phydl.value))
          ) * 100
               ,2)
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


echo "List of sessions with CACHE HIT RATIO < ${PARAM__HIT_RATIO_TRES}% " > $outfile
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> $outfile

cat $outfile.tmp >> $outfile


# get sql for these sessions
#
$SEEDMON/drilsql.sh $outfile.tmp $outfile.tmp.drilsql
if [ $? -gt 0 ]; then
        exit 1;
fi
cat $outfile.tmp.drilsql >> $outfile

# get wait for these sessions
#
## $SEEDMON/drilwait.sh $outfile.tmp $outfile.tmp.drilwait
## if [ $? -gt 0 ]; then
##         exit 1;
## fi
## cat $outfile.tmp.drilwait >> $outfile

dril_apps11i()
{
# get APPS 11i details for these sessions
#
$SEEDMON/drilapps11i.sh $outfile.tmp $outfile.tmp.drilapps11i
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
rm -f $outfile.tmp $outfile.tmp.drilsql $outfile.tmp.drilwait

