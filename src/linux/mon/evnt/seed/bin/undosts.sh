#!/bin/ksh
#
# File:
#       undosts.sh
# EVNT_REG:	UNDO_SIZE SEEDMON 1.4
# <EVNT_NAME>High Undo Usage</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks for high UNDO (rbs) usage by comparing current size of
# UNDO per transaction with the INITIAL size of TRX's RBS.
#
# INITIAL size is calculated by multiplying 
#         INTIAL_EXTENT*MIN_EXTENTS of rbs
#
#
# REPORT ATTRIBUTES:
# -----------------------------
# sid
# serial#
# username
# status
# machine
# process
# osuser
# terminal
# lockwait
# program||' '||module||' '||action
# start_time
# segment_name
# init_rbs_KB
# curr_trx_KB
# decoded_trx_type
# 
# PARAMETER       DESCRIPTION                            EXAMPLE
# --------------  -------------------------------------  ---------------
# USED_KB         Used size in KB                        30720
#                 DEFAULT=30720
# 
# DB_BLOCK_SIZE   db_block_size of UNDO ts               16384
#                 DEFAULT=8192
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
#       VMOGILEV        08-SEP-2004      (1.1) Created
#       VMOGILEV        10-SEP-2004      (1.2) moved RBS stats to the end
#       VMOGILEV        10-NOV-2008      (1.3) SR:3413 - replaced lookup of DB_BLOCK_SIZE with a parameter
#       VMOGILEV        30-JAN-2014      (1.4) Switched to USED_KB (used OVER_INITIAL originally)
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__EXCLUDE_LIST" ]; then
	PARAM__EXCLUDE_LIST="'x'"
fi

if [ ! "$PARAM__OVER_INIT" ]; then
	echo "using default over initial => 2";
	PARAM__OVER_INIT=2;
fi

if [ ! "$PARAM__USED_KB" ]; then
	echo "using default USED KB = 30720";
	PARAM__USED_KB=30720;
fi


if [ ! "$PARAM__DB_BLOCK_SIZE" ]; then
	echo "using default DB_BLOCK_SIZE=8192";
        DB_BLOCK_SIZE=8192;
else
	DB_BLOCK_SIZE=$PARAM__DB_BLOCK_SIZE;
fi


if [ "$PARAM__APPS_TYPE" ]; then
        APPS_TYPE=$PARAM__APPS_TYPE
fi


sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set lines 1000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $chkfile
select
       s.sid
||','||s.serial#
||','||s.username
||','||s.status
||','||s.machine
||','||s.process
||','||s.osuser
||','||s.terminal
||','||NVL(s.lockwait,'N')
||','||DECODE(s.program||' '||
           s.module||' '||
           s.action,
          '  ','MODULE DETAILS N/A'
              ,s.program||' '||s.module||' '||s.action)
||','||t.start_time
||','||r.segment_name
||','||(r.initial_extent*r.min_extents)/1024
||','||(t.used_ublk*${DB_BLOCK_SIZE})/1024
||','||decode(t.space, 'YES', 'SPACE TX',
      decode(t.recursive, 'YES', 'RECURSIVE TX',
         decode(t.noundo, 'YES', 'NO UNDO TX', t.status)
       ))
from v\$transaction t
,    dba_rollback_segs r
,    v\$session s
where t.xidusn = r.segment_id
  and t.ses_addr = s.saddr
  and (t.used_ublk*${DB_BLOCK_SIZE})/1024 >= ${PARAM__USED_KB}
  and r.segment_name NOT IN ($PARAM__EXCLUDE_LIST)
  order by sid;
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
set feed on
set trims on
set lines 98
set pages 80

ttit "Transactions with UNDO usage higher then the INIT size of RBS"

col sid_serial  format a10              heading "S,SER"
col user_stat   format a13 trunc        heading "User[sts]"
--col os_proc   format a20 word wrap    heading "Machine|[OSProc.OSUser@TERM]"
col lockwait    format a1               heading "L|O|C|K| |W|A|I|T"
col terminal    format a8
--col module    format a35              heading "Module"
col segment_name        format a13      heading "RBS-Name"
col init_rbs_kb                         heading "RBS|Init KB"
col curr_trx_kb                         heading "TRX|Curr KB"
col trx_status          format a12      heading "TRX-Status"

select
   s.sid||','||s.serial# sid_serial
,  s.username||'['||substr(s.status,1,3)||']' user_stat
--,  s.machine||'['||s.process||'.'||s.osuser||'@'||s.terminal||']' os_proc
,  s.lockwait
/*,  DECODE(s.program||' '||
           s.module||' '||
           s.action,
          '  ','MODULE DETAILS N/A'
              ,s.program||' '||s.module||' '||s.action) module */
,  t.start_time
,  r.segment_name
,  (r.initial_extent*r.min_extents)/1024 init_rbs_kb
,  (t.used_ublk*${DB_BLOCK_SIZE})/1024 curr_trx_kb
,  decode(t.space, 'YES', 'SPACE TX',
      decode(t.recursive, 'YES', 'RECURSIVE TX',
         decode(t.noundo, 'YES', 'NO UNDO TX', t.status)
       )) trx_status
from v\$transaction t
,    dba_rollback_segs r
,    v\$session s
where t.xidusn = r.segment_id
  and t.ses_addr = s.saddr
  and (t.used_ublk*${DB_BLOCK_SIZE})/1024 >= ${PARAM__USED_KB}
--  and (t.used_ublk*${DB_BLOCK_SIZE})/
--      (r.initial_extent*r.min_extents)
--      >= $PARAM__OVER_INIT
  and r.segment_name NOT IN ($PARAM__EXCLUDE_LIST)
  order by sid;

--@$EVNT_TOP/seed/sql/s_rbs.sql
--@$EVNT_TOP/seed/sql/c_user_rbs.sql
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
echo "##########################################################################" >> $outfile
echo "#######   List below includes only session that use relevant RBS   #######" >> $outfile
echo "##########################################################################" >> $outfile
echo " " >> $outfile
$SEEDMON/drilsql.sh $chkfile $outfile.tmp.drilsql
if [ $? -gt 0 ]; then
	cat $outfile.tmp.drilsql
        exit 1;
fi
cat $outfile.tmp.drilsql >> $outfile

dril_apps11i()
{
echo " " >> $outfile
# get APPS 11i details for these sessions
#
$SEEDMON/drilapps11i.sh $chkfile $outfile.tmp.drilapps11i
if [ $? -gt 0 ]; then
	cat $outfile.tmp.drilapps11i
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

## get rbs stats
##sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
##WHENEVER SQLERROR EXIT FAILURE
##spool $outfile.rbs
##set feed on
##@$EVNT_TOP/seed/sql/s_rbs.sql
##--@$EVNT_TOP/seed/sql/c_user_rbs.sql
##spool off
##exit
##CHK

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

## append rbs output
cat $outfile.rbs >> $outfile

# cleanup temp files
#
rm -f $outfile.tmp.drilsql $outfile.rbs


