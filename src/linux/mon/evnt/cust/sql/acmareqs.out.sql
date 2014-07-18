set lines 132
set trims on

ttit "Completed Concurrent Requests"

col request_id                    format 99999999999  heading "Req ID"
col concurrent_program_id         format 99999999999  heading "Prog ID"
col prog_name                     format a15 trunc    heading "Prog Code"
col user_name                     format a10 trunc    heading "User Name"
col user_concurrent_program_name  format a25 trunc    heading "Prog Name"
col argument_text                 format a35 trunc    heading "Arguments"
col comp_date                                         heading "Completion Date"


SELECT fcr.request_id
,      fcr.concurrent_program_id
,      fu.user_name
,      DECODE(fcp.concurrent_program_name,
          'ALECDC',fcp.concurrent_program_name||'['||fcr.description||']'
                  ,fcp.concurrent_program_name) prog_name
,      fcpt.user_concurrent_program_name
,      TO_CHAR(fcr.actual_completion_date,'MM/DD/RRRR HH24:MI') comp_date
,      fcr.argument_text
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
--AND   fcr.status_code='E'
AND   TRUNC((SYSDATE-fcr.actual_completion_date)/(1/24)) <= &1 /* look-back hours */
ORDER BY fcr.actual_completion_date
/

