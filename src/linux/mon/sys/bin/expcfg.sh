#!/bin/ksh
#
# $Header expcfg.sh 09/25/2002 1.1
#
# File:
#	expcfg.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	expcfg.sh username/password@REPDB
#
# Desc:
#	Export (EXP) EVNT repository tables into $SHARE_TOP/exp/
#	Collected data tables are NOT exported only collection 
#	setup tables.
#
# History:
#	25-SEP-2002	VMOGILEV	Created
#

usage()
{
echo "`basename $0` username/password@REPDB"
exit 1;
}

if [ "$1" ]; then
        uname_passwd="$1"; export uname_passwd
else
        usage;
fi


logfile="$SHARE_TOP/exp/expcfg"
tab_list=$logfile.all

rm $logfile*

sqlplus -s $uname_passwd <<EOF
set feed off
set trims on
set head off
select table_name
from user_tables
where table_name not like 'COLL_PULL__%'
and   table_name not like 'EVENT_TRIGGER%'

spool $tab_list
/
spool off

exit
EOF

for i in `cat $tab_list`
do
	TABLE_NAME=$i
	exp $uname_passwd file=${tab_list}.${TABLE_NAME}.dmp log=${tab_list}.${TABLE_NAME}.log tables=$TABLE_NAME
done
	

