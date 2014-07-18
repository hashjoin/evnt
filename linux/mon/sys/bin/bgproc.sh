#!/bin/ksh
#
# $Header bgproc.sh 04/04/2003 1.4
#
# File:
#	bgproc.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	bgproc.sh assigment_id assigment_type
#
# Desc:
#	Event subprocess handler
#
# History:
#	26-JUL-2002	VMOGILEV	(1.1) Created
#	03-APR-2003	VMOGILEV	(1.2) added set_status/update_status
#	04-APR-2003	VMOGILEV	(1.3) enabled pid files
#	04-APR-2003	VMOGILEV	(1.4) enabled trace files
# 

BASENAME=`basename $0`
HOSTNAME=`hostname`

usage()
{
echo "
$BASENAME assigment_id EVNT|COLL
"
exit 1;
}

if [ $# -ne 2 ]; then
	echo "ERROR:	Invalid input parameters!"
	usage;
fi


assigment_id=$1
atype=$2

if [ "$atype" = "COLL" ]; then
	ascript=collproc.sh
elif [ "$atype" = "EVNT" ]; then
	ascript=evntproc.sh
else
	echo "ERROR:	Invalid assignment type!"
	usage;
fi

pidfile=$SHARE_TOP/wrk/${atype}.${assigment_id}.${$}.pid
trcfile=$SHARE_TOP/wrk/${atype}.${assigment_id}.trc
trcall=$SHARE_TOP/wrk/${atype}.all.trc
logfile=$SHARE_TOP/syslog/${ascript}.${assigment_id}.log
mailfile=$logfile.mail
cntfile=$logfile.err_cnt



update_status() {
STATUS="$1"
sqlplus -s $uname_passwd <<EOF > $logfile.ss
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
BEGIN
   ${atype}_util_pkg.ctrl($assigment_id,'${STATUS}');
END;
/
exit
EOF

if [ $? -gt 0 ]; then
	if [ ! -f $repdown_file ]; then
		echo `date` " ERROR REPDWN:	repository unreachable paging sysadmin"
		$SYS_TOP/bin/sendmail.sh $sysadmin "REPOSITORY unreachable (${HOSTNAME}): ${assigment_id}" $logfile.ss
		touch $repdown_file
	else
		echo `date` " INFO REPDWN:	repository unreachable not first time skiping sysadmin page"
	fi
	sleep 10
else
	rm -f $logfile.ss
	rm -f $repdown_file
	DONE="yes"
fi

## END update_status
}

set_status() {
STATUS="$1"
unset DONE
while [ ! "$DONE" ]
do
	update_status $STATUS
done

## END set_status
}



echo `date` " RUNNING:	$atype assigment: $assigment_id "
touch $pidfile
set_status RUNNING
$SYS_TOP/bin/${ascript} $assigment_id > $logfile 2>&1
if [ $? -gt 0 ]; then
	set_status ERROR
	echo `date` " ERROR:	running $atype assigment: $assigment_id "
	echo `date` " ERROR:	running $atype assigment: $assigment_id " > $mailfile
	tail -40 $logfile >> $mailfile
	cat $mailfile >> $logfile.err
	if [ ! -f $cntfile ]; then
		$SYS_TOP/bin/sendmail.sh $sysadmin "ERROR_running_$atype(${HOSTNAME}): ${assigment_id}" $mailfile
		touch $cntfile
	else
		echo `date` "INFO:	not first error skiping sysadmin page"
	fi
else
	set_status COMPLETE
	if [ -f $cntfile ]; then
		rm $cntfile
	fi
	echo `date` " DONE:	$atype assigment: $assigment_id "
fi


if [ -f $trcfile ]; then
	echo `date` " TRC-ON:    tracefile=$logfile.trc "
	cat $logfile >> $logfile.trc
fi

if [ -f $trcall ]; then
	echo `date` " TRC-ALL-ON:    tracefile=$logfile.trc "
	cat $logfile >> $logfile.trc
fi

rm -f $logfile
rm -f $pidfile

