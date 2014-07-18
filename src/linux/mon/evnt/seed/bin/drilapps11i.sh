#!/bin/ksh

sesfile=$1
outfile=$2


OSID_LIST=`awk 'BEGIN { FS = "," } { if ( NR == 1 ) { print $1 } if ( NR > 1 ) { print "," $1 } }' $sesfile`

sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
spool $outfile
-- APPS related
--
clear col
clear breaks
set lines 124
set pages 100
set trims on
col sid_serial        format a12         heading "Sid,Serial"
col o_user            format a6          heading "O-User"
col os_user           format a8          heading "A-User"
col logon             format a15         heading "Login Time"
col idle              format a8          heading "Idle"
col status            format a10         heading "Status"
col lockwait          format a1          heading "L"
col apps_user         format a10         heading "- Apps -|User Name"
col form_name         format a42 trunc   heading "- Apps -|Form Name"

ttitle  "Matching Oracle APPS sessions (L = Lockwait) "

select
--   rowidtochar(n.rowid),
       chr(39)||s.sid||','||s.serial#||chr(39)                       sid_serial
,          to_char(s.logon_time,'DDth HH24:MI:SS')                     logon
,          floor(last_call_et/3600)||':'||
              floor(mod(last_call_et,3600)/60)||':'||
              mod(mod(last_call_et,3600),60)                             IDLE
,          s.username                                                    o_user
,          s.osuser                                                      os_user
,          s.status                                                      status
,          DECODE(lockwait,'','','Y')                                    lockwait
,          u.user_name                                                   apps_user
,          s.module||' '||s.action                                       form_name
from      v\$session  s
,         v\$process  p
,         fnd_logins n
,         fnd_user   u
where  s.paddr      = p.addr
and    n.pid        IS NOT NULL
and    n.serial#    IS NOT NULL
and    n.login_name IS NOT NULL -- get rid of dups
and    n.end_time   IS NULL
and    n.serial#    = p.serial#
and    n.pid        = p.pid
and    n.process_spid = p.spid
and    n.spid         = s.process    -- so we don't get hung sessions with old SID and SERIAL
and    n.user_id    = u.user_id
and    trunc(s.logon_time) = trunc(n.start_time)
and    s.sid IN ($OSID_LIST)
order by  s.sid
,         to_char(s.logon_time,'DDth - HH24:MI:SS')
/


clear col
clear breaks

set lines 104
set pages 60
set head on
set trims on

col request_id heading "Req ID"
col conc_id    format 99999999 heading "Conc ID"
col start_time format a16 heading "Start Time"
col apps_pid   format a7  heading "Request|App PID"
col aora_pid   format a7  heading "Request|Ora PID"
col mgr_pid    format a7  heading "Manager|App PID"
col mora_pid   format a7  heading "Manager|Ora PID"
col outfile_name format a29 heading "Output File"

ttitle  "All (not by SID) Running Concurrent Requests"

select /*+ ORDERED */
      req.request_id
,     prc.concurrent_process_id conc_id
,     to_char(actual_start_date,'MON-DD HH24:MI:SS') start_time
,     req.phase_code
,     req.status_code
,     req.os_process_id     apps_pid
,     req.oracle_process_id aora_pid
,     prc.os_process_id     mgr_pid
,     p.spid                mora_pid
,     '...'||substr(req.outfile_name,-25)outfile_name
from  fnd_concurrent_processes prc
,     fnd_concurrent_requests  req
,     v\$process p
where req.phase_code IN ('R','T')
and   req.controlling_manager = prc.concurrent_process_id
and   prc.oracle_process_id = p.pid(+)
order by actual_start_date
/


/*
select request_id, phase_code, status_code,
       oracle_process_id, os_process_id,
--           logfile_name
             outfile_name
from FND_CONCURRENT_REQUESTS
where phase_code IN ('R','T') 
*/
/*
select request_id, phase_code, status_code,
       oracle_process_id, os_process_id,
           logfile_name
from FND_CONCURRENT_REQUESTS
where phase_code<>'C'
and phase_code<>'P'
*/

spool off
exit
CHK

if [ $? -gt 0 ]; then
	cat $outfile.err
	rm -f $outfile.err
	exit 1;
fi

rm -f $outfile.err


