#!/bin/ksh
#
# File:
#       osinusg.sh
# EVNT_REG:	OS_IN_USAGE *SEEDMON 1.1
# <EVNT_NAME>Os File System Inode Usage</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks for OS level FILE SYSTEM Inode usage
# 
# REPORT ATTRIBUTES:
# -----------------------------
# file system
# inode pct usage
# 
# 
# PARAMETER       DESCRIPTION                               EXAMPLE
# --------------  ----------------------------------------  --------
# PCT_THRES       < FS Inode USAGE (df -i) [DEFAULT=90]     60
#                    LINUX   df -i
#                    SOLARIS /usr/ucb/df -i OR
#                            /usr/bin/df -F ufs -o i
# IGNORE_FS       != FILE SYSTEM (ignores specified FS)     /|/proc
#                 file systems to ignore must be separated
#                 by |
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        07/23/2004      Created
#


chkfile=$1
outfile=$2
clrfile=$3


touch $chkfile



if [ ! "$PARAM__PCT_THRES" ]; then
	echo "Using default treshold of 90%"
	PCT_THRES=90
else
	PCT_THRES="$PARAM__PCT_THRES"
fi


## SUBROUTINES called from below
## -----------------------------
## note that the only difference between the linux
## and solaris besides the "$dfcmd" is the awk's column
## numbers:
##	LINUX:		6,5
##	SOLARIS:	5,4
## see below
##

linux_chk() {
if [ ! "$PARAM__IGNORE_FS" ]; then
	echo "IN IF"
	pct_list=`$dfcmd | grep -vi Filesystem | grep -v grep | awk '{print $6 "," $5}' | cut -d"%" -f1`
else
	echo "IN ELSE"
	IGNORE_FS=`echo "${PARAM__IGNORE_FS}|" | sed s/\|/\$\|/g`
	pct_list=`$dfcmd | grep -vi Filesystem | grep -v grep | \
                  egrep -v "$IGNORE_FS" | awk '{print $6 "," $5}' | cut -d"%" -f1`
fi

## END linux_chk
}

solaris_chk() {
if [ ! "$PARAM__IGNORE_FS" ]; then
	echo "IN IF"
	pct_list=`$dfcmd | grep -vi Filesystem | grep -v grep | awk '{print $5 "," $4}' | cut -d"%" -f1`
else
	echo "IN ELSE"
	IGNORE_FS=`echo "${PARAM__IGNORE_FS}|" | sed s/\|/\$\|/g`
	pct_list=`$dfcmd | grep -vi Filesystem | grep -v grep | \
                  egrep -v "$IGNORE_FS" | awk '{print $5 "," $4}' | cut -d"%" -f1`
fi

## END solaris_chk
}


## MAIN code starts here

OS=`uname -a | awk '{print $1}'`

if [ "$OS" = "Linux" ]; then
	dfcmd="df -i";
	linux_chk;

elif [ -f "/usr/ucb/df" ]; then
	dfcmd="/usr/ucb/df -i";
	solaris_chk;

else
	## if we get here call "normal df for ufs"
	dfcmd="/usr/bin/df -F ufs -o i";
	solaris_chk;
fi


for i in $pct_list
do
	fs=`echo $i | cut -d"," -f1 ` 
	pct=`echo $i | cut -d"," -f2 ` 

	if [ "$pct" -gt "$PCT_THRES" ]; then
		echo "$i" >> $chkfile
		echo "File system's ($fs ${pct}%) INODE usage is over ${PCT_THRES}%" >> $outfile
	fi
done


if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi

echo " " >> $outfile
echo " " >> $outfile

$dfcmd >> $outfile

