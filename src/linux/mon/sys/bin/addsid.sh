#!/bin/ksh
#
# $Header addsid.sh 09/07/2004 1.2
#
# File:
#	addsid.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV (www.dbatoolz.com)
#
# Usage
#	% addsid.sh
#
# Desciption:
#	Adds new database to EVNT monitoring
#
# History:
#	20-MAR-2003	VMOGILEV	(1.1) Created
#	07-SEP-2004	VMOGILEV	(1.2) changed HOSTNAME parse
#

LOG=$SHARE_TOP/log/$$.evnt_addasid.log

if [ ! -f $SYS_TOP/bin/trgint.sh ]; then
	echo "can't locate $SYS_TOP/bin/trgint.sh ..."
	echo "did you source MON.env?"
	echo "exiting ..."
	exit 1;
fi

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


parse() {
## parse hostname by SID's TNS Alias 
echo "parsing hostname ..."
STRING=`tnsping $TRG_TNS | grep "HOST="`
HOSTNAME=`sqlplus -s "/ as sysdba" <<EOF
spool $LOG.hostname
set pages 0
set trims on
select substr(substr('$STRING',instr(upper('$STRING'),'HOST')+5),
        1,instr(substr('$STRING',instr(upper('$STRING'),'HOST')+5),')')-1)
from dual;
spool off
exit
EOF`
chke $? "HOSTNAME parse failure ..." $LOG.hostname

echo "  HOSTNAME=[${HOSTNAME}]"


## parse sid name in V$DATABASE 
echo "parsing dbname ..."
sqlplus -s sys/$SYS_PASS@$TRG_TNS <<EOF  > $LOG.dbname
WHENEVER SQLERROR EXIT FAILURE
set lines 3000
set trims on
set pages 0
set feed off
SELECT name
from v\$database

spool $LOG.dbname.dat
/
spool off
exit
EOF
chke $? "target database name parse failure ..." $LOG.dbname

DBNAME=`cat $LOG.dbname.dat`
echo "	DBNAME=$DBNAME"
export DBNAME

## parse APPS in dba_objects
echo "parsing APPS ..."
sqlplus -s sys/$SYS_PASS@$TRG_TNS <<EOF  > $LOG.apps
WHENEVER SQLERROR EXIT FAILURE
set lines 3000
set trims on
set pages 0
set feed off
select to_char(count(*))
from dba_tables
where table_name='FND_CONCURRENT_REQUESTS'
and rownum=1

spool $LOG.apps.dat
/
spool off
exit
EOF
chke $? "target database APPS parse failure ..." $LOG.apps

ISAPPS=`cat $LOG.apps.dat`
echo "	ISAPPS=$ISAPPS"
export ISAPPS

if [ $ISAPPS -gt 0 ]; then
	unset OK
	while [ ! "$OK" ]
	do
		read APPS_PASS?"	Enter APPS password: "
		sqlplus apps/$APPS_PASS@$TRG_TNS <<EOF  > $LOG.apps.chk
		select USER from dual;
		exit
EOF
	if [ $? -gt 0 ]; then
		echo "invalid APPS password ... "
	else
		OK="ok"
		export APPS_PASS
	fi
	done
	
fi


## END parse
}


cr8mon() {
echo "creating MON schema ..."
sqlplus -s sys/$SYS_PASS@$TRG_TNS <<EOF > $LOG.cr8mon
WHENEVER SQLERROR EXIT FAILURE
@$SYS_TOP/sql/cr8musr.sql $SYS_PASS $TRG_TNS MON $DEF_TS
exit
EOF

chke $? "error creating MON schema ... " $LOG.cr8mon ;
## END cr8mon
}


grntapps() {
echo "granting APPS privs to MON schema ..."
sqlplus -s sys/$SYS_PASS@$TRG_TNS <<EOF > $LOG.gntapps
WHENEVER SQLERROR EXIT FAILURE
@$SYS_TOP/sql/cr8musra.sql MON justagate $APPS_PASS $TRG_TNS
exit
EOF

chke $? "error granting APPS privs to MON schema ... " $LOG.gntapps ;
## END grntapps
}

vinit() {
echo "validating new SID's parameters ..."
sqlplus -s sys/$SYS_PASS@$TRG_TNS <<EOF > $LOG.init
WHENEVER SQLERROR EXIT FAILURE
create user test123456789 identified by test
default tablespace $DEF_TS temporary tablespace TEMP;
drop user test123456789;
exit
EOF

chke $? "can't validate new SID's parameters ... " $LOG.init ;

## END vinit
}

vevnt() {
echo "validating EVNT parameters ..."
sqlplus -s evnt/$EVNT_PASS@$EVNT_TNS <<EOF > $LOG.init
WHENEVER SQLERROR EXIT FAILURE
select count(*) from events;
exit
EOF

chke $? "can't validate EVNT parameters ... " $LOG.init ;

## END vevnt
}


getnsid() {
echo "
Provide the following information about the
database you wish to monitor:
"
read TRG_TNS?"	Enter new sid's TNS alias: "
read SYS_PASS?"	Enter new sid's sys password: "
read DEF_TS?"	Enter new sid's TOOLS tablespace: "
read DB_DESC?"	Enter new sid's description: "

export TRG_TNS
export SYS_PASS
export DEF_TS
export DB_DESC

echo "
TRG_TNS=$TRG_TNS
SYS_PASS=$SYS_PASS
DEF_TS=$DEF_TS
DB_DESC=$DB_DESC
EVNT_PASS=$EVNT_PASS
EVNT_TNS=$EVNT_TNS
" >> $LOG

## validate init parameters
vinit;

## parse HOST/DBNAME
parse;

## create MON user
cr8mon;

## if db=APPS grant APPS privs
if [ $ISAPPS -gt 0 ]; then
	grntapps;
fi

## add new target to datafile
echo "$HOSTNAME,,$DBNAME,\"$DB_DESC\",mon,justagate,$TRG_TNS" >> SERVER.dat

## END getnsid
}



##
## _____________START_______________
##

echo "
Provide the following information about the
database you designated as repository for EVNT:
"

read EVNT_TNS?"	Enter EVNT TNS Alias: "
read EVNT_PASS?"	Enter EVNT password: "

export EVNT_PASS
export EVNT_TNS

echo "
EVNT_PASS=$EVNT_PASS
EVNT_TNS=$EVNT_TNS
" > $LOG

## validate EVNT parameters
vevnt;

while [ ! "$DONE" ]
do
	getnsid;
	read T_DONE?"Do you have more sids to add? [y]: "
	if [ "$T_DONE" = "n" -o "$T_DONE" = "N" ]; then
		DONE="yes"
	fi
done

echo "done gathering new sid(s) information ..."
echo "importing new sid(s) into EVNT repository ..."
trgint.sh SERVER.dat evnt/$EVNT_PASS@$EVNT_TNS >$LOG.reghost 2>&1
chke $? "import failure [ trgint.sh SERVER.dat evnt/$EVNT_PASS@$EVNT_TNS ] ..." $LOG.reghost

echo "Done!"

