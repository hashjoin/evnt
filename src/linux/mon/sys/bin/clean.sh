#!/bin/ksh
#	

if [ ! "$SHARE_TOP" ]; then
	echo "environment is not set!"
	echo "did you source MON.env ?"
	exit 1;
fi


echo "removing syslogs ..."
find $SHARE_TOP/syslog/ -type f -name '*' -exec rm {} \;

echo "removing logs ..."
find $SHARE_TOP/log/ -type f -name '*' -exec rm {} \;

echo "removing tmps ..."
find $SHARE_TOP/tmp/ -type f -name '*' -exec rm {} \;

echo "removing install logs ..."
find $SYS_TOP/install/ -type f -name '*log_*' -exec rm {} \;
find $SYS_TOP/install/ -type f -name '*.log' -exec rm {} \;
find $SYS_TOP/install/ -type f -name 'cdsddl.lst' -exec rm {} \;

echo "done!"

