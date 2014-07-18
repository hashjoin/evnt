#!/bin/ksh
#
# $Header trgint.sh 03/24/2003 1.1
#
# File:
#	trgint.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	trgint.sh DATA_FILE username/password@REPDB
#
# Desc:
#	Imports HOST/SID definition file into supplied repository
#
# History:
#	24-MAR-2003	VMOGILEV	Created
#

usage()
{
echo "
   Imports HOST/SID definition file into supplied repository
"
echo `basename $0` " DATA_FILE username/password@REPDB"
exit 1;
}

if [ "$1" ]; then
	DATA_FILE=$1
else
	usage;
fi

if [ "$2" ]; then
        uname_passwd="$2"; export uname_passwd
else
        usage;
fi


sqlldr $uname_passwd control=$SYS_TOP/bin/trgint.ctl data=$DATA_FILE

if [ $? -gt 0 ]; then
	echo "ERROR:	loading data!"
        exit 1;
fi

sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set serveroutput on size 1000000
BEGIN
   glob_util_pkg.target_int;
END;
/

commit;
exit
EOF

if [ $? -gt 0 ]; then
	echo "ERROR:	interfacing data!"
        exit 1;
fi

