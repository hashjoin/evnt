#!/bin/ksh
#
# $Header bgman.sh 05/08/2006 1.7
#
# File:
#	bgman.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	bgman.sh EVNT|COLL sublist_build sleep_interval
#
# Desc:
#	Background processor for EVNT monitoring system
#	runs event and collection assigments
#
# History:
#	01-JUN-2002	VMOGILEV	(1.1) Created
#	26-MAR-2003	VMOGILEV	(1.2) changed sleep int from 2 to 1 sec 
#					      between calls to subprocs
#	03-APR-2003	VMOGILEV	(1.3) transitioned to bgproc.sh
#	27-APR-2006	VMOGILEV	(1.4) increased sleep from 1 sec to 5 sec
#	08-MAY-2006	VMOGILEV	(1.5) deincreased sleep from 5 sec to 2 sec
#	04-AUG-2006	VMOGILEV	(1.6) deincreased sleep from .5 sec to .2 sec
#	05-AUG-2006	VMOGILEV	(1.7) reverted back to .5 sec -- was taking too much load on storage
#

if [ $# -lt 3 ]; then
	echo "USAGE:	`basename $0` EVNT|COLL sublist_build sleep_interval"
	exit 1;
fi

sublist_type=$1
sublist_build=$SYS_TOP/bin/$2
sleep_int=$3

sublist_name=${sublist_type}.`basename ${sublist_build}`

logfile=$SHARE_TOP/syslog/$sublist_name.log
sublist=$SHARE_TOP/syslog/$sublist_name.list
mailfile=$sublist.mail
cntfile=$sublist.err_cnt
HOSTNAME=`hostname`


submitpend()
{
$sublist_build $sublist $mailfile

if [ $? -gt 0 ]; then
	echo `date` " ERROR:	getting pending sublist: $sublist_name "

	if [ ! -f $mailfile ]; then
		echo `date` " ERROR:	getting pending sublist: $sublist_name " > $mailfile
	fi

        cat $mailfile >> $sublist.err

	# create empty sublist
	echo "" > $sublist

        if [ ! -f $cntfile ]; then
                $SYS_TOP/bin/sendmail.sh $sysadmin "ERROR_getting_sublist(${HOSTNAME})_(${sublist_name})" $mailfile
                touch $cntfile
        else
                echo `date` " INFO:      not first error skiping sysadmin page"
        fi
else    
        if [ -f $cntfile ]; then
		echo `date` " INFO:	removing err count file"
                rm $cntfile
        fi
fi

for i in `cat $sublist`
do
	subid=$i
	
	echo `date` " SUBMITTING:	SUBID_ID=$subid "
	$SYS_TOP/bin/bgproc.sh $subid $sublist_type >> $logfile.$subid 2>&1 &
	sleep .5
done
}


echo `date` " starting " 
while :
do
        echo `date` "START OF BATCH"
        submitpend ;
        echo `date` "END OF BATCH"
	echo `date` "SLEEPING:	for $sleep_int seconds ..."
        sleep $sleep_int
        if [ -f $shutdown_file ]; then
                echo "Shutdown file detected: $shutdown_file "
                echo `date` " exiting " 
                break ;
        fi
done

