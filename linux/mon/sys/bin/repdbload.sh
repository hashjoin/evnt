#!/bin/ksh
#
# $Header repdbload.sh 07/22/2014 1.3
#
# File:
#	repdbload.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV
#
# Purpose:
#	Process data upload to REPORTING Server (uses REPDB/DAT/CTL as params)
#
# Usage:
#	repdbload.sh REPDB DATAFILE SQLLDR_CTL_FILE
#   reads $SYS_TOP/conf/repdbload.sh.conf parsing REPDBs connect strings [could be multiples]
#
# History:
#	21-JUL-2014	VMOGILEV	(1.1) Created
#	21-JUL-2014	VMOGILEV	(1.2) Added Check for parse result
#	22-JUL-2014	VMOGILEV	(1.3) Added ctlsave to queue up DAT/CTL for maintenance of REPDB
#


BASENAME=`basename $0`
HOSTNAME=`hostname`

logfile=$SHARE_TOP/syslog/${BASENAME}.log
cfgfile=$SYS_TOP/conf/${BASENAME}.conf

echo "SHARE_TOP="$SHARE_TOP
if [ ! "$SHARE_TOP" ]; then
	echo "ERROR:   SHARE_TOP not set!"
	exit 1;
fi


usage() {
    echo "USAGE: repdbload.sh REPDB DATAFILE SQLLDR_CTL_FILE"
    exit 1;
}

if [ "$1" ]; then
	REPDB=$1
else
	usage;
fi

if [ "$2" ]; then
	DAT=$2
	DATBASE=`basename $DAT`
else
	usage;
fi

if [ "$3" ]; then
	CTL=$3
else
	usage;
fi


echo "`date`    ${DATBASE}: starting upload" >> $logfile

if [ -f $DAT ]; then
    echo "`date`    ${DATBASE}: $DAT found" >> $logfile
else
    echo "`date`    ${DATBASE}: ERROR - $DAT missing! Exiting!" >> $logfile
    exit 1;
fi

if [ -f $CTL ]; then
    echo "`date`    ${DATBASE}: $CTL found" >> $logfile
else
    echo "`date`    ${DATBASE}: ERROR - $CTL missing! Exiting!" >> $logfile
    exit 1;
fi


##
## CODE STARTS HERE
##


ctlsave() {

REPDB_CONNECT=$1
DBNAME=`echo $REPDB_CONNECT | awk -F"@" '{print $2}'`

if [ ${DBNAME}"x" == "x" ]; then
     DBNAME=${REPDB}_DB_uknown;
fi

savedir=$SHARE_TOP/wrk/${DBNAME}

mkdir -p $savedir
cp -p ${CTL} $savedir/
cp -p ${DAT} $savedir/

}

ctlload() {

REPDB_CONNECT=$1
DBNAME=`echo $REPDB_CONNECT | awk -F"@" '{print $2}'`

if [ ${DBNAME}"x" == "x" ]; then
     DBNAME=${REPDB}_DB_uknown;
fi

SQLDLOG=${CTL}.${DBNAME}.log
DISCARD=${DAT}.${DBNAME}.bad
ERRFILE=${DAT}.${DBNAME}.error

sqlldr ${REPDB_CONNECT} \
    data=$DAT \
    control=$CTL \
    log=$SQLDLOG \
    discard=$DISCARD

## check for errors
##
if [ $? -gt 0 ]; then
    echo "`date`:   ${DATBASE}: failed to upload to ${DBNAME}" >> $ERRFILE
    echo "con: ${DBNAME}"           >> $ERRFILE
    echo "dat: $DAT"                >> $ERRFILE
    echo "bad: $DISCARD"            >> $ERRFILE
    echo "log: $SQLDLOG"            >> $ERRFILE
    echo "ctl: $CTL"                >> $ERRFILE
fi
}



for x in `grep ^${REPDB} $cfgfile`
do
    connectdb=`echo $x | awk -F: '{print $2}'`
    enableddb=`echo $x | awk -F: '{print $3}'`
    if [ ${enableddb}"x" == "Yx" ]; then
        echo "`date`    ${DATBASE}:     found target - ${connectdb} loading ..." >> $logfile
        ctlload ${connectdb}
    elif [ ${enableddb}"x" == "Qx" ]; then
        echo "`date`    ${DATBASE}:     found target - ${connectdb} it's set to QUEUE - saving DAT/CTL ..." >> $logfile
        ctlsave ${connectdb}
    else
        echo "`date`    ${DATBASE}:     found target - ${connectdb} but it's disabled" >> $logfile
    fi
done

if [ ${connectdb}"x" == "x" ]; then
    echo "`date`    ${DATBASE}:     didn't find any targets for ${REPDB} ..." >> $logfile
fi

mailfile=${logfile}.${DATBASE}.mail
errcnt=`ls -l ${DAT}.*.error | wc -l`
if [ $errcnt -gt 0 ]; then
    echo "`date`    ${DATBASE}: failed to load to ${errcnt} targets, notifying $sysadmin" >> $logfile
    cat ${DAT}.*.error > $mailfile
    $SYS_TOP/bin/sendmail.sh $sysadmin "${DATBASE}: failed to load to ${errcnt} targets" $mailfile
    rm -f $mailfile
else
    echo "`date`    ${DATBASE}: uploaded successfully ... removing CTL and DAT" >> $logfile
    rm -f ${CTL}*
    rm -f ${DAT}*
fi
