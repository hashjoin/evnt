#!/bin/ksh
#
# $Header startup.sh 03-SEP-2008 1.4
#
# File:
#	startup.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	startup.sh <local|remote> <bgproc_username/bgproc_password@REPDB>
#
# Desc:
#	Starts EVNT background processes 
#
# History:
#	11-JUN-2002	VMOGILEV	(1.1) Created
#	03-APR-2003	VMOGILEV	(1.2) change bgman calls to EVNT|COLL
#	04-APR-2003	VMOGILEV	(1.3) added pid files removal
#	03-SEP-2008	VMOGILEV	(1.4) LOCAL_HOSNAME is now set in MON.env
#


if [ ! "$SHARE_TOP" ]; then
	echo "ERROR:	Environment is not set!"
	echo "Did you source MON.env?"
	exit 1;
fi

rm -f $SHARE_TOP/wrk/EVNT*.pid
rm -f $SHARE_TOP/wrk/COLL*.pid

if [ -f $shutdown_file ]; then
        rm $shutdown_file
fi

if [ "$coll_sleep_int" ]; then
        coll_sleep_int=$coll_sleep_int
else
	echo "using default sleep interval for coll subsystem = 60 sec ..."
        coll_sleep_int=60
fi

if [ "$evnt_sleep_int" ]; then
        evnt_sleep_int=$evnt_sleep_int
else
	echo "using default sleep interval for event subsystem = 30 sec ..."
        evnt_sleep_int=30
fi


usage()
{
echo "`basename $0` <local|remote> <bgproc_username/bgproc_password@REPDB>"
exit 1;
}

local_startup()
{
sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET SERVEROUTPUT ON SIZE 100000
BEGIN
   evnt_util_pkg.reset;
END;
/
commit;
exit
EOF

if [ $? -gt 0 ]; then
	echo "Error resetting event assigments!"
	exit 1;
fi


sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET SERVEROUTPUT ON SIZE 1000000
BEGIN
   coll_util_pkg.fix_coll;
END;
/
commit;
exit
EOF

if [ $? -gt 0 ]; then
	echo "Error resetting collection assigments!"
	exit 1;
fi


nohup bgman.sh COLL colllist.sh $coll_sleep_int > $SHARE_TOP/syslog/bg_coll.log 2>&1 &
nohup bgman.sh EVNT evntlistl.sh $evnt_sleep_int > $SHARE_TOP/syslog/bg_evntl.log 2>&1 &
nohup mailbg.sh > $SHARE_TOP/syslog/mailbg.sh.log 2>&1 &

# END LOCAL STARTUP
}


remote_startup()
{
## (see MON.env) LOCAL_HOSNAME=`hostname`

sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET SERVEROUTPUT ON SIZE 100000
BEGIN
   evnt_util_pkg.reset('$LOCAL_HOSNAME');
END;
/
commit;
exit
EOF

if [ $? -gt 0 ]; then
	echo "Error resetting event assigments!"
	exit 1;
fi



nohup bgman.sh EVNT evntlistr.sh $evnt_sleep_int > $SHARE_TOP/syslog/bg_evntr.log 2>&1 &

# END REMOTE STARTUP
}

if [ "$2" ]; then
	uname_passwd="$2"; export uname_passwd
else
	usage;
fi

cd $SYS_TOP/bin

echo "startup:	in $PWD ..."
	
case "$1" in
local)   local_startup ;;
remote)  remote_startup ;;
*)      usage ;;
esac


$SYS_TOP/bin/bstat

