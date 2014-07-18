#!/bin/ksh
#
# $Header logmine.sh 06/11/2002 1.2
#
# File:
#	logmine.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	logmine.sh <logfile> <search_string> <ignore_string>
#
# Desc:
#	Parses <logfile> for occurences of <search_string>
#	ignoring all occurences of <ignore_string>.  Called
#	from various EVENTS in $*MON
#	
# History:
#	11-JUN-2002	VMOGILEV	Created
#	26-MAR-2003	VMOGILEV	added SED at the tail to remove ">" chars
#

FILE_NAME=$1
SEARCH_STRING="$2"
IGNORE_STRING="$3"
BASE_FILE_NAME=`basename $FILE_NAME`
WORK_DIR=$SHARE_TOP/wrk

OLD_FILE_NAME=$WORK_DIR/$BASE_FILE_NAME.old
NEW_FILE_NAME=$WORK_DIR/$BASE_FILE_NAME.new

cp $FILE_NAME $NEW_FILE_NAME

if [ ! -f $OLD_FILE_NAME ]; then
	touch $OLD_FILE_NAME
fi

if [ ! "$IGNORE_STRING" ]; then
        IGNORE_STRING="^\$"
fi

diff $OLD_FILE_NAME $NEW_FILE_NAME | grep "^>" | egrep "$SEARCH_STRING" | egrep -v "$IGNORE_STRING" | sed s/^\>//g

mv $NEW_FILE_NAME $OLD_FILE_NAME

