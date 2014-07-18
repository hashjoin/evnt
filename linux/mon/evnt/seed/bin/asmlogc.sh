#!/bin/ksh
#
# File:
#       asmlogc.sh
# EVNT_REG:	CHK_ASM_LOG SEEDMON 1.1
# <EVNT_NAME>ASM Log Errors</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks ASM ALERT log for errors.
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
#       VMOGILEV        01/01/2014      v1.0	Created
#       VMOGILEV        05/28/2014      v1.1	Added PATH variable
#


chkfile=$1
outfile=$2
clrfile=$3

SEARCH_STRING="$PARAM__SEARCH_STRING"
IGNORE_STRING="$PARAM__IGNORE_STRING"

REMOTE_HOST="$MON__H_NAME"

ASMID=`ssh -l oracle ${REMOTE_HOST} "ps -ef | grep pmon | grep ASM | grep -v grep | awk '{print \\$NF}' | sed 's/asm_pmon_//g'"`
if [ $? -gt 0 ]; then
	echo "ERROR GETTING ASMID!"
	echo $ASMID
	exit 1
fi

if [ ${ASMID}"x" == "x" ]; then
	echo "ASM is not running, exiting ..."
	echo "ASM_DOWN" > $chkfile
	exit 0
fi

ASM_ORACLE_HOME=`ssh -l oracle ${REMOTE_HOST} "grep ${ASMID} /etc/oratab | awk -F: '{print \\$2}'"`
if [ $? -gt 0 ]; then
	echo "ERROR GETTING ASM ORACLE_HOME!"
	echo $ASM_ORACLE_HOME
	exit 1
fi



echo "
export ORACLE_SID=${ASMID}
export ORACLE_HOME=${ASM_ORACLE_HOME}
export PATH=${ASM_ORACLE_HOME}/bin:\$PATH
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
XXX | grep ${ASMID}
" > /tmp/${MON__EA_ID}.run

FILE_NAME=`ssh -l oracle ${REMOTE_HOST} < /tmp/${MON__EA_ID}.run 2>/tmp/${MON__EA_ID}.out`

if [ $? -gt 0 ]; then
	echo "ERROR GETTING ALERT LOG FILENAME!"
	echo $FILE_NAME
	cat /tmp/${MON__EA_ID}.out
	exit 1
fi

if [ ! "$SEARCH_STRING" ]; then
	SEARCH_STRING="ORA-|ERROR|Corrupt|Error|error"
fi

BASENAME_FN=`basename $FILE_NAME`
LOCAL_FILE_NAME="${SHARE_TOP}/wrk/${MON__EA_ID}_${BASENAME_FN}"
scp oracle@${REMOTE_HOST}:${FILE_NAME} ${LOCAL_FILE_NAME}

$SYS_TOP/bin/logmine.sh $LOCAL_FILE_NAME $SEARCH_STRING $IGNORE_STRING > $chkfile

