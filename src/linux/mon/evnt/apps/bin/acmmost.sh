#!/bin/ksh
#
# File:
#       acmmost.sh
# EVNT_REG:     APPS_MOST_REQS APPSMON 1.1
# <EVNT_NAME>APPS Most Used Requests</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports most used concurrent requests, excluding pending requests.
# 
# RECOMMENDED FREQUENCY: = LOOKBACK_MIN
# 
# REPORT ATTRIBUTES:
# -----------------------------
# number of requests ran
# fnd_concurrent_requests.status_code
# fnd_concurrent_requests.concurrent_program_id
# fnd_user.user_name
# fnd_concurrent_programs.concurrent_program_name
# fnd_concurrent_programs_tl.user_concurrent_program_name
# 
# 
# PARAMETER       DESCRIPTION                                EXAMPLE
# --------------  -----------------------------------------  --------
# LOOKBACK_MIN    number of minutes to look back in          30
#                 fnd_concurrent_programs.actual_start_date
#                 DEFAULT=60
#                 
# NUM_OF_RUNS     threshold for # of requests ran during     10
#                 LOOKBACK_MIN
#                 DEFAULT=20
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        09/30/2002      Created
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__LOOKBACK_MIN" ]; then
        echo "using default parameter LOOKBACK_MIN=60 "
        PARAM__LOOKBACK_MIN=60
fi

if [ ! "$PARAM__NUM_OF_RUNS" ]; then
        echo "using default parameter NUM_OF_RUNS=20 "
        PARAM__NUM_OF_RUNS=20
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
SELECT   count(*) 
||','||fcr.status_code
||','||fcr.concurrent_program_id
||','||fu.user_name
||','||DECODE(fcp.concurrent_program_name,
          'ALECDC',fcp.concurrent_program_name||'['||fcr.description||']'
                  ,fcp.concurrent_program_name)
||','||fcpt.user_concurrent_program_name
FROM fnd_concurrent_programs_tl fcpt
,    fnd_concurrent_programs fcp
,    fnd_user fu
,    fnd_concurrent_requests fcr
WHERE fcr.concurrent_program_id = fcpt.concurrent_program_id
AND   fcr.program_application_id = fcpt.application_id
AND   fcr.concurrent_program_id = fcp.concurrent_program_id
AND   fcr.program_application_id = fcp.application_id
AND   fcr.requested_by = fu.user_id
AND   fcpt.language = USERENV('Lang')
AND   fcr.status_code != 'P'
AND   TRUNC(((SYSDATE-fcr.actual_start_date)/(1/24))*60) < $PARAM__LOOKBACK_MIN
GROUP BY
         fcr.status_code
,        fcr.concurrent_program_id
,        fu.user_name
,        DECODE(fcp.concurrent_program_name,
          'ALECDC',fcp.concurrent_program_name||'['||fcr.description||']'
                  ,fcp.concurrent_program_name)
,        fcpt.user_concurrent_program_name
HAVING COUNT(*) > $PARAM__NUM_OF_RUNS
ORDER BY count(*) desc
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

