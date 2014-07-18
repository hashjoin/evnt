#!/bin/ksh
#
# File:
#       msslavec.sh
# EVNT_REG:	MYSQL_SLAVE_CHECK SEEDMON 1.1
# <EVNT_NAME>MySQL Slave Check</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# Checks MySQL Slave to see if it's in sync with it's master and if connection is active
# 
# REPORT ATTRIBUTES:
# -----------------------------
# Binlog Position LAG
# 
# 
# PARAMETER       DESCRIPTION                                 EXAMPLE
# --------------  ------------------------------------------  --------
# BINLOG_LAG      Number of BIN LOG clicks/posisions of LAG   10000
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        01/23/2014      v1.0	Created
#       VMOGILEV        01/28/2014      v1.1	Added SLAVE_LAG to chkfile
#


chkfile=$1
outfile=$2
clrfile=$3

REMOTE_HOST="$MON__H_NAME"
SHORT_HOST=${REMOTE_HOST%%.*}
BINLOG_LAG=${PARAM__BINLOG_LAG}

if [ ${BINLOG_LAG}"x" == "x" ]; then
	BINLOG_LAG=10000
fi


get_full_report() {
echo "--- slave status ---"
ssh -l oracle ${REMOTE_HOST} "echo \"SHOW SLAVE STATUS\\G\" | mysql"
echo "--- master status ---"
ssh -l oracle ${MASTER_HOST} "echo \"SHOW MASTER STATUS\\G;\" | mysql"
ssh -l oracle ${MASTER_HOST} "echo \"SHOW PROCESSLIST \\G;\" | mysql"
}


ssh -l oracle ${REMOTE_HOST} "date"
if [ $? -gt 0 ]; then
	echo "failed to ssh to slave host: ${REMOTE_HOST}"
	exit 1;
fi

MASTER_HOST=`ssh -l oracle ${REMOTE_HOST} "echo \"SHOW SLAVE STATUS\\G\" | mysql | grep Master_Host" | awk '{print $2}'`

ssh -l oracle ${MASTER_HOST} "date"
if [ $? -gt 0 ]; then
	echo "failed to ssh to master host: ${MASTER_HOST}"
	exit 1;
fi

SLAVE_POS=`ssh -l oracle ${REMOTE_HOST} "echo \"SHOW SLAVE STATUS\\G\" | mysql | grep Read_Master_Log_Pos" | awk '{print $2}'`
MASTER_POS=`ssh -l oracle ${MASTER_HOST} "echo \"SHOW MASTER STATUS\\G;\" | mysql | grep Position" | awk '{print $2}'`
SLAVE_CNT=`ssh -l oracle ${MASTER_HOST} "echo \"SHOW PROCESSLIST;\" | mysql | grep -c ${REMOTE_HOST}"`
SLAVE_LAG=`expr $MASTER_POS - $SLAVE_POS`

touch $chkfile
if [ ${SLAVE_CNT} -lt 1 ]; then
	echo "SLAVE_PROC_DOWN" >> $chkfile
fi

if [ ${SLAVE_LAG} -gt ${BINLOG_LAG} ]; then
	echo "SLAVE_LAG_TOO_HIGH,${SLAVE_LAG}" >> $chkfile
fi

if [ `cat $chkfile | wc -l` -gt 0 ]; then
	get_full_report > $outfile
fi

