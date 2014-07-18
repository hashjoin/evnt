#!/bin/ksh
#
# File:
#       dbupchk.sh
# EVNT_REG:	DB_UP_CHK SEEDMON 1.4
# <EVNT_NAME>Database Down</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks Database availability by performing the following:
# 
#   if HOST PING failed then
#      status=HOST_DOWN
#      exit
#   elif TNSPING failed then
#      status=LSNR_DOWN
#      exit
#   elif SQL*Plus failed then
#      status=DB_DOWN
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
# Recommended HOLD level = SID
# </EVNT_DESC>
#
# History:
#       VMOGILEV        08/20/2002      Created
#	VMOGILEV	03/13/2003	ported to Linux
#	VMOGILEV	05/06/2006	added 3 attempts for sqlplus conn before raising an ERROR
#					(due to number of ORA-12535: TNS:operation timed out)
#	VMOGILEV	05/16/2006	added 3 attempts for tnsping conn before raising an ERROR
#					(due to number of ORA-12535: TNS:operation timed out)
#	VMOGILEV	29/SEP/2009	switched to using MON__SC_TNS_ALIAS for tnsping
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
	exit 0;
fi

# 2. perform TNSPING
# -------------------
#

dbping() {
tnsping $MON__SC_TNS_ALIAS > $outfile.tmp

if [ $? -gt 0 ]; then
        LSNR_OK="NO"
else
        LSNR_OK="YES"
fi
}

CNT="1 2 3"

for i in $CNT
do
	sleep 2
        dbping;
        if [ $LSNR_OK = "YES" ]; then
                break;
        fi
done

if [ $LSNR_OK = "NO" ]; then
	echo "LSNR_DOWN $i" >> $chkfile
	echo "====================================================================================== " >> $outfile
	echo `date` " FAILED:	TNSPING $MON__SC_TNS_ALIAS $i attempts" >> $outfile
	echo "====================================================================================== " >> $outfile
	cat $outfile.tmp >> $outfile
	rm $outfile.tmp
	exit 0;
fi


# 3. perform SQL*Plus connection
# -------------------------------
#

dbconn() {

sqlplus -s $MON__CONNECT_STRING <<CHK > $outfile.tmp
WHENEVER SQLERROR EXIT FAILURE
set pages 0
set feed off
set trims on
select 'CHECK_OK' from DUAL;
exit
CHK

if [ $? -gt 0 ]; then
        DB_OK="NO"
else
        DB_OK="YES"
fi

}


CNT="1 2 3"

for i in $CNT
do
	sleep 2
        dbconn;
        if [ $DB_OK = "YES" ]; then
                break;
        fi
done

if [ $DB_OK = "NO" ]; then
	echo "DB_DOWN $i" >> $chkfile
	echo "====================================================================================== " >> $outfile
	echo `date` " FAILED:	SQL CONNECTION TO $MON__S_NAME $i attempts" >> $outfile
	echo "====================================================================================== " >> $outfile
	cat $outfile.tmp >> $outfile
	rm $outfile.tmp
else
	# things are OK checkout
	touch $chkfile
	touch $outfile
	rm $outfile.tmp
fi

