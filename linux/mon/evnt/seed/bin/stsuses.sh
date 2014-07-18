#!/bin/ksh
#
# File:
#       stsuses.sh
# EVNT_REG:	UNAUTH_SES SEEDMON 1.1
# <EVNT_NAME>Unauthorized Sessions</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports unauthorized sessions (TOAD,SQLPLUS)
# drills down to SQL
# 
# REPORT ATTRIBUTES:
# -----------------------------
# sid
# serial#
# username
# machine
# logon_time
# 
# 
# PARAMETER   DESCRIPTION                             EXAMPLE
# ----------  --------------------------------------  -----------------------
# IN          IN clause for v$session.module          'T.O.A.D.','SQL*Plus'
#             enter 'show_all' if you want all
#             sessions to be reported
#
# NOTIN       NOT IN clause for v$session.machine     'machine1','machine2'
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        06/06/2002      Created
#       VMOGILEV        12/03/2002      Added drill to SQL
#       VMOGILEV        01/22/2003      allowed for 'show_all' filter on modules
#					filtered current USER from the list
#


chkfile=$1
outfile=$2
clrfile=$3

SHOW_ALL="'NOT'"
echo "$PARAM__IN"

if [ "$PARAM__IN" = "'show_all'" ]; then
	echo "... show all is active"
	SHOW_ALL="'ALL'"
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
select sid||','||serial#||','||username||','||machine||','||TO_CHAR(logon_time,'RRRR-MON-DD HH24:MI:SS')
from v\$session
where DECODE($SHOW_ALL,'ALL','show_all',module) in ($PARAM__IN)
--where module in ($PARAM__IN)
and   username != 'SYSTEM'
and   username != 'SYS'
and   username != USER
--
-- WARNING DO NOT REMOVE
--
-- REPLACE(machine,chr(0)) is here to
-- avoid BUG:2103768 see note# 2103768.9
--
and   REPLACE(machine,chr(0)) not in ($PARAM__NOTIN)
order by sid,serial#,username;
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

OSID_LIST=`awk 'BEGIN { FS = "," } { if ( NR == 1 ) { print $1 } if ( NR > 1 ) { print "," $1 } }' $chkfile`


sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
spool $outfile
break on report
compute sum of sess_cnt on report
set lines 132
set trims on
col username format a10
col machine format a23
col action format a35 trunc
prompt Below is a list of detected sessions
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
select count(*) sess_cnt
, status
, machine
, username
, module||' '||action action
from v\$session
where sid in ($OSID_LIST)
group by status
,        machine
,        username
,        module||' '||action;
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

# cleanup temp files
#
rm -f $outfile.tmp.drilsql

