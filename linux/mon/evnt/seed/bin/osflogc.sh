#!/bin/ksh
#
# File:
#       osflogc.sh
# EVNT_REG:	CHK_OS_LOG SEEDMON 1.1
# <EVNT_NAME>Check Logfile Errors</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks any remote logfile for errors.  Runs via SSH 
# on the server that's being monitored
# 
# REPORT ATTRIBUTES:
# -----------------------------
# error line
# 
# 
# PARAMETER       DESCRIPTION
# --------------  ----------------------------------------------------------
# FILE_NAME       full path to logfile to check for errors
# SEARCH_STRING   separated by | (DEFAULT = ERROR|Error|error)
# IGNORE_STRING   separated by | (DEFAULT = BLANK)
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        01/14/2014      v1.1	Created
#


chkfile=$1
outfile=$2
clrfile=$3

SEARCH_STRING="$PARAM__SEARCH_STRING"
IGNORE_STRING="$PARAM__IGNORE_STRING"
FILE_NAME="$PARAM__FILE_NAME"

REMOTE_HOST="$MON__H_NAME"



if [ ! "$SEARCH_STRING" ]; then
	SEARCH_STRING="ERROR|Error|error"
fi

BASENAME_FN=`basename $FILE_NAME`
LOCAL_FILE_NAME="${SHARE_TOP}/wrk/${BASENAME_FN}-${MON__EA_ID}"
scp oracle@${REMOTE_HOST}:${FILE_NAME} ${LOCAL_FILE_NAME}
if [ $? -gt 0 ]; then
	echo "ERROR GETTING LOG FILENAME from $REMOTE_HOST !"
	echo $FILE_NAME
	exit 1
fi


$SYS_TOP/bin/logmine.sh $LOCAL_FILE_NAME "${SEARCH_STRING}" "${IGNORE_STRING}" > $chkfile

