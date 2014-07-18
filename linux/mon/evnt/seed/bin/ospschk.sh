#!/bin/ksh
#
# File:
#       ospschk.sh
# EVNT_REG:	OS_PS_CHECK *SEEDMON 1.1
# <EVNT_NAME>Os Process Failure</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks for various states of OS LEVEL processes see below:
# 
# REPORT ATTRIBUTES:
# -----------------------------
# process_name
# count (optional if CHK_TYPE=notexist)
# 
# 
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  --------
# CHK_TYPE        Type of process check to perform valid values:      notexist
#                    exist - triggers when process is found
#                    notexist - triggers when process is not found
#                               or when number of found processes is
#                               less then CHK_CNT
# 
# CHK_PROCESS     Name of the process to check (used by grep util     ora_
#                 to filter ps -ef command output
# 
# CHK_CNT         Number of expected processes [DEFAULT=1] only used  6
#                 when CHK_TYPE=notexist
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        09/05/2002      Created
#


chkfile=$1
outfile=$2
clrfile=$3

BASENAME=`basename $0`

CHK_TYPE="$PARAM__CHK_TYPE"

if [ ! "$PARAM__CHK_PROCESS" ]; then
	echo "ERROR:	missing process to check parameter!"
	exit 1;
else
	CHK_PROCESS="$PARAM__CHK_PROCESS"
fi


if [ ! "$PARAM__CHK_CNT" ]; then
	echo "Using default treshold for ps -ef process count: 1"
	CHK_CNT=1
else
	CHK_CNT="$PARAM__CHK_CNT"
fi


chk_yes()
{
echo "IN CHK_YES"
if [ `ps -ef | grep $CHK_PROCESS | grep -v grep | grep -v $BASENAME | wc -l` -gt 0 ]; then
	echo "$CHK_PROCESS" > $chkfile
	echo "Active process detected [${CHK_PROCESS}]" > $outfile
else
	touch $chkfile
fi
}

chk_no()
{
echo "IN CHK_NO"
if [ `ps -ef | grep $CHK_PROCESS | grep -v grep | grep -v $BASENAME | wc -l` -lt $CHK_CNT ]; then
	echo "${CHK_PROCESS},${CHK_CNT}" > $chkfile
	echo "Active process count ${CHK_PROCESS} is less then ${CHK_CNT}" > $outfile
else
	touch $chkfile
fi
}


#
# chk_yes will set trigger
# if process is present
#
# chk_no will set trigger
# if process is not present
#
case "$CHK_TYPE" in
exist)   chk_yes ;;
notexist)  chk_no ;;
*)      exit 1 ;;
esac

if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi

echo " " >> $outfile
echo " " >> $outfile

ps -ef >> $outfile

