#!/bin/ksh
#
#	10-21-2003	VMOGILEV	(1.2) fixed "latch free" wait
#					based on BUG# 904088 note# 176200.1
#					adding "+0" on the txt.hash_value join
#	11-04-2013	VMOGILEV	(1.3) added decode to get the PREV sql
#	11-19-2013	VMOGILEV	(1.4) added SQL_ID, PREV_SQL_ID and CLIENT_INFO
#	JUL-31-2014	VMOGILEV	(1.5) added CLIENT_IDENTIFIER
CLIENT_IDENTIFIER

sesfile=$1
outfile=$2


OSID_LIST=`awk 'BEGIN { FS = "," } { if ( NR == 1 ) { print $1 } if ( NR > 1 ) { print "," $1 } }' $sesfile`

sqlplus -s $MON__CONNECT_STRING <<CHK >/dev/null
WHENEVER SQLERROR EXIT FAILURE
spool $outfile
prompt Last SQL executed by these sessions:
prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

clear col
clear breaks
set lines 80
set trims on
set pages 9000
col sql_text format a70 word_wrapped
col sid format a10 noprint new_value n_sid
col serial format a10 noprint new_value n_serial
col username format a20 noprint new_value n_username
col machine format a20 noprint new_value n_machine
col osuser format a20 noprint new_value n_osuser
col process format a20 noprint new_value n_process
col action format a45 noprint new_value n_action
col SQL_ID format a13 noprint new_value n_SQL_ID
col PREV_SQL_ID format a13 noprint new_value n_PREV_SQL_ID
col CLIENT_INFO format a64 noprint new_value n_CLIENT_INFO
col CLIENT_IDENTIFIER format a64 noprint new_value n_CLIENT_IDENTIFIER

break on sid on serial on username on process on machine on action skip page

ttitle -
       "Sid ............... : "  n_sid -
      skip 1 -
       "Serial ............ : "  n_serial -
      skip 1 -
       "Username .......... : "  n_username -
      skip 1 -
       "Displayed SQL Id .. : "  n_SQL_ID -
      skip 1 -
       "Prev SQL Id ....... : "  n_PREV_SQL_ID -
      skip 1 -
       "Client Info ....... : "  n_CLIENT_INFO -
      skip 1 -
       "Client Id ......... : "  n_CLIENT_IDENTIFIER -
      skip 1 -
       "Machine ........... : "  n_machine -
      skip 1 -
       "OSuser ............ : "  n_osuser -
      skip 1 -
       "Process ........... : "  n_process -
      skip 1 -
       "Action ............ : "  n_action -

select /*+ ORDERED */
   sid,serial# serial,username,machine,osuser,process,module||' '||action action,sql_text,
   nvl(txt.SQL_ID,'null') SQL_ID,
   nvl(ses.PREV_SQL_ID,'null') PREV_SQL_ID,
   nvl(ses.CLIENT_INFO,'null') CLIENT_INFO,
   nvl(ses.CLIENT_IDENTIFIER,'null') CLIENT_IDENTIFIER
from v\$session ses, v\$sqltext txt
--from v\$session ses, v\$sqltext_with_newlines txt
where txt.address(+) = decode(ses.sql_address,'00',ses.PREV_SQL_ADDR,ses.sql_address)
and   txt.hash_value(+)+0 = decode(ses.sql_hash_value,0,ses.PREV_HASH_VALUE,ses.sql_hash_value)
and   ses.sid IN ($OSID_LIST)
order by sid,piece
/
spool off
exit
CHK

if [ $? -gt 0 ]; then
	exit 1;
fi

