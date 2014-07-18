#!/bin/ksh
#
# File:
#       dbaudmon.sh
# EVNT_REG:	MON_AUDIT_LOGS *SEEDMON 1.2
# <EVNT_NAME>Audit Logs Parser</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (magil_ru@yahoo.com)
#
# Usage:
# <EVNT_DESC>
# Checks database AUDIT logs for AUDIT_ACTIONS.ACTION occurences. Runs through remote agent
# on the server that's being monitored.
#
# The following sql can be used to find ACTION numbers to use for this event:
#    select * from AUDIT_ACTIONS;
# 
# REPORT ATTRIBUTES:
# -----------------------------
# audit_logname
# 
# 
# PARAMETER       DESCRIPTION
# --------------  ----------------------------------------------------------
# SEARCH_STRING   AUDIT_ACTIONS.ACTION separated by space   (DEFAULT = 100 43)
#                    100 = LOGON     (failed login see below)
#                    43 = ALTER USER (alter user see below)
#
#                 To enable failed logon attemps audit:
#                    audit all by access whenever not successful;
#
#                 To enable alter user audit:
#                    audit ALTER USER by ACCESS WHENEVER SUCCESSFUL;
#
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        05/22/2006      v1.0 Created
#       VMOGILEV        05/24/2006      v1.1 fixed egrep string parse bugs
#					     changed FILE_LIST naming to fixed format
#					     moved CURR_FILE parser to the outer loop
#					     implemented dynamic SEARCH_STRING build
#	VMOGILEV			v1.2 added PREFIX to aud files and the list
#					     to enable multiple thresholds per this event
#					     (See PREFIX for further notes on this)
#


chkfile=$1
outfile=$2
clrfile=$3

WHOAMI=$$.`basename $0`
FILES_TO_CHK=/tmp/$WHOAMI.FILES_TO_CHK
TMP_CHK_OUT=/tmp/$WHOAMI.TMP_CHK_OUT

FILE_LIST=static_name.FILE_LIST.aud

##AUD_LOCATION=/u01/app/oracle/admin/TUTOR/audit
##AUD_LOCATION=`sqlplus -s system/manager <<EOF
AUD_LOCATION=`sqlplus -s $MON__CONNECT_STRING <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set feed off
set pages 0
set trims on
select value
from v\\$parameter p
where name = 'audit_file_dest';
exit
EOF
`

if [ $? -gt 0 ]; then
	echo "ERROR GETTING AUDIT LOG LOCATION!"
	echo $AUD_LOCATION
	exit 1
fi


## We need PREFIX to enable parsing of the same file
## by multiple thresholds of this event.
##
## Here's why:
##
## logmine.sh will make a BASE copy of each aud file that will be 
## checked against by each subsequent run ... so we need to PREFIX 
## that copy with the search string variables to make sure that
## we compare apples to apples by creating a UNIQUE copy of
## each audit file for each SEARCH_STRING combo
##
if [ ! "$PARAM__SEARCH_STRING" ]; then
	SEARCH_STRING="ACTION: \"100\"|ACTION: \"43\""
	PREFIX=default
else
	for i in $PARAM__SEARCH_STRING
	do
		SEARCH_STRING="${SEARCH_STRING}|ACTION: \"$i\""
		PREFIX="$i.${PREFIX}"
	done
fi

FILE_LIST=/tmp/${PREFIX}.${FILE_LIST}
ls -l $AUD_LOCATION > $FILE_LIST


$SYS_TOP/bin/logmine.sh $FILE_LIST ".aud" > $FILES_TO_CHK
echo "-- `date` --

       The following new/changed AUDIT files were detected:

" > $outfile

cat $FILES_TO_CHK >> $outfile
echo "
-- `date` --

       The following AUDIT files matched AUDIT string:
       AUDIT STRING: ${SEARCH_STRING}

" >> $outfile

for i in `cat $FILES_TO_CHK |  awk '{ print $9 }'`
do
	BASE_FILE=$i
	CURR_FILE=$AUD_LOCATION/$BASE_FILE
	PREF_FILE=/tmp/${PREFIX}.$BASE_FILE
	cp -p $CURR_FILE $PREF_FILE
	$SYS_TOP/bin/logmine.sh $PREF_FILE "$SEARCH_STRING" > $TMP_CHK_OUT
	rm -f $PREF_FILE
	if [ `cat $TMP_CHK_OUT | wc -l` -gt 0 ];
	then
		echo "$BASE_FILE" >> $chkfile
		echo "-------- $CURR_FILE --------" >> $outfile
		cat $CURR_FILE >> $outfile
	fi
done

if [ `cat $chkfile | wc -l` -gt 0 ]; then
	echo "$SEARCH_STRING" >> $chkfile
fi

## cleanup
##
rm -f $FILES_TO_CHK
rm -f $TMP_CHK_OUT

