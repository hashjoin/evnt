#!/bin/ksh
#
# File:
#       dglagck.sh
# EVNT_REG:	CHK_DGARD_LAG SEEDMON 1.2
# <EVNT_NAME>Data Guard Lag</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks dataguard lag
# 
# REPORT ATTRIBUTES:
# -----------------------------
# lag in minutes
# 
# PARAMETER       DESCRIPTION
# --------------  ----------------------------------------------------------
# LAG_MINUTES     Threshold for LAG in minutes
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        04-MAR-2014      v1.1	Created
#       VMOGILEV        02-APR-2014      v1.2	Added NVL on max(time) to capture recovery_stopped by user
#


chkfile=$1
outfile=$2
clrfile=$3

LAG_MINUTES="$PARAM__LAG_MINUTES"

REMOTE_HOST="$MON__H_NAME"

get_dg_status() {
echo "
export ORACLE_SID=${MON__S_NAME}
sqlplus -s '/ as sysdba'<<XXX
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
alter session set nls_date_format='YY-MON-DD HH24:MI';
set lines 300
set trims on
col MESSAGE format a100 trunc
select * from v\\\$dataguard_status order by TIMESTAMP;
set lines 80
select process, status from v\\\$managed_standby;
exit
XXX
" > /tmp/${MON__EA_ID}.run

ssh -l oracle ${REMOTE_HOST} < /tmp/${MON__EA_ID}.run 2>/tmp/${MON__EA_ID}.out
}

echo "
export ORACLE_SID=${MON__S_NAME}
sqlplus -s '/ as sysdba'<<XXX
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set time off
set timing off
set feed off
set pages 0
set trims on
set lines 132
SELECT 'LAG,'||round(nvl(((sysdate - max(timestamp))*1440),180))||','||nvl(to_char(max(timestamp),'YYYY-MON-DD HH24:MI:SS'),'RECOVERY_STOPPED')
FROM V\\\$RECOVERY_PROGRESS;
exit
XXX | grep LAG
" > /tmp/${MON__EA_ID}.run

DG_LAG=`ssh -l oracle ${REMOTE_HOST} < /tmp/${MON__EA_ID}.run 2>/tmp/${MON__EA_ID}.out`

if [ $? -gt 0 ]; then
	echo "ERROR CHECKING DG LAG!"
	echo $DG_LAG
	cat /tmp/${MON__EA_ID}.out
	exit 1
fi

if [ ! "$LAG_MINUTES" ]; then
	LAG_MINUTES=160
fi

touch $chkfile
CURR_LAG=`echo $DG_LAG | awk -F, '{print $2}'`
if [ ${CURR_LAG} -gt ${LAG_MINUTES} ]; then
	echo $DG_LAG > $chkfile
	get_dg_status > $outfile
fi

