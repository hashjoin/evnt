#!/bin/ksh
#
# $Header clnsid.sh 02/11/2004 1.2
#
# File:
#	clnsid.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV (www.dbatoolz.com)
#
# Usage
#	% clnsid.sh
#
# Desciption:
#	Clones all event assigments from one SID to another
#
# History:
#	25-MAR-2003	VMOGILEV	Created
#	11-FEB-2004	VMOGILEV	(1.2) got rid of UPPER() on s_name
#

LOG=$SHARE_TOP/log/$$.evnt_clnsid.log

if [ ! -f $SYS_TOP/sql/sidcln.sql ]; then
	echo "can't locate $SYS_TOP/sql/sidcln.sql ..."
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

psrc() {
sqlplus -s evnt/$EVNT_PASS@$EVNT_TNS <<EOF >$LOG.ass
col event format a23 trunc heading "Event"
col threshold format a23 trunc heading "Threshold"
col credentials format a10 trunc heading "Credentials"
col interval format 99999999 heading "Interval"

select
   '$'||e_code_base||'/'||e_file_name event
,  ep.ep_code threshold
,  sc_username credentials
,  ea_min_interval interval
from event_assigments_v e
,    event_parameters ep
--where s_name = UPPER('$SRC_SID')
where s_name = '$SRC_SID'
and e.ep_id = ep.ep_id
order by event, threshold

spool $LOG.ass.dat
/
spool off
exit
EOF

chke $? "source database event assigment report failure ..." $LOG.ass

echo "the following event assigments will be used by the clone process:"
echo " "
cat $LOG.ass.dat

## END psrc
}


parse() {
## parse hostname by SID's name
echo "parsing target hostname ..."

sqlplus -s evnt/$EVNT_PASS@$EVNT_TNS <<EOF >$LOG.prs
WHENEVER SQLERROR EXIT FAILURE
set lines 3000
set trims on
set pages 0
set feed off

select h_name
from hosts
where h_id = (select h_id
              from sids
              --where s_name = upper('$TRG_SID'))
              where s_name = '$TRG_SID')

spool $LOG.prs.dat
/
spool off
exit
EOF
chke $? "target hostname parse failure ..." $LOG.prs

TRG_HOST=`cat $LOG.prs.dat`
echo "	TRG_HOST=$TRG_HOST"
export TRG_HOST

## check sc_username_copy_to

echo "validating sc_username_copy_to ..."
sqlplus -s evnt/$EVNT_PASS@$EVNT_TNS <<EOF >$LOG.prs
WHENEVER SQLERROR EXIT FAILURE
set lines 3000
set trims on
set pages 0
set feed off

select sc_username
from sid_credentials
where UPPER(sc_username) = UPPER(NVL('$TRG_USER','MON'))
and s_id = (select s_id
            from sids
            --where s_name = UPPER('$TRG_SID'))
            where s_name = '$TRG_SID')


spool $LOG.prs.dat
/
spool off
exit
EOF
chke $? "target sc_username_copy_to validation failure ..." $LOG.prs

TRG_USER_CONF=`cat $LOG.prs.dat`
echo "	TRG_USER_CONF=$TRG_USER_CONF"
export TRG_USER_CONF

if [ ! "$TRG_USER_CONF" ]; then
	echo "ERROR: $TRG_USER hasn't been registered as sid credential for $TRG_SID"
	exit 1;
fi


echo "validating pl_code_copy_to ..."
sqlplus -s evnt/$EVNT_PASS@$EVNT_TNS <<EOF >$LOG.prs
WHENEVER SQLERROR EXIT FAILURE
set lines 3000
set trims on
set pages 0
set feed off

select pl_code
from page_lists
where pl_code = UPPER(NVL('$TRG_PLC','EMAIL'))

spool $LOG.prs.dat
/
spool off
exit
EOF
chke $? "target pl_code_copy_to validation failure ..." $LOG.prs

TRG_PLC_CONF=`cat $LOG.prs.dat`
echo "	TRG_PLC_CONF=$TRG_PLC_CONF"
export TRG_PLC_CONF

if [ ! "$TRG_PLC_CONF" ]; then
        echo "ERROR: $TRG_PLC is an invalid page list code"
        exit 1;
fi


## END parse
}


clonesid() {
echo "cloning $SRC_SID sid event assigments ..."
sqlplus -s evnt/$EVNT_PASS@$EVNT_TNS <<EOF > $LOG.clone
WHENEVER SQLERROR EXIT FAILURE
@$SYS_TOP/sql/sidcln.sql $SRC_SID $TRG_HOST $TRG_SID $TRG_USER_CONF $TRG_PLC_CONF
exit
EOF

chke $? "error cloning $SRC_SID sid event assigments ... " $LOG.clone ;
## END clonesid
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
database you wish to clone TO:
"
read TRG_SID?"	Enter sid's name (case sensitive): "
read TRG_USER?"	Enter sid credentials account [mon]: "
read TRG_PLC?"	Enter page list code [EMAIL]: "

export TRG_SID
export TRG_USER
export TRG_PLC

echo "
TRG_SID=$TRG_SID
TRG_USER=$TRG_USER
TRG_PLC=$TRG_PLC
EVNT_PASS=$EVNT_PASS
EVNT_TNS=$EVNT_TNS
" >> $LOG

## parse
parse;

## clone sid
clonesid;

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

echo "
Provide the following information about the
database you wish to clone FROM:
"

read SRC_SID?"	Enter SOURCE sid (case sensitive): "

export SRC_SID

echo "
SRC_SID=$SRC_SID
" >> $LOG

#print source assigments
psrc;


while [ ! "$DONE" ]
do
	getnsid;
	read T_DONE?"Do you have more sids to clone? [y]: "
	if [ "$T_DONE" = "n" -o "$T_DONE" = "N" ]; then
		DONE="yes"
	fi
done

echo "Done!"

