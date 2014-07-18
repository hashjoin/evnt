#!/bin/ksh
#
# File:
#       acmpend.sh
# EVNT_REG:     APPS_PEND_REQS APPSMON 1.1
# <EVNT_NAME>APPS Many Pending Requests</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# APPS - Reports high number of pending concurrent requests per queue
# if threshold exceeds the ratio of maximum requests per queue.
# Small queues can be excluded from check by using EXCLUDE_QUEUE:
# 
# REPORT ATTRIBUTES:
# -----------------------------
# number of pending requests
# concurrent_queue_name
# queue_description
# max_processes
# 
# 
# PARAMETER       DESCRIPTION                                   EXAMPLE
# --------------  --------------------------------------------  ------------------
# PEND_RATIO      < fnd_concurrent_worker_requests COUNT        2
#                 per QUEUE
# EXCLUDE_QUEUE   NOT IN fnd_concurrent_worker_requests.        'FNDCRM','INVMGR'
#                 concurrent_queue_name           
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        07/24/2002      Created
#       VMOGILEV        02/07/2003      fixed attributes missing COUNT(*)
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__PEND_RATIO" ]; then
	echo "Missing Pending Ratio parameter: \$PARAM__PEND_RATIO "
	exit 1
fi

if [ ! "$PARAM__EXCLUDE_QUEUE" ]; then
        PARAM__EXCLUDE_QUEUE="'x'"
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
col pending noprint
spool $chkfile
SELECT COUNT(*)
||','||concurrent_queue_name
||','||queue_description
||','||max_processes
FROM fnd_concurrent_worker_requests
WHERE hold_flag != 'Y'
AND phase_code = 'P'
AND requested_start_date <= SYSDATE
AND concurrent_queue_name NOT IN ($PARAM__EXCLUDE_QUEUE)
GROUP BY
       concurrent_queue_name,
       queue_description,
       queue_application_id,
       max_processes
HAVING
       COUNT(*) / DECODE(max_processes,0,1,max_processes) >= $PARAM__PEND_RATIO
/
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
alter session set nls_date_format='RRRR-DD-MON HH24:MI';
spool $outfile

set lines 100
col pendp format 9999 heading "Pend|Req"
col maxp  format 9999 heading "Max|Req"
col qname format a25  heading "Queue Name"
col qdesc format a45  heading "Queue Desc"
SELECT 
   COUNT(*) pendp
,  max_processes maxp
,  concurrent_queue_name qname
,  queue_description     qdesc
FROM  fnd_concurrent_worker_requests
WHERE hold_flag != 'Y'
AND   phase_code = 'P'
AND   requested_start_date <= SYSDATE
AND   concurrent_queue_name NOT IN ($PARAM__EXCLUDE_QUEUE)
GROUP BY
       concurrent_queue_name,
       queue_description,
       queue_application_id,
       max_processes
HAVING
       COUNT(*) / DECODE(max_processes,0,1,max_processes) >= $PARAM__PEND_RATIO
/


set lines 132
col qname        format a15 trunc   heading "Queue Name"
col request_id   format 99999999999 heading "Request ID"
col request_date format a18         heading "Req. Date"
col user_name    format a15 trunc   heading "Req. By"
col psname       format a17         heading "Program"
col plname       format a35 trunc   heading "Program Desc"

SELECT
   req.concurrent_queue_name qname
,  req.request_id
,  req.request_date
,  usr.user_name
,  req.concurrent_program_name      psname
,  req.user_concurrent_program_name plname
FROM  fnd_concurrent_worker_requests req
,     fnd_user usr
,     (select COUNT(*)
       ,      concurrent_queue_name
       ,      queue_application_id
       FROM   fnd_concurrent_worker_requests
       WHERE  hold_flag != 'Y'
       AND    phase_code = 'P'
       AND    requested_start_date <= SYSDATE
       AND    concurrent_queue_name NOT IN ($PARAM__EXCLUDE_QUEUE)
       GROUP BY
              concurrent_queue_name
       ,      queue_application_id
       ,      max_processes
       HAVING 
              COUNT(*) / DECODE(max_processes,0,1,max_processes) >= $PARAM__PEND_RATIO ) overl
WHERE req.hold_flag != 'Y'
AND   req.phase_code = 'P'
AND   req.requested_start_date <= SYSDATE
AND   req.requested_by = usr.user_id
AND   req.concurrent_queue_name = overl.concurrent_queue_name
AND   req.queue_application_id = overl.queue_application_id
/
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

