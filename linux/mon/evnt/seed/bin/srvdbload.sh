#!/bin/ksh
#
# File:
#       srvdbload.sh
# EVNT_REG:	SERVICE_LOAD SEEDMON 1.2 Y
# <EVNT_NAME>Load Monitor [SERVICE]</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (hashjoin.com)
#
# Usage:
# <EVNT_DESC>
# Reports SERVICE level disk, buffer, cpu and dbtime rates from gv$service_stats
# REQUIRES COLLECTION from gv$service_stats view .  Makes comparison
# of previous and current snapshots from gv$service_stats.
# 
#
# REPORT ATTRIBUTES:
# -----------------------------
# SNAP_ID
# DB_NAME
# INST_ID
# disk
# buffer
# cpu
# dbtime
# begin_snap_time  YYYYMMDDHH24MISS
# end_snap_time    YYYYMMDDHH24MISS
#
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  -----------
#
#          [ all of this is ignored for now -- we get everything ]
#
# DISK            threshold for number of DISK                        4000
# BUFFER          threshold for number of BUFFER                      4000
# CPU             threshold for number of CPU                         4000
# DBTIME          threshold for number of DBTIME		      4000
#
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        04/22/2014      v1.0 Created
#       VMOGILEV        07/22/2014      v1.1 Switched to using repdbload.sh
#


chkfile=$1
outfile=$2
clrfile=$3

## these are ignored for now -- we get all of it
DISK=${PARAM__DISK}
BUFFER=${PARAM__BUFFER}
CPU=${PARAM__CPU}
DBTIME=${PARAM__DBTIME}

## connection to REPDB for remote archiving of data
##
REPDB_CONNECT=${PARAM__REPDB_CONNECT}

if [ ${DISK}"x" == "x" ]; then
        DISK=1
fi

if [ ${BUFFER}"x" == "x" ]; then
        BUFFER=1
fi

if [ ${CPU}"x" == "x" ]; then
        CPU=1
fi

if [ ${DBTIME}"x" == "x" ]; then
        DBTIME=1
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
||','||service_name_hash
||','||service_name
||','||disk
||','||buffer
||','||cpu
||','||dbtime
||','||to_char(b_snap_time,'YYYYMMDDHH24MISS')
||','||to_char(e_snap_time,'YYYYMMDDHH24MISS')
from (
  select  e.sn_id, e.inst_id, 
          '${MON__S_NAME}' db_name,
          e.service_name_hash, e.service_name,
          e.disk-b.disk disk,
          e.buffer-b.buffer buffer,
          e.cpu-b.cpu cpu,
          e.dbtime-b.dbtime dbtime,
          e.snap_time e_snap_time, b.snap_time b_snap_time
    from  &&X_out_psnp b , &&X_out_csnp e
    where b.inst_id = e.inst_id 
      and b.service_name_hash = e.service_name_hash)
where dbtime >= 0 /* solves the problem with DB restart */
and disk||buffer||cpu||dbtime != 0||0||0||0 /* suppresses noise with all 0 values */
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
INTO TABLE load_monitor_service_all
APPEND
FIELDS TERMINATED BY ','
TRAILING NULLCOLS
(
   snap_id
,  db_name
,  inst_id
,  service_name_hash
,  service_name
,  disk
,  buffer
,  cpu
,  dbtime
,  start_time         \"to_date(:start_time, 'YYYYMMDDHH24MISS')\"
,  end_time           \"to_date(:end_time, 'YYYYMMDDHH24MISS')\"
,  snap_time          \"to_date(:end_time, 'YYYYMMDDHH24MISS')\"
)" > $chkfile.sqlldr.ctl

cp -p $chkfile $chkfile.dat
$SYS_TOP/bin/repdbload.sh ${REPDB_CONNECT} $chkfile.dat $chkfile.sqlldr.ctl &

