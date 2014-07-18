#!/bin/ksh
#
# $Header bgtrc.sh 04/04/2003 1.1
#
# File:
#	bgtrc.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	bgtrc.sh [<assigment_id> EVNT|COLL ON|OFF]
#
# Desc:
#	Event subprocess handler
#
# History:
#	04-APR-2003	VMOGILEV	(1.1) Created
# 

if [ ! "$SHARE_TOP" ]; then
	echo "ERROR:	environment is not set!"
	echo "Did you source MON.env?"
	exit 1;
fi

BASENAME=`basename $0`
HOSTNAME=`hostname`

usage()
{
echo "
$BASENAME [<assigment_id> EVNT|COLL ON|OFF]
"
exit 1;
}

if [ $# -eq 3 ]; then
	aid="$1"
	atype="$2"
	flag="$3"
elif [ $# -eq 2 ]; then
	atype="$1"
	flag="$2"
else
	read atype?"Enter assignment type [EVNT|COLL]: "
	read aid?"Enter assignment id [can be null]: "
	unset DONE
	while [ ! "$DONE" ] 
	do
		if [ "$flag" = "ON" -o "$flag" = "OFF" ]; then
			DONE="yes"
		else
			read flag?"Trace [ON|OFF]: "
		fi
	done
fi


if [ "$atype" = "COLL" ]; then
	echo "collection ..."
elif [ "$atype" = "EVNT" ]; then
	echo "event ..."
else
	echo "ERROR:	Invalid assignment type!"
	usage;
fi


trcfile=$SHARE_TOP/wrk/${atype}.${aid}.trc
trcall=$SHARE_TOP/wrk/${atype}.all.trc


enable_trc() {

if [ "$aid" ]; then
	touch $trcfile
else
	touch $trcall
fi

## END enable_trc
}

disable_trc() {

if [ "$aid" ]; then
	rm -f $trcfile
else
	rm -f $trcall
	rm -f $SHARE_TOP/wrk/${atype}.*.trc
fi

## END disable_trc
}


if [ "$flag" = "ON" ]; then
	echo "enabling trace for $atype (${aid})"
	enable_trc;
elif [ "$flag" = "OFF" ]; then
	echo "disabling trace for $atype (${aid})"
	disable_trc;
else
	echo "ERROR:	Invalid trace flag=$flag"
	usage;
fi

echo "Done!"

find $SHARE_TOP/wrk/

