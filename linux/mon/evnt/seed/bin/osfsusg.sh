#!/bin/ksh
#
# File:
#       osfsusg.sh
# EVNT_REG:	OS_FS_USAGE SEEDMON 1.2
# <EVNT_NAME>Os File System Full</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks for OS level FILE SYSTEM usage
# 
# REPORT ATTRIBUTES:
# -----------------------------
# file system
# pct usage
# 
# 
# PARAMETER       DESCRIPTION                               EXAMPLE
# --------------  ----------------------------------------  --------
# PCT_THRES       < FS USAGE (df -k) [DEFAULT=90]           60
# IGNORE_FS       != FILE SYSTEM (ignores specified FS)     /|/proc
#                 file systems to ignore must be separated
#                 by |
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        09/04/2002      v1.0	Created
#       VMOGILEV        12/23/2013      v1.2	Converted to use SSH
#


chkfile=$1
outfile=$2
clrfile=$3

REMOTE_HOST="$MON__H_NAME"
LOCAL_FILE_NAME="${SHARE_TOP}/wrk/${REMOTE_HOST}_df.out"
ssh -l oracle ${REMOTE_HOST} "df -h" > ${LOCAL_FILE_NAME}

touch $chkfile

if [ ! "$PARAM__PCT_THRES" ]; then
	echo "Using default treshold for df -k usage: 90%"
	PCT_THRES=90
else
	PCT_THRES="$PARAM__PCT_THRES"
fi



if [ ! "$PARAM__IGNORE_FS" ]; then
	echo "IN IF"
	pct_list=`grep -vi Filesystem ${LOCAL_FILE_NAME} | grep -v grep | awk '{print $6 "," $5}' | cut -d"%" -f1`
else
	echo "IN ELSE"
	IGNORE_FS=`echo "${PARAM__IGNORE_FS}|" | sed s/\|/\$\|/g`
	pct_list=`grep -vi Filesystem ${LOCAL_FILE_NAME} | grep -v grep | egrep -v "$IGNORE_FS" | awk '{print $6 "," $5}' | cut -d"%" -f1`
fi


for i in $pct_list
do
	fs=`echo $i | cut -d"," -f1 ` 
	pct=`echo $i | cut -d"," -f2 ` 

	if [ "$pct" -gt "$PCT_THRES" ]; then
		echo "$i" >> $chkfile
		echo "File system $fs is over ${pct}% usage" >> $outfile
	fi
done


if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi

echo " " >> $outfile
echo " " >> $outfile

cat ${LOCAL_FILE_NAME} >> $outfile

