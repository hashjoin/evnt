#!/bin/ksh
#
# $Header mailbg.sh 06/11/2002 1.1
#
# File:
#	mailbg.sh
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV (www.dbatoolz.com)
#
# Purpose:
#       Mail subsystem background process which calls 
#	mailman.sh to process all pending mail.
#
# Usage:
#       mailbg.sh <sl
#
# History:
#       VMOGILEV        06/11/2002      Created


usage()
{
echo "ERROR:	MAIL sleep interval is not defined!"
echo "mail_sleep_int="$mail_sleep_int
exit 1;
}


if [ "$mail_sleep_int" ]; then
	echo "MAIL process interval = $mail_sleep_int SEC"
else
	usage ;
fi

# process globals
#
if [ "$ack_notif_freq" ]; then
        ack_notif_freq=$ack_notif_freq
else
        echo "using default acknowledgment frequency for mail subsystem = 15 minutes ..."
        ack_notif_freq=15
fi

if [ "$ack_notif_tres" ]; then
        ack_notif_tres=$ack_notif_tres
else
        echo "using default acknowledgment threshold for mail subsystem = 3 primary notif b4 secondary ..."
        ack_notif_tres=3
fi

export ack_notif_freq;
export ack_notif_tres;

echo "MAIL acknowledgment frequency = $ack_notif_freq"
echo "MAIL acknowledgment threshold = $ack_notif_tres"



while :
do
	echo `date` " STARTING:	mail manager "
	$SYS_TOP/bin/mailman.sh 
	echo `date` " DONE:	mail manager "
	sleep $mail_sleep_int
	if [ -f $shutdown_file ]; then
		echo "Shutdown file detected: $shutdown_file "
		echo `date` " exiting " 
		break ;
	fi
done

