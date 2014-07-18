#!/bin/ksh
#
# $Header evntproc.sh 04-NOV-2013 1.6
#
# File:
#	evntproc.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV
#
# Purpose:
#	Process EVENT
#
# Usage:
#	evntproc.sh EVENT_ASSIGMENTS.EA_ID
#
# History:
#	23-JUL-2002	VMOGILEV	(1.1) Created
#	10-MAR-2003	VMOGILEV	(1.2) added collection processing procs
#	03-APR-2003	VMOGILEV	(1.3) removed set_status moved to evntsubm.sh
#	03-APR-2003	VMOGILEV	(1.4) changed collproc.sh to [bgproc.sh $CA_ID COLL]
#	04-NOV-2013	VMOGILEV	(1.5) added $prevfile to the call of $event_file
#	02-DEC-2013	VMOGILEV	(1.6) added purge of load and prev + files 
#


BASENAME=`basename $0`
CTIME=`date`
usage()
{
echo "evntproc.sh EVENT_ASSIGMENTS.EA_ID"
exit 1;
}

if [ "$1" ]; then
	ASSIGMENT_ID=$1
else
	usage;
fi


echo "Starting event check on $CTIME "

echo "SHARE_TOP="$SHARE_TOP
echo "SEEDMON="$SEEDMON
echo "APPSMON="$APPSMON
echo "SIEBMON="$SIEBMON

if [ ! "$SHARE_TOP" ]; then
	echo "ERROR:   SHARE_TOP not set!"
	exit 1;
fi

if [ ! "$SEEDMON" ]; then
	echo "ERROR:   SEEDMON not set!"
	exit 1;
fi

if [ ! "$APPSMON" ]; then
	echo "ERROR:   APPSMON not set!"
	exit 1;
fi

if [ ! "$SIEBMON" ]; then
	echo "ERROR:   SIEBMON not set!"
	exit 1;
fi
if [ ! "$uname_passwd" ]; then
	echo "ERROR:   uname_passwd not set!"
	exit 1;
fi

if [ ! "$time_format" ]; then
	echo "ERROR:   time_format not set!"
	exit 1;
fi


run_coll()
{
#
# PROCEDURE run_coll
# ---------------------
#   run_coll COLL_ASSIGMENTS.CA_ID
#   submits collection for processing
#

CA_ID=$1
$SYS_TOP/bin/bgproc.sh $CA_ID COLL

if [ $? -gt 0 ]; then
        echo "run_coll:   Failure submitting collection ... exiting"
        exit 1
fi
}



proc_coll()
{
#
# PROCEDURE proc_coll
# ---------------------
#   proc_coll COLL_PARAMETERS.CP_CODE SIDS.S_ID SID_CREDENTIALS.SC_ID PAGE_LISTS.PL_ID EVENT_ASSIGMENTS.EA_ID
#   exports COLL_ASSIGMENTS.CA_ID
#

CP_CODE="$1"
S_ID=$2
SC_ID=$3
PL_ID=$4
EA_ID=$5

CHKF=$SHARE_TOP/syslog/${BASENAME}.${CP_CODE}.${EA_ID}.chk

echo "proc_coll:   CP_CODE=${CP_CODE}"
echo "proc_coll:   S_ID=${S_ID}"
echo "proc_coll:   SC_ID=${SC_ID}"
echo "proc_coll:   PL_ID=${PL_ID}"
echo "proc_coll:   EA_ID=${EA_ID}"

sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET SERVEROUTPUT ON

set trims on
set lines 100
VARIABLE ca_id NUMBER;
VARIABLE ret_code VARCHAR2(100);

BEGIN
   coll_util_pkg.evnt_get_ca(
      p_cp_code  => '${CP_CODE}'
   ,  p_s_id     => ${S_ID}
   ,  p_sc_id    => ${SC_ID}
   ,  p_pl_id    => ${PL_ID}
   ,  p_ea_id    => ${EA_ID}
   ,  p_ca_id_out => :ca_id
   ,  p_ret_code => :ret_code);
END;
/
l

commit;

set feed off
set pages 0
set trims on
spool $CHKF
SELECT :ret_code||','||TO_CHAR(:ca_id)
FROM dual;
spool off
exit
EOF

if [ $? -gt 0 ]; then
        echo "proc_coll:   Failure to get collection assignment on `date` !"
        exit 1
fi

CA_STAT=`cut -d"," -f1 $CHKF`
CA_ID=`cut -d"," -f2 $CHKF`

echo "CA_STAT=${CA_STAT}"
echo "CA_ID=${CA_ID}"

## if I got here call collection subprogram
if [ "$CA_STAT" = "NEW" ]; then
        # run collections twice
        run_coll $CA_ID;
        run_coll $CA_ID;
else
        run_coll $CA_ID;
fi

export CA_ID;
}



