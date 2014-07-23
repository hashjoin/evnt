#!/bin/ksh
#
# $Header 3pariom.sh	2014-Jul-23	v1.5
#
# HISTORY:
#	2013-Dec-18	v1.1	VMOGILEVSKIY	added check for service times
#	2013-Dec-19	v1.2	VMOGILEVSKIY	added check for Qlen counts
#	2013-Dec-20	v1.3	VMOGILEVSKIY	added drilldowns to disk level "statpd"
#	2013-Dec-20	v1.4	VMOGILEVSKIY	added drilldowns to vlun level stats
#   2014-Jul-23 v1.5    VMOGILEVSKIY	added MYID, renamed MY3PARARRAY


##
## setup
##

BASENAME=`basename $0`
MYUSER=oracle
MY3PARARRAY=$1
MYID=$2
TMPOUT=/tmp/${BASENAME}.${MYID}.out
REPOUT=/tmp/${BASENAME}.${MYID}.rep


##
## pars
##

maxio=$3   ## MAX IOPs per host
totio=$4   ## MAX total IOPs
maxms=$5   ## MAX Service Times in ms per host
maxql=$6   ## MAX QLEN count per host
cache=$7   ## GET the data from cache TMPOUT rather than running statvlun


if [ ${cache}"x" == "x" ]; then
	ssh $MYUSER@$MY3PARARRAY "statvlun -hostsum -host * -d 5 -sortcol 0 -iter 1" > ${TMPOUT}
fi

do_report=N
echo "" > ${REPOUT}

## notes on the below parsers for highio
##
## 1) egrep -v "IOSz|^--|Qlen|^$" ${TMPOUT}
##	filters out the headers, empties and "---"
## 2) sed -e '$d'
##	removes last line (the summary)
## 3) awk -v iothres=${maxio}
##	the main parser using awk:
##	  - if 3 column value is > maxio -- print the line
##
##   03:03:15 12/19/13 r/w    I/O per second       KBytes per sec  Svt ms     IOSz KB
##            Hostname       Cur   Avg   Max    Cur    Avg    Max Cur Avg   Cur   Avg Qlen
##             APPSDB1   t    14    14    14     96     96     96 2.2 2.2   6.7   6.7    0
##             APPSDB2   t    13    13    13    107    107    107 1.1 1.1   8.0   8.0    0
##   ...
##   ...
##   -------------------------------------------------------------------------------------
##                  25   t 28260 28260       387975 387975        6.1 6.1  13.7  13.7  858


highio=`egrep -v "IOSz|^--|Qlen|^$" ${TMPOUT} | sed -e '$d' | awk -v iothres=${maxio} '{ if($3>=iothres) printf("%s\n",$0)}'`
totaio=`egrep -v "^$" ${TMPOUT} | tail -1 | awk -v iothres=${totio} '{ if($3>=iothres) printf("%s\n",$3)}'`
highms=`egrep -v "IOSz|^--|Qlen|^$" ${TMPOUT} | sed -e '$d' | awk -v iothres=${maxms} '{ if($9>=iothres) printf("%s\n",$0)}'`
highql=`egrep -v "IOSz|^--|Qlen|^$" ${TMPOUT} | sed -e '$d' | awk -v iothres=${maxql} '{ if($13>=iothres) printf("%s\n",$0)}'`
highio_cnt=`echo "${highio}" | grep -v "^$" | wc -l`
totaio_cnt=`echo ${totaio} | grep -v "^$" | wc -l`
highms_cnt=`echo "${highms}" | grep -v "^$" | wc -l`
highql_cnt=`echo "${highql}" | grep -v "^$" | wc -l`


if [ ${totaio_cnt} -gt 0 ]; then
	echo "	- ISSUE: total IOPs are ${totaio} --  over threshold of ${totio} IOPs" >> ${REPOUT}
	echo "" >> ${REPOUT}
	do_report=Y
fi


if [ ${highio_cnt} -gt 0 ]; then
	echo "	- ISSUE: found ${highio_cnt} IO consumers over threshold of ${maxio} IOPs" >> ${REPOUT}
	echo "" >> ${REPOUT}
	echo "------- here are the hosts -------" >> ${REPOUT}
	egrep "IOSz|Qlen" ${TMPOUT} >> ${REPOUT}
	echo "${highio}" >> ${REPOUT}
	echo "" >> ${REPOUT}
	do_report=Y
fi

if [ ${highms_cnt} -gt 0 ]; then
	echo "	- ISSUE: found ${highms_cnt} hosts with services times over threshold of ${maxms} ms" >> ${REPOUT}
	echo "" >> ${REPOUT}
	echo "------- here are the hosts -------" >> ${REPOUT}
	egrep "IOSz|Qlen" ${TMPOUT} >> ${REPOUT}
	echo "${highms}" >> ${REPOUT}
	echo "" >> ${REPOUT}
	do_report=Y
fi

if [ ${highql_cnt} -gt 0 ]; then
	echo "	- ISSUE: found ${highql_cnt} hosts with Qlen over threshold of ${maxql}" >> ${REPOUT}
	echo "" >> ${REPOUT}
	echo "------- here are the hosts -------" >> ${REPOUT}
	egrep "IOSz|Qlen" ${TMPOUT} >> ${REPOUT}
	echo "${highql}" >> ${REPOUT}
	echo "" >> ${REPOUT}
	do_report=Y
fi


if [ ${do_report} == "Y" ]; then
	echo "------- 3PAR IO Alert!: `date` -------"
	cat ${REPOUT}
	echo "------- full report -------"
	cat ${TMPOUT}
	if [ ${cache}"x" == "Yx" ]; then
		echo "------- vlun level stats -------"
		ssh $MYUSER@$MY3PARARRAY "statvlun -vvsum -d 10 -sortcol 0 -rw -iter 1"
		echo "------- disk level stats -------"
		ssh $MYUSER@$MY3PARARRAY "statpd -d 10 -rw -iter 1"
	fi
else
	echo "no-issues-found"
fi

