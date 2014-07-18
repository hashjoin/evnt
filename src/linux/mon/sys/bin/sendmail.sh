#!/bin/ksh
#
# $Header sendmail.sh 03/13/2003 1.3
#
# File:
#	sendmail.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV
#
# Usage:
#	sendmail.sh TO_ADDR SUBJECT MESSAGE_FILE <ATTACH_FILE>
#
# Desc:
#	calls sendmail directly using <ATTACH_FILE> as
#	message body. 
#
# History:
#	13-MAR-2003	VMOGILEV	(1.1) Created
#	01-APR-2003	VMOGILEV	(1.2) removed "-f" switch, now build
#					      local version of sendmail message
#					      using sendmail flags
#	02-APR-2003	VMOGILEV	(1.3) added support for uuencode attachments
#

usage() {
echo "`basename $0` TO_ADDR SUBJECT MESSAGE_FILE <ATTACH_FILE>"
exit 1;
}

if [ $# -lt 3 ]; then
	usage;
fi

INFILE=$SHARE_TOP/tmp/sendmail.$$.in


TO_ADDR="$1"
SUBJECT="$2"
MESSAGE="$3"

if [ ! -f $MESSAGE ]; then
	echo "invalid message file: $MESSAGE"
	exit 1;
fi

ATTACH="$4"

if [ "$ATTACH" ]; then
	if [ -f $ATTACH ]; then
		BASEATTACH=`basename ${ATTACH}`
	else
		echo "invalid attach file: $ATTACH"
		exit 1;
	fi
fi


chk_err() {
ECODE=$1
EMESS="$2"

if [ $ECODE -gt 0 ]; then
        echo "$EMESS"
        exit 1;
fi

## END chk_err
}


prep_msg() {

echo "Reply-to: ${replyto}
From: ${replyto}
To: ${TO_ADDR}
Subject: ${SUBJECT}

" > $INFILE
cat ${MESSAGE} >> $INFILE
chk_err $? "error: can't cat message file: ${MESSAGE}"

cat ${INFILE}
chk_err $? "error: can't cat infile: ${INFILE}"

if [ "$ATTACH" ]; then
	uuencode ${ATTACH} ${BASEATTACH}
	chk_err $? "error: can't encode attachment file: ${ATTACH}"
fi

## end prep_msg
}


prep_msg | $sendmail_cmd "${TO_ADDR}"
chk_err $? "error calling SENDMAIL [$sendmail_cmd]"

rm -f $INFILE

