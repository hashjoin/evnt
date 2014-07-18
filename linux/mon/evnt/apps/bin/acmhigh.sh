#!/bin/ksh
#
# File:
#       acmhigh.sh
# EVNT_REG:	APPS_HIGH_REQS APPSMON 1.1
# <EVNT_NAME>APPS High Request Submission</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks for high number of concurrent requests per minute, looks back 7 days.
# 
# REPORT ATTRIBUTES:
# -----------------------------
# concurrent_program_id
# user_name
# concurrent_program_name
# user_concurrent_program_name
# number of reqs per minute
# requested_start_date ['MM/DD/RRRR HH24:MI']
# 
# PARAMETER       DESCRIPTION                                EXAMPLE
# --------------  -----------------------------------------  --------
# PERMIN_THRES    < fnd_concurrent_requests COUNT per MIN    60
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        08/29/2002      Created
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__PERMIN_THRES" ]; then
        echo "using default parameter: 60 "
        PARAM__PERMIN_THRES=60
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
SELECT fcr.concurrent_program_id
||','||fu.user_name
||','||DECODE(fcp.concurrent_program_name,
          'ALECDC',fcp.concurrent_program_name||'['||fcr.description||']'
                  ,fcp.concurrent_program_name)
||','||fcpt.user_concurrent_program_name
||','||COUNT(*)
||','||TO_CHAR(fcr.requested_start_date,'MM/DD/RRRR HH24:MI')
FROM fnd_concurrent_programs_tl fcpt
,    fnd_concurrent_programs fcp
,    fnd_concurrent_requests fcr
,    fnd_user fu
WHERE fcr.actual_start_date between
            SYSDATE-7 AND
            SYSDATE
AND   fcr.concurrent_program_id = fcpt.concurrent_program_id
AND   fcr.program_application_id = fcpt.application_id
AND   fcr.concurrent_program_id = fcp.concurrent_program_id
AND   fcr.program_application_id = fcp.application_id
AND   fcr.requested_by = fu.user_id
/* AVOID REQUESTS SCHEDULED WITH PAST DATE */
AND   fcr.requested_start_date >= fcr.request_date
AND   fcpt.language = USERENV('Lang')
GROUP BY fcr.concurrent_program_id
,        fu.user_name
,        DECODE(fcp.concurrent_program_name,
          'ALECDC',fcp.concurrent_program_name||'['||fcr.description||']'
                  ,fcp.concurrent_program_name)
,        fcpt.user_concurrent_program_name
,        TO_CHAR(fcr.requested_start_date,'MM/DD/RRRR HH24:MI')
HAVING count(*) > $PARAM__PERMIN_THRES
ORDER BY fcr.concurrent_program_id
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

