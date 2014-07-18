#!/bin/ksh
#
# File:
#       ocrschk.sh
# EVNT_REG:	ORA_CRS_CHECK SEEDMON 1.0
# <EVNT_NAME>Oracle CRS Check</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks for CRS for issues
# 
# REPORT ATTRIBUTES:
# -----------------------------
# file system
# pct usage
# 
# 
# PARAMETER       DESCRIPTION                               EXAMPLE
# --------------  ----------------------------------------  --------
# CRS_HOME        Oracle CRS HOME full path                 /oracle/crs/product/1020/crs
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        01/16/2014      v1.0	Created
#


chkfile=$1
outfile=$2
clrfile=$3

REMOTE_HOST="$MON__H_NAME"
SHORT_HOST=${REMOTE_HOST%%.*}
CRSD_LOG=${PARAM__CRS_HOME}/log/${SHORT_HOST}/crsd/crsd.log
ALERT_LOG=${PARAM__CRS_HOME}/log/${SHORT_HOST}/alert${SHORT_HOST}.log

LOCAL_FILE_NAME="${SHARE_TOP}/wrk/${REMOTE_HOST}_crs_check.out"
rm -rf ${LOCAL_FILE_NAME}
ssh -l oracle ${REMOTE_HOST} "${PARAM__CRS_HOME}/bin/crsctl check crs" > ${LOCAL_FILE_NAME}


if [ `grep "appears healthy" ${LOCAL_FILE_NAME} | wc -l` -eq 3 ]; then
	touch $chkfile
        exit 0 ;
else
	cat ${LOCAL_FILE_NAME} > $chkfile
	cat ${LOCAL_FILE_NAME} > $outfile
	echo " " >> $outfile
	echo " " >> $outfile
	echo "----------- crs_stat -t ----------" >> $outfile
	ssh -l oracle ${REMOTE_HOST} "${PARAM__CRS_HOME}/bin/crs_stat -t" >> $outfile
	echo " " >> $outfile
	echo " " >> $outfile
	echo "----------- crs_stat -u ----------" >> $outfile
	ssh -l oracle ${REMOTE_HOST} "${PARAM__CRS_HOME}/bin/crs_stat -u" >> $outfile
	echo " " >> $outfile
	echo " " >> $outfile
	echo "----------- CRSD LOG [last 100 lines] [${CRSD_LOG}]----------" >> $outfile
	ssh -l oracle ${REMOTE_HOST} "tail -100 ${CRSD_LOG}" >> $outfile
	echo " " >> $outfile
	echo " " >> $outfile
	echo "----------- Clusterware Alert Log [last 100 lines] [${ALERT_LOG}] ----------" >> $outfile
	ssh -l oracle ${REMOTE_HOST} "tail -100 ${ALERT_LOG}" >> $outfile
fi

