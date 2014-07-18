#!/bin/ksh
#
# File:
#       runprc.sh
# EVNT_REG:	RUNAWAY_PROC SEEDMON 1.3
# <EVNT_NAME>Runaway Session (IO)</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (hashjoin.com)
#
# Usage:
# <EVNT_DESC>
# Checks for runaway processes using v$session can drill down to APPS 
# request or APPS forms connection.
# 
# Report only sessions with high resource consumption rate
# (consistent gets, db block gets, physical reads, db block changes)
# that ran for longer than predefined threshold (see parameters)
# 
# REPORT ATTRIBUTES:
# -----------------------------
# sid
# serial#
# username
# program
# module||' '||action
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
#       VMOGILEV        12/20/2002      put decode on combination of
#                                       program, module and action
#                                       to avoid dup trigs when this
#                                       combination is NULL and diff
#                                       on PREV/CURR outputs of same
#                                       data causes trigger
#       VMOGILEV        10/22/2003      on error "cat &outfile"
#       VMOGILEV        10/23/2013      (1.3)	added SPID to report
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__RUN_THRES" ]; then
        echo "using default minutes parameter: 60 "
        PARAM__RUN_THRES=60
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
select s.sid
||','||s.serial#
||','||s.username
||','||DECODE(program||' '||
              s.module||' '||
              s.action,
          '  ','MODULE DETAILS N/A'
              ,program||' '||s.module||' '||s.action)
from 
   (select tot_value
    ,      sid
    from
	(select sum(stat.value) tot_value
        ,      s.sid
        from v\$sesstat stat 
        ,    v\$statname sname
	,    v\$session s
        where s.sid = stat.sid
		and   stat.STATISTIC# = sname.STATISTIC#
        and   sname.name IN( 'consistent gets', 'db block gets'
                           , 'physical reads' , 'db block changes')
	and   s.type <> 'BACKGROUND'
	--and   s.schemaname <> 'SYS'
        and   s.WAIT_CLASS <> 'Idle'
	and   s.status = 'ACTIVE'
        group by s.sid
        order by tot_value desc)
    where  rownum < 11)       top_ten
, v\$session    s
where top_ten.sid = s.sid
and   floor(last_call_et/60) > $PARAM__RUN_THRES
order by s.sid,s.serial#
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
alter session set nls_date_format='RRRR-DD-MON HH24:MI';
spool $outfile

set lines 256
set trims on

col sid_serial        format a12         heading "Sid,Serial"
col USERNAME          format a8 trunc    heading "User"
col MACHINE           format a10 trunc   heading "Machine"
col PROCESS           format a10         heading "PROCESS"
col spid	      format a10         heading "SPID"
col OSUSER            format a10 trunc   heading "OS-User"
col logon             format a15         heading "Login Time"
col idle              format a8          heading "Idle"
col status            format a1          heading "STS"
col lockwait          format a1          heading "L|W"
col module            format a35 trunc   heading "Module"                
                
select top_ten.tot_value
,      chr(39)||s.sid||','||s.serial#||chr(39) sid_serial
,      s.username
,      SUBSTR(s.status,1,1) status
,      s.lockwait
,      s.osuser
,      s.process
,      p.spid
,      s.machine
,      to_char(s.logon_time,'DDth HH24:MI:SS') logon
,      floor(last_call_et/60) ACTIVE_MIN
,      s.program||' '||s.module||' '||s.action  module
from 
   (select tot_value
    ,      sid
    from
	(select sum(stat.value) tot_value
        ,      s.sid
        from v\$sesstat stat 
        ,    v\$statname sname
	,    v\$session s
        where s.sid = stat.sid
		and   stat.STATISTIC# = sname.STATISTIC#
        and   sname.name IN( 'consistent gets', 'db block gets'
                           , 'physical reads' , 'db block changes')
	and   s.type <> 'BACKGROUND'
	--and   s.schemaname <> 'SYS'
        and   s.WAIT_CLASS <> 'Idle'
	and   s.status = 'ACTIVE'
        group by s.sid
        order by tot_value desc)
    where  rownum < 11)       top_ten
, v\$session    s
, v\$process    p
where top_ten.sid = s.sid
and   floor(last_call_et/60) > $PARAM__RUN_THRES
and   s.paddr = p.addr
order by 1 desc
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
rm -f $outfile.tmp.drilsql $outfile.tmp.drilwait

