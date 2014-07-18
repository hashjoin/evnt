#!/bin/ksh
#
# $Header cleanup.sh 04/21/2003 1.2
#
# File:
#	cleanup.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	cleanup.sh
#
# Desc:
#	Cleans up ENVT logs that are 1 days old
#
# History:
#	26-SEP-2002     VMOGILEV        1.1 Created
#	21-APR-2003     VMOGILEV        1.2 modified HERE parse and added "-type f"
#


BASENAME=`basename $0`
##echo $BASENAME

if [ "$BASENAME" = "$0" ]; then
	HERE="."
else
	HERE=`echo $0 | sed s/$BASENAME//g`
fi

##echo $HERE

. $HERE/../../MON.env

LOGFILE=$SHARE_TOP/syslog/cleanup.LOG

# tmp files
# ---------
echo "removing day old temp files [$SHARE_TOP/tmp] ..." >> $LOGFILE
find $SHARE_TOP/tmp -mtime +1 -name '*' -type f -ls >> $LOGFILE
find $SHARE_TOP/tmp -mtime +1 -name '*' -type f -exec rm {} \;

# log files
# ---------
echo "removing day old log files [$SHARE_TOP/log] ..." >> $LOGFILE
find $SHARE_TOP/log -mtime +1 -name '*' -type f -ls >> $LOGFILE
find $SHARE_TOP/log -mtime +1 -name '*' -type f -exec rm {} \;

# sys log files
# -------------
echo "removing day old syslog files [$SHARE_TOP/syslog] ..." >> $LOGFILE
find $SHARE_TOP/syslog -mtime +1 -name '*' -type f -ls >> $LOGFILE
find $SHARE_TOP/syslog -mtime +1 -name '*' -type f -exec rm {} \;

