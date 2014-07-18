#!/bin/ksh
#
# File:
#       dbalogc.sh
# EVNT_REG:	CHK_ALERT_LOG SEEDMON 1.6
# <EVNT_NAME>Alert Log Errors</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks database ALERT log for errors.  Runs through remote agent
# on the server that's being monitored
# 
# REPORT ATTRIBUTES:
# -----------------------------
# error line
# 
# 
# PARAMETER       DESCRIPTION
# --------------  ----------------------------------------------------------
# SEARCH_STRING   separated by | (DEFAULT = ORA-|ERROR|Corrupt|Error|error)
# IGNORE_STRING   separated by | (DEFAULT = BLANK)
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        07/25/2002      v1.1	Created
#       VMOGILEV        12/23/2013      v1.2	Converted to use SSH/SCP
#       VMOGILEV        12/23/2013      v1.3	Converted to use SSH to parse alert log file name
#       VMOGILEV        01/16/2014      v1.3	Added error output to .out file to trace error messages
#       VMOGILEV        01/29/2014      v1.5	Appended EA_ID to the logfile name
#       VMOGILEV        05/28/2014      v1.6	Added PATH and ORACLE_HOME variables
#


chkfile=$1
outfile=$2
clrfile=$3

SEARCH_STRING="$PARAM__SEARCH_STRING"
IGNORE_STRING="$PARAM__IGNORE_STRING"

REMOTE_HOST="$MON__H_NAME"

## strip last digit from SID (Example: MORA1=>MORA)
REMOTE_DB=`echo ${MON__S_NAME} | awk '{print substr($0, 1, length($0) - 1)}'`


DB_ORACLE_HOME=`ssh -l oracle ${REMOTE_HOST} "grep ${REMOTE_DB} /etc/oratab | awk -F: '{print \\$2}' | tail -1"`
if [ $? -gt 0 ]; then
        echo "ERROR GETTING ORACLE_HOME!"
        echo $DB_ORACLE_HOME
        exit 1
fi


echo "
export ORACLE_SID=${MON__S_NAME}
export ORACLE_HOME=${DB_ORACLE_HOME}
export PATH=${DB_ORACLE_HOME}/bin:\$PATH
sqlplus -s '/ as sysdba'<<XXX
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set time off
set timing off
set feed off
set pages 0
set trims on
select TO_CHAR(p.value||'/alert_'||i.instance_name||'.log')
from v\\\$parameter p
,    v\\\$instance i
where p.name = 'background_dump_dest';
exit
XXX | grep ${MON__S_NAME}
" > /tmp/${MON__EA_ID}.run

FILE_NAME=`ssh -l oracle ${REMOTE_HOST} < /tmp/${MON__EA_ID}.run 2>/tmp/${MON__EA_ID}.out`

if [ $? -gt 0 ]; then
	echo "ERROR GETTING ALERT LOG FILENAME!"
	echo $FILE_NAME
	echo "--- /tmp/${MON__EA_ID}.out ---"
	cat /tmp/${MON__EA_ID}.out
	echo "--- /tmp/${MON__EA_ID}.run ---"
	cat /tmp/${MON__EA_ID}.run
	echo "DB_ORACLE_HOME=$DB_ORACLE_HOME"
	exit 1
fi

if [ ! "$SEARCH_STRING" ]; then
	SEARCH_STRING="ORA-|ERROR|Corrupt|Error|error"
fi

BASENAME_FN=`basename $FILE_NAME`
##LOCAL_FILE_NAME="${SHARE_TOP}/wrk/${BASENAME_FN}"
LOCAL_FILE_NAME="${SHARE_TOP}/wrk/${MON__EA_ID}_${BASENAME_FN}"
scp oracle@${REMOTE_HOST}:${FILE_NAME} ${LOCAL_FILE_NAME}

$SYS_TOP/bin/logmine.sh $LOCAL_FILE_NAME $SEARCH_STRING $IGNORE_STRING > $chkfile