process_date=`sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set feed off
set pages 0
set trims on
select TO_CHAR(SYSDATE,'$time_format') from dual;
exit
EOF
`

logfile=$SHARE_TOP/tmp/$BASENAME.$ASSIGMENT_ID.$process_date
envfile=$logfile.env
prevfile=$logfile.prev
newfile=$logfile.new
clearfile=$logfile.clr


sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
VARIABLE out_ref_id NUMBER
BEGIN
   evnt_util_pkg.set_event_env($ASSIGMENT_ID,:out_ref_id);
END;
/
set trimspool on
set pages 0
set lines 900
set feed off
spool $envfile
SELECT eupo_out
FROM   evnt_util_pkg_out
WHERE  eupo_ref_id = :out_ref_id
order by eupo_ref_type
,        eupo_ref_id
,        eupo_id;
spool off
exit
EOF

if [ $? -gt 0 ]; then
	echo "ERROR:   while getting event assigment!"
	exit 1
fi

# first UNSET ALL PREV values
# this avoids bugs when someone
# had setup environment before
# starting up the event system bg proc
# and ENV gets carried over ...
#
for i in `env | egrep "PARAM__|MON__|DER__"`
do
	param_name=`echo $i | cut -d"=" -f1 `
	echo "UNSETTING PARAMETER:  ${param_name} ..."
	unset ${param_name}
done


. $envfile
env | grep "MON__" 
env | grep "DER__"
env | grep "PARAM__"


if [ "$DER__CONTINUE" = "NO" ]; then
	echo "$DER__HOLD_REASON"
	echo "Done on `date` !"
	rm $envfile
	exit 0 ;
fi


# parse prev values for the event trigger
#
if [ ! "$DER__last_et_id" ]; then
	touch $prevfile
else
sqlplus -s $uname_passwd <<EOF 
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
VARIABLE out_ref_id NUMBER
BEGIN
   evnt_util_pkg.get_event_output(NVL('$DER__last_et_id',-999),:out_ref_id);
END;
/
set trimspool on
set pages 0
set lines 2000
set feed off
spool $prevfile
SELECT eupo_out
FROM   evnt_util_pkg_out
WHERE  eupo_ref_id = :out_ref_id
order by eupo_ref_type
,        eupo_ref_id
,        eupo_id;
spool off
exit
EOF

if [ $? -gt 0 ]; then
	echo "ERROR:   while getting event output!"
	exit 1
fi

fi


## check if event is collection based
## if so process collection
if [ "$PARAM__cp_code" ]; then
	echo "calling proc_coll ..."
	proc_coll $PARAM__cp_code $MON__S_ID $MON__SC_ID $MON__PL_ID $MON__EA_ID;
fi


event_file=$MON__E_CODE_BASE/$MON__E_FILE_NAME
event_log=$SHARE_TOP/log/$MON__E_FILE_NAME.$ASSIGMENT_ID.$MON__H_NAME.$MON__S_NAME.$process_date.log

echo "EVENT_FILE="$event_file
echo "EVENT_LOG="$event_log

if [ ! -f $event_file ]; then
	echo "ERROR:   EVENT FILE "$event_file "is missing!"
	exit 1
fi


echo "Calling event file: "
echo "$event_file $newfile $event_log $clearfile $prevfile"
# call event file
#
$event_file $newfile $event_log $clearfile $prevfile
exit_code=$?

echo "checking exit code ..."
if [ $exit_code -gt 0 ]; then
	echo "ERROR:   While executing event file: $event_file !"
	echo "============================"
	echo "LAST 5 lines from CHK file:"
	echo "============================"
	tail -5 $newfile
	echo " "
	echo "============================"
	echo "LAST 15 lines from OUT file:"
	echo "============================"
	tail -15 $event_log
	exit 1
fi

echo "deriving trigger status ..."
if [ `cat $newfile | wc -l` -gt 0 ]; then
	if [ `diff $prevfile $newfile | wc -l` -gt 0 ]; then
		TRIGGER='NEW'
	else
		TRIGGER='OLD'
	fi
else
	TRIGGER='OFF'
fi

