#!/bin/ksh
#
# $Header shutdown.sh 06/11/2002 1.2
#
# File:
#	shutdown.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	shutdown.sh
#
# Desc:
#	Stops EVNT background processes
#
# History:
#	11-JUN-2002	VMOGILEV	Created
#	27-MAR-2003	VMOGILEV	1.2 added *proc.sh procs to the list
#

touch $shutdown_file

bstat
while [ `ps -ef | egrep "bgman.sh|bgproc.sh|mailbg.sh|evntproc.sh|collproc.sh" | grep -v grep | wc -l` -gt 0 ]
do
	echo "... `date` waiting for active processes to shutdown "
	sleep 5
done
echo "Done!"

