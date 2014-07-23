#!/bin/ksh
#
# $Header repdbloadq.sh 07/22/2014 1.1
#
# File:
#	repdbload.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV
#
# Purpose:
#   You can QUEUE up the DAT/CTL pairs to $SHARE_TOP/wrk/${DBNAME} directory
#   by setting Q flag in $SYS_TOP/conf/repdbload.sh.conf
#
#	Then you can use this script to process queued data from $SHARE_TOP/wrk/${DBNAME} directory
#   and load it to a provided DB connection (CONN param)
#
# Usage:
#	repdbload.sh DBNAME CONN
#     - reads $SHARE_TOP/wrk/${DBNAME}/*dat directory
#     - loads all *dat files using their *ctl files connecting to $CONN
#
# History:
#	22-JUL-2014	VMOGILEV	(1.1) Created
#


BASENAME=`basename $0`
HOSTNAME=`hostname`


echo "SHARE_TOP="$SHARE_TOP
if [ ! "$SHARE_TOP" ]; then
	echo "ERROR:   SHARE_TOP not set!"
	exit 1;
fi


usage() {
    echo "USAGE: repdbloadq.sh DBNAME CONN"
    exit 1;
}

if [ "$1" ]; then
	DBNAME=$1
else
	usage;
fi

if [ "$2" ]; then
	CONN=$2
else
	usage;
fi



echo "`date`    ${DBNAME}: starting upload"

if [ -d $SHARE_TOP/wrk/${DBNAME} ]; then
    cnt=`ls -l $SHARE_TOP/wrk/${DBNAME}/*.dat | wc -l`
    echo "`date`    ${DBNAME}: $SHARE_TOP/wrk/${DBNAME} found ${cnt} dat files"
else
    echo "`date`    ${DBNAME}: ERROR - $SHARE_TOP/wrk/${DBNAME} missing! Exiting!"
    exit 1;
fi



##
## CODE STARTS HERE
##



ctlload() {

REPDB_CONNECT=$1
DAT=$2
CTL=$3

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
    echo "`date`:   ${DBNAME}: failed to upload DAT=${DAT}" >> $ERRFILE
    echo "con: ${DBNAME}"           >> $ERRFILE
    echo "dat: $DAT"                >> $ERRFILE
    echo "bad: $DISCARD"            >> $ERRFILE
    echo "log: $SQLDLOG"            >> $ERRFILE
    echo "ctl: $CTL"                >> $ERRFILE
    cat $ERRFILE
else
    echo "`date`    ${DBNAME}:     done DAT=${DAT} ... removing CTL and DAT"
    rm -f ${CTL}*
    rm -f ${DAT}*
fi
}



for x in `ls $SHARE_TOP/wrk/${DBNAME}/*.dat`
do
    basefile=`echo $x | awk -Fdat '{print $1}'`
    ctlfile=${basefile}sqlldr.ctl

    if [ -f $ctlfile ]; then
        echo "`date`    ${DBNAME}:     found DAT/CTL pair loading ..."
        ctlload $CONN $x $ctlfile
    else
        echo "`date`    ${DBNAME}:     DAT missing CTL pair: basefile=${basefile}"
    fi
done
