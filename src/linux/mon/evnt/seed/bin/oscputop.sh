#!/bin/ksh
#
# File:
#       oscputop.sh
# EVNT_REG:	OS_CPU_CHECK SEEDMON 1.3
# <EVNT_NAME>Os CPU Check</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks OS Cpu utilization
# 
# REPORT ATTRIBUTES:
# -----------------------------
# MACHINE
# SQL_ID
# SQL_HASH_VALUE
# SPID
# 
# 
# PARAMETER       DESCRIPTION                                 EXAMPLE
# --------------  ------------------------------------------  --------
# CPU_IDLE        Idle % Threshold - if less than -- trigger  75
#			[default=75]
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        02/26/2014      v1.0	Created
#       VMOGILEV        03/04/2014      v1.1	Added SPID to chkfile
#       VMOGILEV        03/04/2014      v1.2	Added substr to limit output file to 255 chars long
#       VMOGILEV        04/09/2014      v1.3	Increased pages to 1000
#


chkfile=$1
outfile=$2
clrfile=$3

REMOTE_HOST="$MON__H_NAME"
SHORT_HOST=${REMOTE_HOST%%.*}
CPU_IDLE=${PARAM__CPU_IDLE}

if [ ${CPU_IDLE}"x" == "x" ]; then
	CPU_IDLE=75
fi


get_full_report(){
echo "---------------------------------------"
##ssh -l oracle ${REMOTE_HOST} "/usr/bin/vmstat 1 10 | awk -v hst=${REMOTE_HOST} '{ printf(\"%s[%s]: %s\\n\",hst,strftime(\"%Y%m%d-%H:%M:%S\"),\$0) }'" 
ssh -l oracle ${REMOTE_HOST} "ps -eo pcpu,pid,user,args | sort -k 1 -r -n | head -50" > $outfile.pids
cat $outfile.pids | awk '{printf("%s\n",substr($0,1,255))}'

PID_LIST=`cat $outfile.pids | awk '{ pctcpu=$1; if (pctcpu > 5) { if (NR==1) {printf("%s",$2)} if (NR > 1) {printf(",%s",$2)} } }'`

sqlplus -s $MON__CONNECT_STRING <<CHK >/dev/null
WHENEVER SQLERROR EXIT FAILURE

spool $outfile.sql
set head on
set pages 1000

set lines 300
set trims on
set tab off
col sid format 9999
col serial# format 999999
col username format a27
col machine format a45
col osuser format a14 trunc
col maction format a32 trunc
col spid format a10
col process format a10
set feed off

select s.sid,s.serial#,nvl(s.username,'null') username,
       s.status,s.osuser,s.machine,s.process,
       to_char(s.logon_time,'DDth HH24:MI:SS') logon,
       floor(s.last_call_et/60) last_call,
       nvl(s.SQL_ID,'null') SQL_ID,
       nvl(s.SQL_HASH_VALUE,-1) SQL_HASH_VALUE,
       nvl(s.PREV_SQL_ID,'null') PREV_SQL_ID,
       s.PREV_HASH_VALUE,
       p.spid, s.module||' '||s.action maction
from v\$session s
,    v\$process p
--where (s.process in (${PID_LIST}) OR
where p.spid in (${PID_LIST})
and   s.paddr = p.addr
order by s.sid;

spool off
exit
CHK

if [ $? -gt 0 ]; then
	echo $PID_LIST
fi

cat $outfile.sql
tail -n+4 $outfile.sql | grep -v "^$" | awk '{ printf("%s,%s,%s,%s\n",$6,$11,$12,$15) }' > $chkfile
rm -f $outfile.sql
rm -f $outfile.pids


}


ssh -l oracle ${REMOTE_HOST} "/usr/bin/vmstat 1 10 | awk -v hst=${REMOTE_HOST} '{ printf(\"%s[%s]: %s\\n\",hst,strftime(\"%Y%m%d-%H:%M:%S\"),\$0) }'" > $outfile
if [ $? -gt 0 ]; then
	echo "failed to ssh to host: ${REMOTE_HOST}"
	exit 1;
fi

touch $chkfile
tail -n+4 $outfile | awk -v lthres=$CPU_IDLE '{ idle=$16; if (idle < lthres) { printf("%s,%s\n",$1,$16) } }' > $chkfile

if [ `cat $chkfile | wc -l` -gt 0 ]; then
	get_full_report >> $outfile
fi

