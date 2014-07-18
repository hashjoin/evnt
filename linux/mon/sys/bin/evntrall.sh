#!/bin/ksh
#
# $Header evntrall.sh 03/10/2002 1.1
#
# File:
#       evntrall.sh
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV
#
# Purpose:
#       Register all EVENTs
#
# Usage:
#       evntrall.sh <repository> <evnt_password>
#
# History:
#	10-MAR-2003	VMOGILEV	Created
#


usage()
{
echo "evntrall.sh <repository> <evnt_password>"
exit 1;
}

if [ "$1" ]; then
	REPOSITORY="$1"
else
	usage;
fi

if [ "$2" ]; then
	PASSWORD="$2"
else
	usage;
fi

REG_SCRIPT=${SYS_TOP}/bin/evntrall.tmp.sh
rm -f $REG_SCRIPT


parse_top()
{
TOP_NAME=$1
echo "... scanning ${TOP_NAME}"
## parse TOP_NAME
echo "cd $TOP_NAME" >> $REG_SCRIPT
for i in `find $TOP_NAME -type f`
do
	EVNT_FILE=`basename $i`
	EVNT_CODE=`grep EVNT_REG $i | awk '{ print $3 " " $4 }'`
	COLL_FLAG=`grep EVNT_REG $i | awk '{ print $6 }'`
	if [ "$EVNT_CODE" ]; then
		echo "${SYS_TOP}/bin/evntmaint.sh ${EVNT_FILE} ${EVNT_CODE} evnt/${PASSWORD}@${REPOSITORY} $COLL_FLAG" >> $REG_SCRIPT
	fi
done
}


echo "... parsing SEEDMON"
parse_top $SEEDMON
echo "... parsing APPSMON"
parse_top $APPSMON
echo "... parsing SIEBMON"
parse_top $SIEBMON


echo "... START of event registration"
chmod +x $REG_SCRIPT
$REG_SCRIPT
echo "... END of event registration"

