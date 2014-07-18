#!/bin/ksh
#
# $Header nevnt.sh 03/10/2003 1.1
#
# File:
#       nevnt.sh
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#       nevnt.sh
#
# Desc:
#       Handles new EVENT creation from a TEMPLATE.sh
#
# History:
#       02-OCT-2003     VMOGILEV        Created
#


CF=`basename $0`
TS=`date '+%m-%d-%Y'`

read_base() {
echo "
                       *** EVENT Creation Utility ***

This utility will make your custom EVENT script pluggable into the EVNT 
repository.  Special tags will be inserted into the beginning of your script 
using TEMPLATE.sh.  Your original script will be saved with .bak extension.

EVENT can be one of the following types:
   CUST - custom event located in ($CUSTMON)
   SEED - seeded event located in ($SEEDMON)
   APPS - apps event located in ($APPSMON)
   SIEB - siebel event located in ($SIEBMON)

WARNING:
   If you are a FusionCode customer and wish to create a new custom event you 
   should be using CUST type.  This is the only type of EVENT that is preserved 
   during FusionCode upgrades.  Events created using all other event types WILL 
   be overwritten by the FusionCode upgrade process.
"
read EBASE?"Enter EVENT Type: "
}

read_file() {
echo "
Based on the EVENT TYPE you've provided the following recent files can be added 
to the FusionCode repository:
"
if [ "$EBASE" = "CUSTMON" ]; then
	EBDIR=$CUSTMON
elif [ "$EBASE" = "SEEDMON" ]; then
	EBDIR=$SEEDMON
elif [ "$EBASE" = "APPSMON" ]; then
	EBDIR=$APPSMON
elif [ "$EBASE" = "SIEBMON" ]; then
	EBDIR=$SIEBMON
else
	echo "ERROR: EBASE is not set!"
	exit 1;
fi

ls -lat $EBDIR | head

read EFILE?"Enter your EVENT file: "
## convert filename to BASE/FILE format
## if not found in that location read again by while loop below ...
EFILE="${EBDIR}/`basename $EFILE`"
}

read_ecode() {
read ECODE?"Enter EVENT short code (no spaces example: DB_EVNT): "
}

read_autlong() {
read ALONG?"Enter Author's full name (can have spaces): "
}

read_autshort() {
read ASHORT?"Enter Author's short name (no spaces): "
}

read_aemail() {
read AEMAIL?"Enter Author's email address: "
}

read_remote() {
echo "
EVENT can be either LOCAL or REMOTE.  LOCAL events are processed by the 
management server, REMOTE events are processed directly on the remote host.
"
read EREMOTE?"Is this a remote EVENT (Y|N)?:"
}

unset DONE
while [ ! "$DONE" ]
do
	if [ "$EBASE" = "CUST" -o "$EBASE" = "SEED" -o "$EBASE" = "APPS" -o "$EBASE" = "SIEB" ]; then
		DONE="yes"
		EBASE="${EBASE}MON"
	else
		read_base
	fi
done

while [ ! -f "$EFILE" ]
do
	read_file
done

while [ `grep "EVNT_REG" "$EFILE" | wc -l` -gt 0 ]
do
	echo "ERROR: $EFILE script already has special tags"
	echo "please remove them or specify another script"
	exit 1
done

unset DONE
while [ ! "$DONE" ]
do
	if [ "$EREMOTE" = "Y" -o "$EREMOTE" = "y" ]; then
		DONE="yes"
		EBASE="*${EBASE}"
	elif [ "$EREMOTE" = "N" -o "$EREMOTE" = "n" ]; then
		DONE="yes"
	else
		read_remote
	fi
done

while [ ! "$ECODE" ]
do
	read_ecode
done

while [ ! "$ALONG" ]
do
	read_autlong
done

while [ ! "$ASHORT" ]
do
	read_autshort
done

while [ ! "$AEMAIL" ]
do
	read_aemail
done



NEFILE=`basename $EFILE`
TEFILE=$EFILE.tmp

# make backup just incase things go south
cp $EFILE $EFILE.bak

# parse TEMPLATE.sh into temp file
cat $SYS_TOP/bin/TEMPLATE.sh |
        sed 's/<event_file_name>/'$NEFILE'/g' |
        sed 's/<EVENT_CODE>/'$ECODE'/g' |
        sed 's/<BASENAME>/'$EBASE'/g' |
        sed 's/<VERSION>/1.1/g' |
        sed 's/<AUTHOR_LONG>/'"$ALONG"'/g' |
        sed 's/<AUTHOR_EMAIL>/'$AEMAIL'/g' |
        sed 's/<AUTHOR>/'$ASHORT'/g' |
        sed 's/<DATE>/'$TS'/g' > $TEFILE

# append EFILE file to temp file
cat $EFILE >> $TEFILE

# remove EFILE file now
rm $EFILE

# rename temp file to EFILE file
mv $TEFILE $EFILE
chmod +x $EFILE

##vi $EFILE
echo "Done!
"
ls -lta $EFILE*

