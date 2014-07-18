SELECT fcr.request_id
||','||fcr.concurrent_program_id
||','||fu.user_name
||','||DECODE(fcp.concurrent_program_name,
          'ALECDC',fcp.concurrent_program_name||'['||fcr.description||']'
                  ,fcp.concurrent_program_name)
||','||fcpt.user_concurrent_program_name
||','||TO_CHAR(fcr.actual_completion_date,'MM/DD/RRRR HH24:MI')
||','||replace(substr(fcr.argument_text,1,255),chr(44),'''||chr(44)||''') /* strip commas */
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