set_trigger()
{
TRIGGER_STATUS="$1"
SOURCE_FILE="$2"
OUTPUT_FILE="$3"

echo "TRIGGER_STATUS="$TRIGGER_STATUS
echo "SOURCE_FILE="$SOURCE_FILE
echo "OUTPUT_FILE="$OUTPUT_FILE

if [ ! "$TRIGGER_STATUS" ]; then
	echo "Missing trigger status!"
	exit 1 ;
fi


if [ ! -f "$SOURCE_FILE" ]; then
	echo "Missing source file!"
	exit 1 ;
fi

if [ ! -f "$OUTPUT_FILE" ]; then
	echo "Missing output file!"
	exit 1 ;
fi

SOURCE_LINES=`cat $SOURCE_FILE | wc -l`
OUTPUT_LINES=`cat $OUTPUT_FILE | wc -l`

if [ $SOURCE_LINES -gt 0 ]; then
cat $SOURCE_FILE |
 sed s/\'/\'\'/g |
 sed s/\,/\'\,\'/g |
 sed s/^/'exec evnt_util_pkg.insert_trigger_detail(:next_et_id,SYSDATE,'\'$BASENAME\'',SYSDATE,'\'$TRIGGER_STATUS\'','\'/g  |
 sed s/$/\'');'/g > $SOURCE_FILE.load

if [ `cat $SOURCE_FILE.load | wc -l` -ne $SOURCE_LINES ]; then
	echo "ERROR:   while parsing details file: $SOURCE_FILE !"
	exit 1
fi
else
	echo "INFO:   Source file $SOURCE_FILE has no lines ..."
fi

if [ $OUTPUT_LINES -gt 0 ]; then
cat $OUTPUT_FILE |
 sed s/\'/\'\'/g |
 sed s/\;/\,/g |
 sed s/^/'exec evnt_util_pkg.insert_trigger_output(:next_et_id,SYSDATE,'\'$BASENAME\'','\'/g  |
 sed s/$/\'');'/g > $OUTPUT_FILE.load

if [ `cat $OUTPUT_FILE.load | wc -l` -ne $OUTPUT_LINES ]; then
	echo "ERROR:   while parsing output file: $OUTPUT_FILE !"
	exit 1
fi
else
	echo "INFO:   Output file $OUTPUT_FILE has no lines ..."
fi

echo "inserting trigger information ..."
sqlplus -s $uname_passwd <<EOF
select 'inserting header ...' from dual;
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
VARIABLE next_et_id NUMBER
BEGIN
evnt_util_pkg.insert_trigger_header(
   :next_et_id
,  $MON__EA_ID
,  $MON__PL_ID
,  $MON__E_ID
,  $MON__H_ID
,  NVL('$MON__S_ID',NULL)
,  NVL('$MON__SC_ID',NULL)
,  SYSDATE
,  '$BASENAME'
,  SYSDATE
,  '$TRIGGER_STATUS'
,  '$DER__last_et_orig_et_id'
,  '$DER__last_et_id'
,  '$DER__last_sev_level'
,  '$PARAM__ep_hold_level'
,  '$MON__H_NAME'
,  '$MON__S_NAME'
,  '$MON__SC_DB_LINK_NAME'
,  '$event_file'
,  '$event_log'
,  '`basename $event_log`'
);
END;
/
set scan off
select 'inserting attributes ...' from dual;
@$SOURCE_FILE.load
commit;
-- commit before loading output
-- to save time
select 'inserting output ...' from dual;
@$OUTPUT_FILE.load
commit;
exit
EOF

if [ $? -gt 0 ]; then
	echo "ERROR:   while inserting trigger information !"
	exit 1
fi
rm -f $SOURCE_FILE.load $OUTPUT_FILE.load
}

# create empty output file if none
# was created to avoid error
#
if [ ! -f $event_log ]; then
	touch $event_log ;
fi
 
if [ "$TRIGGER" = "OFF" -a "$DER__last_sev_level" -a "$DER__last_sev_level" != "CLEARED" ]; then
	if [ ! -f $clearfile ]; then
		touch $clearfile ;
	fi
	echo "setting trigger with the following command: "
	echo "set_trigger CLEARED $clearfile $event_log "
	set_trigger CLEARED $clearfile $event_log ;
elif [ "$TRIGGER" = "NEW" ]; then
	echo "setting trigger with the following command: "
	echo "set_trigger "$PARAM__ep_code" $newfile $event_log"
	set_trigger "$PARAM__ep_code" $newfile $event_log ;
else
	echo "INFO:   Removing log and temp files ..."
	rm -f $envfile $event_log $newfile $clearfile $prevfile
fi

echo "TRIGGER="$TRIGGER
echo "INFO:   Removing log and temp files ..."
rm -f $envfile $event_log $newfile $clearfile $prevfile

echo "Done on `date` !"

