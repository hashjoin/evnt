#!/bin/ksh
#
# File:
#       acmrerr.sh
# EVNT_REG:     APPS_ERR_REQS APPSMON 1.1
# <EVNT_NAME>APPS Error Requests</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks for concurrent requests that finished with ERROR
# 
# REPORT ATTRIBUTES:
# -----------------------------
# request_id
# concurrent_program_id
# user_name
# user_concurrent_program_name
# actual_completion_date
# 
# PARAMETER       DESCRIPTION                          EXAMPLE
# --------------  -----------------------------------  ---------------
# LOOKBACK_MIN    number of minutes to look back in    30
#                 FND_CONCURRENT_REQUESTS table
#                 DEFAULT=60
#
# EXCLUDE_PROG    exclude programs (optional)          'OMPREL','PROG2'
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        09/20/2002      Created
#	VMOGILEV	02/03/2003	added PARAM__EXCLUDE_PROG
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__LOOKBACK_MIN" ]; then
        echo "using default parameter: 60 "
        PARAM__LOOKBACK_MIN=60
fi

if [ ! "$PARAM__EXCLUDE_PROG" ]; then
	echo "using no exclude mode = 'x'"
	PARAM__EXCLUDE_PROG="'x'"
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
SELECT fcr.request_id
||','||fcr.concurrent_program_id
||','||fu.user_name
||','||DECODE(fcp.concurrent_program_name,
          'ALECDC',fcp.concurrent_program_name||'['||fcr.description||']'
                  ,fcp.concurrent_program_name)
||','||fcpt.user_concurrent_program_name
||','||TO_CHAR(fcr.actual_completion_date,'MM/DD/RRRR HH24:MI')
FROM fnd_concurrent_programs_tl fcpt
,    fnd_concurrent_programs fcp
,    fnd_concurrent_requests fcr
,    fnd_user fu
WHERE fcr.concurrent_program_id = fcpt.concurrent_program_id
AND   fcr.program_application_id = fcpt.application_id
AND   fcr.concurrent_program_id = fcp.concurrent_program_id
AND   fcr.program_application_id = fcp.application_id
AND   fcr.requested_by = fu.user_id
AND   fcpt.language = USERENV('Lang')
AND   fcr.status_code='E'
AND   fcp.concurrent_program_name NOT IN (${PARAM__EXCLUDE_PROG})
AND   TRUNC(((SYSDATE-fcr.actual_completion_date)/(1/24))*60) < $PARAM__LOOKBACK_MIN
ORDER BY fcr.concurrent_program_id,fu.user_name,fcr.actual_completion_date
/
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

touch $outfile

