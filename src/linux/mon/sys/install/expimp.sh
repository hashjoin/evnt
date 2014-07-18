#!/bin/ksh
#
# File:
#	expimp.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV (www.dbatoolz.com)
#
# Usage:
#	expimp.sh exp|imp evnt/<passwd>@<REPDB> <v$database.name>
#
# Description:
#	Export / Import EVNT seed data
#
# History:
#	19-MAR-2003	VMOGILEV	Created
#

BASENAME=`basename $0`

usage() {
   echo "$BASENAME exp|imp evnt/<passwd>@<REPDB> <v\$database.name>"
   exit 1;
## END usage
}


check_exp() {
log=$1
if [ `grep "with warnings." $1 | wc -l` -gt 0 ]; then
   echo "EMP_EXP_error"
   cat $log
   exit 1;
fi

## END check_exp
}


chke() {
ES=$1
EM="$2"
ELOG=$3
if [ $ES -gt 0 ]; then
        echo $EM
        cat $ELOG
        echo "exiting ..."
        exit 1;
fi
## END chke
}

##
## __________START ____________
##

if [ $# -ne 3 ]; then
	usage;
fi

if [ "$1" = "exp" ]; then
	DOEXP="yes"
elif [ "$1" = "imp" ]; then
	DOIMP="yes"
else
	usage;
fi

CONSTR="$2"
SIDNAME="$3"


NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
export NLS_LANG

if [ "$DOEXP" ]; then
	sqlplus -s $CONSTR <<EOF > $BASENAME.cfg.log
	@expdrp.sql
	WHENEVER SQLERROR EXIT FAILURE
	@expcr8.sql
	set lines 132
	set trims on
	set pages 0
	set feed off
	SELECT tname FROM tab WHERE tname LIKE 'X%'

	spool $BASENAME.cfg
	/
	spool off
	exit;
EOF
	chke $? "ERROR getting X tables list ..." $BASENAME.cfg.log
	
	for TABLE_NAME in `cat $BASENAME.cfg | grep -v "^#"`
	do
   		echo "exporting table $TABLE_NAME ..."
   		exp $CONSTR tables=$TABLE_NAME file=$TABLE_NAME.data.dmp log=$TABLE_NAME.data.log > $BASENAME.exp.log 2>&1
   		chke $? "ERROR exporting $TABLE_NAME ..." $BASENAME.exp.log
   		check_exp $TABLE_NAME.data.log
	done   
fi


	
if [ "$DOIMP" ]; then
	sqlplus -s $CONSTR <<EOF > /dev/null
	@expdrp.sql
	exit
EOF
	for TABLE_NAME in `cat $BASENAME.cfg | grep -v "^#" `
	do
   		echo "importing table $TABLE_NAME ..."
		imp $CONSTR COMMIT=N buffer=5242880 file=$TABLE_NAME.data.dmp log=$TABLE_NAME.data.log_imp > $BASENAME.imp.log 2>&1
		chke $? "ERROR importing $TABLE_NAME ..." $BASENAME.imp.log
		check_exp $TABLE_NAME.data.log_imp
	done

	echo "uploading X tables ..."
	sqlplus -s $CONSTR <<EOF > $BASENAME.upl.log
	set echo on
	WHENEVER SQLERROR EXIT FAILURE
	@impupl.sql $SIDNAME
	exit
EOF
	chke $? "ERROR uploading X tables ... " $BASENAME.upl.log
fi
