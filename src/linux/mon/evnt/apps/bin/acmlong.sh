#!/bin/ksh
#
# File:
#       acmlong.sh
# EVNT_REG:     APPS_LONG_REQS APPSMON 1.1
# <EVNT_NAME>APPS Long Runtime Requests</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# APPS - Reports concurrent requests that ran for over X minutes
# 
# REPORT ATTRIBUTES:
# -----------------------------
# concurrent_program_name
# 
# PARAMETER       DESCRIPTION                                   EXAMPLE
# --------------  --------------------------------------------  ----------
# LONG_RATIO      < fnd_concurrent_requests.                    60
#                   actual_completion_date-actual_start_date
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        07/25/2002      Created
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__LONG_RATIO" ]; then
	echo "using default minutes parameter: 60 "
	PARAM__LONG_RATIO=60
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
SELECT DISTINCT p.concurrent_program_name
FROM fnd_concurrent_programs p
,    fnd_concurrent_programs_tl pt
,    fnd_concurrent_requests f
WHERE  TRUNC(((f.actual_completion_date-f.actual_start_date)/(1/24))*60) > $PARAM__LONG_RATIO
and    f.concurrent_program_id = p.concurrent_program_id
and    f.program_application_id = p.application_id
and    f.concurrent_program_id = pt.concurrent_program_id
and    f.program_application_id = pt.application_id
AND    pt.language = USERENV('Lang')
ORDER by p.concurrent_program_name
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

set lines 300
set trims on
set pages 60
set head on

ttit off
btit off

col runtime format 9999999    heading "Runtime|[min]"
col asd format a20            Heading "Start Time"
col acd format a20            Heading "End Time"
col cpn format a15             heading "Program"
col ucpn format a35 trunc     heading "Program Name"
--col logfile_name format a85   heading "Log File"  newline
--col argument_text format a300 heading "Arguments" newline

SELECT f.request_id
,      TRUNC(((f.actual_completion_date-f.actual_start_date)/(1/24))*60) runtime
,      f.actual_start_date       asd
,      f.actual_completion_date  acd
,      DECODE(p.concurrent_program_name,
          'ALECDC',p.concurrent_program_name||'['||f.description||']'
                  ,p.concurrent_program_name)            cpn
,      pt.user_concurrent_program_name      ucpn
,      f.phase_code
,      f.status_code
--,      f.logfile_name
--,      f.argument_text
FROM fnd_concurrent_programs p
,    fnd_concurrent_programs_tl pt
,    fnd_concurrent_requests f
WHERE  TRUNC(((f.actual_completion_date-f.actual_start_date)/(1/24))*60) > $PARAM__LONG_RATIO
and    f.concurrent_program_id = p.concurrent_program_id
and    f.program_application_id = p.application_id
and    f.concurrent_program_id = pt.concurrent_program_id
and    f.program_application_id = pt.application_id
AND    pt.language = USERENV('Lang')
ORDER by f.actual_completion_date-f.actual_start_date desc
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

