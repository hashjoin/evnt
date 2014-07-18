#!/bin/ksh
#
# File:
#       bxupchk.sh
# EVNT_REG:	HOST_UP_CHK SEEDMON 1.1
# <EVNT_NAME>Host Down</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks Host availability by performing the following:
# 
#   if HOST PING failed then
#      status=HOST_DOWN
#      exit
#   else
#      status=OK
#      exit
#   end if
# 
# REPORT ATTRIBUTES:
# -----------------------------
# status
#
# NO Parameters
# 
# Recommended HOLD level = HOST
# </EVNT_DESC>
#
# History:
#       VMOGILEV        08/20/2002      dbupchk.sh Created
#	VMOGILEV	03/13/2003	dbupchk.sh ported to Linux
#	VMOGILEV	11/05/2004	bxupchk.sh created (removed all db checks for UNIX admins)
#


chkfile=$1
outfile=$2
clrfile=$3

OS=`uname -a | awk '{print $1}'`

if [ ! "$PARAM_PING_TIMEOUT" ]; then
        echo "using default ping timeout parameter: 120 seconds "
        PARAM_PING_TIMEOUT=120
fi


# 1. perform HOST PING
# ---------------------
#
if [ "$OS" = "Linux" ]; then
	$ping_cmd -c 10 -w $PARAM_PING_TIMEOUT $MON__H_NAME > $outfile.tmp 2>&1
else
	$ping_cmd $MON__H_NAME $PARAM_PING_TIMEOUT > $outfile.tmp 2>&1
fi

if [ $? -gt 0 ]; then
	echo "HOST_DOWN" >> $chkfile
	echo "====================================================================================== " >> $outfile
	echo `date` " FAILED:	PING $MON__H_NAME with $PARAM_PING_TIMEOUT timeout seconds" >> $outfile
	echo "====================================================================================== " >> $outfile
	cat $outfile.tmp >> $outfile
	rm $outfile.tmp
else
	# things are OK checkout
	touch $chkfile
	touch $outfile
	rm $outfile.tmp
fi

