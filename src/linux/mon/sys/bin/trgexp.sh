#!/bin/ksh
#
# $Header trgexp.sh 09/25/2002 1.2
#
# File:
#	trgexp.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	trgexp.sh username/password@REPDB
#
# Desc:
#	Performs export of HOST/SID definitions that
#	can be imported to another EVNT repository
#	VIA running trgint.sh with SERVER.dat created
#	by this utility.
#
# History:
#	25-SEP-2002	VMOGILEV	(1.1) Created
#	16-JUL-2003	VMOGILEV	(1.2) added sid(less) hosts
#

usage()
{
echo "
   Performs export of HOST/SID definitions that
   can be imported to another EVNT repository
   VIA running trgint.sh with SERVER.dat created
   by this utility:

"

echo `basename $0` " username/password@REPDB"
exit 1;
}

if [ "$1" ]; then
        uname_passwd="$1"; export uname_passwd
else
        usage;
fi

LOG=/tmp/$$.`basename $0`.log

sqlplus -s $uname_passwd <<EOF >$LOG
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set lines 3000
set trims on
set pages 0
set feed off

spool SERVER.dat

select h_name||',"'||h_desc||'",'||s_name||',"'||s_desc||'",'||sc_username||','||sc_password||','||sc_tns_alias
from sids s
,    hosts h
,    sid_credentials sc
where s.h_id = h.h_id
and s.s_id = sc.s_id
and lower(sc.sc_username) = 'mon'
order by h_name, s_name;

select h_name||',"'||h_desc||'",'||null||',"'||null||'",'||null||','||null||','||null
from sids s
,    hosts h
where s.h_id(+) = h.h_id
and s.s_id is null
order by h_name;

spool off
exit
EOF

if [ $? -gt 0 ]; then
	echo "ERROR:	exporting HOST/SID definition  data!"
	cat $LOG
        exit 1;
fi

cat SERVER.dat
rm -f $LOG

echo "
   Exported HOST/SID definitions into SERVER.dat
"

