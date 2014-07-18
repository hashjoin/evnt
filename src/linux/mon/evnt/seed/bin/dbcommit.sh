#!/bin/ksh
#
# File:
#       dbevnth.sh
# EVNT_REG:	DB_COMMIT SEEDMON 1.1 Y
# <EVNT_NAME>High Commit Rate</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (hashjoin.com)
#
# Usage:
# <EVNT_DESC>
# Reports database commit, rollback and logon rates from gv$sysstat
# REQUIRES COLLECTION from gv$sysstat view .  Makes comparison
# of previous and current snapshots from gv$sysstat.
# 
#
# REPORT ATTRIBUTES:
# -----------------------------
# SNAP_ID
# DB_NAME
# INST_ID
# USER_COMMITS
# USER_ROLLBACKS
# LOGONS_CUMULATIVE
# begin_snap_time  YYYYMMDDHH24MISS
# end_snap_time    YYYYMMDDHH24MISS
#
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  -----------
# COMMITS         threshold for number of COMMITS in snap period      100000
# ROLL_PCT        threshold for PCT of rollbacks vs commits           80
# LOGONS          threshold for number of LOGONS_CUMULATIVE           4000
#
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        03/18/2014      v1.0 Created
#       VMOGILEV        03/21/2014      v1.1 Added push to remote reporting server via sqlldr
#


chkfile=$1
outfile=$2
clrfile=$3

COMMITS=${PARAM__COMMITS}
ROLL_PCT=${PARAM__ROLL_PCT}
LOGONS=${PARAM__LOGONS}
REPDB_CONNECT=${PARAM__REPDB_CONNECT}

if [ ${COMMITS}"x" == "x" ]; then
        COMMITS=100000
fi

if [ ${ROLL_PCT}"x" == "x" ]; then
        ROLL_PCT=80
fi

if [ ${LOGONS}"x" == "x" ]; then
        LOGONS=4000
fi

if [ "$CA_ID" ]; then
	echo "CA_ID=${CA_ID}"
else
	echo "CA_ID is not set, exiting ..."
	exit 1;
fi

if [ "$PARAM__cp_code" ]; then
	COLL_CODE="$PARAM__cp_code"
else
	echo "PARAM__cp_code is not set, exiting ..."
	exit 1;
fi


sqlplus -s $uname_passwd <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
set lines 2000

--
-- call collection parser
-- to get curr/prev table names
--
@$EVNT_TOP/seed/sql/getsnp.sql $COLL_CODE $MON__S_ID $CA_ID

set verify off

spool $chkfile

SELECT sn_id
||','||db_name
||','||INST_ID
||','||USER_COMMITS
||','||USER_ROLLBACKS
||','||LOGONS_CUMULATIVE
||','||to_char(b_snap_time,'YYYYMMDDHH24MISS')
||','||to_char(e_snap_time,'YYYYMMDDHH24MISS')
from (
  select  e.sn_id, e.inst_id,
          '${MON__S_NAME}' db_name,
          e.user_commits-b.user_commits user_commits,
          e.user_rollbacks-b.user_rollbacks user_rollbacks,
          e.logons_cumulative-b.logons_cumulative logons_cumulative,
          e.snap_time e_snap_time, b.snap_time b_snap_time
    from  &&X_out_psnp b , &&X_out_csnp e
    where b.inst_id = e.inst_id )
where USER_COMMITS >= 0 /* solves the problem with DB restart */
order by e_snap_time,INST_ID;

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


if [ ${REPDB_CONNECT}"x" == "x" ]; then
	exit;
fi

echo "
LOAD DATA
INTO TABLE crl_monitor_all
APPEND
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(
   snap_id
,  db_name
,  inst_id
,  user_commits
,  user_rollbacks
,  logons_cumulative
,  start_time         \"to_date(:start_time, 'YYYYMMDDHH24MISS')\"
,  end_time           \"to_date(:end_time, 'YYYYMMDDHH24MISS')\"
,  snap_time          \"to_date(:end_time, 'YYYYMMDDHH24MISS')\"
)" > $chkfile.sqlldr.ctl

sqlldr ${REPDB_CONNECT} \
    data=$chkfile \
    control=$chkfile.sqlldr.ctl \
    log=$chkfile.sqlldr.log \
    discard=$chkfile.sqlldr.bad

## check for errors
##
if [ $? -gt 0 ]; then
	cat $chkfile.sqlldr.bad
	cat $chkfile.sqlldr.log
	rm -f $chkfile.sqlldr.ctl 
	rm -f $chkfile.sqlldr.bad
	rm -f $chkfile.sqlldr.log
	exit 1;
fi

rm -f $chkfile.sqlldr.ctl 
rm -f $chkfile.sqlldr.bad
rm -f $chkfile.sqlldr.log

