#!/bin/ksh
#
# File:
#       killfs.sh
# EVNT_REG:	KILL_FS_SESS CUSTMON 1.0
# <EVNT_NAME>Kills Ruaway Long Ops Sessions with FTS</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (hashjoin.com)
#
# <EVNT_DESC>
#
#
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  --------
# RUN_THRES       < v$session.last_call_et (in minutes)               60
#
# APPS_TYPE       Set this parameter if APPS related session details  11i
#                 are nessesary.  Allowable values are - "11i"
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        09/10/2002      Created

chkfile=$1
outfile=$2
clrfile=$3

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
select lo.sid
||','||lo.serial#
||','||lo.sql_id
||','||lo.sql_hash_value
||','||s.username
||','||s.machine
||','||s.service_name
||','||s.last_call_et
from v\$session_longops lo
,    v\$session s
where lo.target='SINGLES_OWNER.MATCH_SUMMARIES'
and lo.opname='Table Scan'
and lo.sid=s.sid
and lo.serial#=s.serial#
and s.last_call_et > 30;
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
alter session set nls_date_format='RRRR-DD-MON HH24:MI';
col x format a132
col z format a132
set lines 132
set trims on


set pages 0
set head off
spool $outfile.run
select 'prompt '||s.username||': '||lo.sql_id||':'||lo.sql_hash_value||' '||s.machine||':'||s.service_name||' LCET:'||s.last_call_et
,      'alter system kill session '||chr(39)||s.sid||','||s.serial#||chr(39)||';' x
from v\$session_longops lo
,    v\$session s
where lo.target='SINGLES_OWNER.MATCH_SUMMARIES'
and lo.opname='Table Scan'
and lo.sid=s.sid
and lo.serial#=s.serial#
and s.last_call_et > 30;
spool off

spool $outfile
set echo on
@$outfile.run
spool off

exit
CHK

## check for errors
##
if [ $? -gt 0 ]; then
        cat $outfile.err
	rm $outfile.run
        rm $outfile.err
        exit 1;
fi

## if I got here remove error chk file
##
rm $outfile.err
rm $outfile.run


