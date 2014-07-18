#!/bin/ksh
#
# $Header mon.sh 06/11/2002 1.2
#
# File:
#	mon.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	mon.sh
#
# Desc:
#	Sets up EVNT environmental variables and starts
#	char-based (sqlplus) user interface to EVNT repository
#
# History:
#	11-JUN-2002	VMOGILEV	Created
#

cd $SYS_TOP/bin
bstat
cd $SYS_TOP/sql
read EVNT_TNS?"Enter EVNT TNS Alias: "

TWO_TASK=$EVNT_TNS
export TWO_TASK

sqlplus evnt @x_dir.sql

