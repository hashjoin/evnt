#!/bin/ksh
#
# $Header evntmaint.sh 03/10/2003 1.1
#
# File:
#	evntmaint.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	evntmaint.sh E_FILE_NAME E_CODE E_CODE_BASE username/password@REPDB <E_COLL_FLAG>
#
# Desc:
#	Handles EVENT maintenance - registration and updates
#
# to build script to refresh all events:
#
#   SELECT '$SYS_TOP/bin/evntmaint.sh '||e_file_name
#          ||' '||e_code
#          ||' '||e_code_base
#          ||' <rep_owner>/<password> '
#          ||E_COLL_FLAG
#   FROM events;
#
# History:
#	10-MAR-2003	VMOGILEV	Created
# 

usage()
{
echo `basename $0` " E_FILE_NAME E_CODE E_CODE_BASE username/password@REPDB <E_COLL_FLAG>"
exit 1;
}

if [ "$1" ]; then
	E_FILE_NAME=$1
	SEVNT_FILE=`basename $E_FILE_NAME`
else
	usage;
fi

if [ "$2" ]; then
	E_CODE="$2"
else
	usage;
fi

if [ "$3" ]; then
	E_CODE_BASE="$3"
else
	usage;
fi

if [ "$4" ]; then
        uname_passwd="$4"; export uname_passwd
else
        usage;
fi

if [ "$5" ]; then
        E_COLL_FLAG="$5"; export E_COLL_FLAG
else
	E_COLL_FLAG="N"; export E_COLL_FLAG
fi


insert()
{
echo "
INSERT INTO events(
   e_id
,  date_created
,  date_modified
,  modified_by
,  created_by
,  e_code
,  e_name
,  e_code_base
,  e_file_name
,  E_COLL_FLAG
,  e_desc)
VALUES (
   events_S.NEXTVAL
,  SYSDATE
,  NULL
,  NULL
,  'EVNT_INTERFACE'
,  '$E_CODE'
,  '$E_NAME'
,  '$E_CODE_BASE'
,  '$SEVNT_FILE'
,  '$E_COLL_FLAG'
,  LTRIM(LTRIM(LTRIM(RTRIM('" > $evnt_loadfile
#,  LTRIM(REPLACE(LTRIM(LTRIM(RTRIM('" > $evnt_loadfile

awk '/<EVNT_DESC>/, /<\/EVNT_DESC>/' $E_FILE_NAME |
   sed 's/.*<EVNT_DESC>//' |
   sed 's/<\/EVNT_DESC>.*//' |
   sed '/^ $/d' |
   sed '/^$/d' |
   sed s/\'/\'\'/g |
   sed s/^\#/\-\-/g |
   sed s/^\#\ /\-\-/g |
   sed 's/;//g' >> $evnt_loadfile
echo "')),chr(10))) ); " >> $evnt_loadfile
#echo "')),chr(10)),'-- ')) ); " >> $evnt_loadfile

}

update()
{
echo "
UPDATE events
SET date_modified = SYSDATE
,   modified_by   = 'EVNT_INTERFACE'
,  e_name = '$E_NAME'
,  E_COLL_FLAG = '$E_COLL_FLAG'
,  e_code_base = '${E_CODE_BASE}'
,   e_desc        = LTRIM(LTRIM(LTRIM(RTRIM('" > $evnt_loadfile
#,   e_desc        = LTRIM(REPLACE(LTRIM(LTRIM(RTRIM('" > $evnt_loadfile

awk '/<EVNT_DESC>/, /<\/EVNT_DESC>/' $E_FILE_NAME |
   sed 's/.*<EVNT_DESC>//' |
   sed 's/<\/EVNT_DESC>.*//' |
   sed '/^ $/d' |
   sed '/^$/d' |
   sed s/\'/\'\'/g |
   sed s/^\#/\-\-/g |
   sed s/^\#\ /\-\-/g |
   sed 's/;//g' >> $evnt_loadfile
echo "')),chr(10))) " >> $evnt_loadfile
#echo "')),chr(10)),'-- ')) " >> $evnt_loadfile

echo "WHERE e_id = $e_id ; " >> $evnt_loadfile

}


echo "PROCESSING EVENT FILE: $E_FILE_NAME ..."

evnt_loadfile=$SHARE_TOP/tmp/evnt_loadfile.$SEVNT_FILE.sql

echo "checking if this event is already registered ..."

e_id=`sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set feed off
set pages 0
set trims on
SELECT TO_CHAR(e_id)
FROM events
WHERE e_code_base like '%${E_CODE_BASE}'
AND e_file_name='$SEVNT_FILE'
/
exit
EOF
`

E_NAME=`awk '/<EVNT_NAME>/, /<\/EVNT_NAME>/' $E_FILE_NAME |
   sed 's/.*<EVNT_NAME>//' |
   sed 's/<\/EVNT_NAME>.*//'`

if [ "$e_id" ]; then
   echo "event is registered update ..."
   update;
else
   echo "new event insert ..."
   insert;
fi

echo "Done!"

cat $evnt_loadfile

sqlplus -s $uname_passwd <<EOF
set scan off
@$evnt_loadfile
commit;
exit
EOF

