#!/bin/ksh
#
# File:
#       prserat.sh
# EVNT_REG:     PARSE_RATIO SEEDMON 1.1
# <EVNT_NAME>Execute to Parse Ratio</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports session's Execute to Parse ratio.
# Optimal ratio is 100%
# Drills down to session's sql and details.
#
# REPORT ATTRIBUTES:
# -----------------------------
# sid
#
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# HARD_PARSE      v$sesstat.[parse count (hard)].value
#                 DEFAULT=50                              100
#
# EXEC_COUNT      v$sesstat.[execute count].value
#                 DEFAULT=500                             1000
#
# PARSE_RATIO     100 - ( [parse count (total)]*100 /
#                         [execute count] )
#                 optimal ratio should be 100%
#                 DEFAULT=80                              99
#
# APPS_TYPE       Set this parameter if APPS related      11i
#                 session details
#
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV	31-MAR-2003	Created
#

chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__HARD_PARSE" ]; then
        echo "using default hard parse value: 50 "
        HARD_PARSE=50
fi

if [ ! "$PARAM__EXEC_COUNT" ]; then
        echo "using default execute count value: 500"
        EXEC_COUNT=500
fi

if [ ! "$PARAM__PARSE_RATIO" ]; then
        echo "using default parse ratio: 80(%)"
        PARSE_RATIO=80
fi

if [ "$PARAM__APPS_TYPE" ]; then
        APPS_TYPE=$PARAM__APPS_TYPE
fi


## get trigger attributes
##
sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set lines 2000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off

SELECT
   sid
from (
select
   sid
,  max(decode(name,'execute count',value,null)) ec
,  max(decode(name,'parse count (hard)',value,null)) ph
,  max(decode(name,'parse count (total)',value,null)) pt
,  max(decode(name,'session cursor cache count',value,null)) cc
,  max(decode(name,'session cursor cache hits',value,null)) ch
from(
select s.sid, a.name, s.value
from v\$sesstat s, v\$statname a
where s.statistic# = a.statistic#
and  (a.name = 'execute count' or
      a.name like 'parse count%' or
      a.name like '%cursor%cache%'))
group by sid)
where (100-(pt*100/decode(ec,0,1,ec))) < $PARSE_RATIO
and ph > $HARD_PARSE
AND ec > $EXEC_COUNT
ORDER BY sid


spool $chkfile
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


## check if attribute file has any output
## if not exit if yes continue with 
## getting trigger output
##
if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi


## get trigger output
##
sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
set trims on
set pages 60

ttit "Execute to Parse Ratio"
col ec heading "Exec CNT"
col ph heading "Parse|Hard CNT"
col pt heading "Parse|Total CNT"
col cc heading "Cursor|Cache CNT"
col ch heading "Cursor|Cache HIT"

SELECT
   sid,
   ROUND((100-(pt*100/decode(ec,0,1,ec))),2) ratio,
    ec, ph, pt, cc, ch
from (
select
   sid
,  max(decode(name,'execute count',value,null)) ec
,  max(decode(name,'parse count (hard)',value,null)) ph
,  max(decode(name,'parse count (total)',value,null)) pt
,  max(decode(name,'session cursor cache count',value,null)) cc
,  max(decode(name,'session cursor cache hits',value,null)) ch
from(
select s.sid, a.name, s.value
from v\$sesstat s, v\$statname a
where s.statistic# = a.statistic#
and  (a.name = 'execute count' or
      a.name like 'parse count%' or
      a.name like '%cursor%cache%'))
group by sid)
where (100-(pt*100/decode(ec,0,1,ec))) < $PARSE_RATIO
and ph > $HARD_PARSE
AND ec > $EXEC_COUNT
order by ratio


spool $outfile
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


# get sql for these sessions
#
$SEEDMON/drilsql.sh $chkfile $outfile.tmp.drilsql
if [ $? -gt 0 ]; then
        exit 1;
fi
cat $outfile.tmp.drilsql >> $outfile


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
rm -f $outfile.tmp.drilsql

