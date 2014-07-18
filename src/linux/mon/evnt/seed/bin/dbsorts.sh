#!/bin/ksh
#
# File:
#	dbsorts.sh
# EVNT_REG:	SORT_SIZE SEEDMON 1.3
# <EVNT_NAME>High Sort Usage</EVNT_NAME>
#
# Author:
#	Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks session with sorts higher then predefined threshold
# If triggered gives detailed report of sessions and their sorts
# 
# REPORT ATTRIBUTES:
# -----------------------------
# sid
# serial#
# username
# logon_time
# machine
# program||' '||module||' '||action
# status
# tablespace
# contents
# extents
# sort size in KB
# 
# 
# PARAMETER       DESCRIPTION                            EXAMPLE
# --------------  -------------------------------------  ---------------
# SORT_KB         sort size threshold in Kbytes          51200
#                 DEFAULT=102400 (100 mb)
# 
# APPS_TYPE       Set this parameter if APPS related     11i
#                 session details  
# </EVNT_DESC>
#	
#
# History:
#	VMOGILEV	12/02/2002	Created
#	VMOGILEV	12/06/2002	changed chk sql to do NVL on program column
#					since it was causing identical triggers
#					to refire due to middle attribute being NULL:
#   OLD: 93,6910,APPS,DEC-05 18:14,AIND\ACLIU9 ,KILLED,TEMP,TEMPORARY,313,320512
#   NEW: 93,6910,APPS,DEC-05 18:14,AIND\ACLIU9 ,,KILLED,TEMP,TEMPORARY,313,320512
#					this is because of the way evnt_util_pkg
#					concats the attributes
#
#	VMOGILEV	12/30/2002	put NVL on machine for same reason as above
#	VMOGILEV	02/20/2003	added program||' '||s.module||' '||s.action
#	VMOGILEV	08/29/2013	added CASE to v$parameter filter to avoid ORA-01722
#
#					
#

chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__SORT_KB" ]; then
        echo "using default ort KB usage parameter: 102400 (100mb) "
        PARAM__SORT_KB=102400
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
       s.sid
||','||s.serial#
||','||s.username
||','||TO_CHAR(s.logon_time,'MON-DD HH24:MI')
||','||NVL(s.machine,'UNKNOWN MACHINE')
||','||DECODE(s.program||' '||
              s.module||' '||
              s.action,
          '  ','MODULE DETAILS N/A'
              ,s.program||' '||s.module||' '||s.action)
||','||s.status
||','||u.tablespace
||','||u.contents
||','||u.extents
||','||case p.type when 3 then (u.blocks*p.value/1024) end KB
FROM v\$session s
,    v\$sort_usage u
,    v\$parameter p
WHERE s.saddr=u.session_addr
AND   p.name='db_block_size'
AND   case p.type when 3 then (u.blocks*p.value/1024) end >= $PARAM__SORT_KB
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
@$EVNT_TOP/seed/sql/s_db_sorts.sql
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

