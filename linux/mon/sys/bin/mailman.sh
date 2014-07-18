#!/bin/ksh
#
# $Header mailman.sh 06/11/2002 1.1
#
# File:
#	mailman.sh
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV (www.dbatoolz.com)
#
# Purpose:
#       Process all pending mail by calling generating
#	mailall.sh that calls mailsub.sh
#
# Usage:
#       mailman.sh
#       (called from mailbg.sh)
#
# History:
#       VMOGILEV        06/11/2002      Created
#	VMOGILEV	10/10/2002	removed parsing with awk
#					it's all done in evnt_util_pkg
#	VMOGILEV	10/21/2002	get_pending_mail call changed
#


trigger_list_file=$SHARE_TOP/tmp/trg.list
mail_list_file=$SHARE_TOP/tmp/mail.list; export mail_list_file
mail_grp_sub=$SYS_TOP/bin/mailsub.sh; export mail_grp_sub
mail_grp_all=$SYS_TOP/bin/mailall.sh

echo `date` " GETTING PENDING MAIL"
sqlplus -s $uname_passwd <<EOF > /dev/null
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
VARIABLE out_ref_id NUMBER
BEGIN
   evnt_util_pkg.get_pending_mail($ack_notif_freq, $ack_notif_tres, :out_ref_id);
END;
/
set trims on
set feed off
set pages 0
set lines 4000
spool $trigger_list_file
SELECT eupo_out
FROM EVNT_UTIL_PKG_OUT
WHERE eupo_ref_id = :out_ref_id
AND   eupo_ref_type = 'MAILPEND_TRG'
order by eupo_ref_type
,        eupo_ref_id
,        eupo_id;
spool off
spool $mail_list_file
SELECT eupo_out
FROM EVNT_UTIL_PKG_OUT
WHERE eupo_ref_id = :out_ref_id
AND   eupo_ref_type = 'MAILPEND_PGL'
order by eupo_ref_type
,        eupo_ref_id
,        eupo_id;
spool off
spool $mail_list_file.HOLD
SELECT eupo_out
FROM EVNT_UTIL_PKG_OUT
WHERE eupo_ref_id = :out_ref_id
AND   eupo_ref_type = 'MAILPEND_PGL_HOLD'
order by eupo_ref_type
,        eupo_ref_id
,        eupo_id;
spool off
exit
EOF

if [ $? -gt 0 ]; then
        echo `date` " ERROR: getting pending mail"
        exit 1 ;
fi


echo `date` " SENDING PENDING MAIL"

if [ -f $mail_list_file.sql ]; then
	rm $mail_list_file.sql
fi

mv $trigger_list_file $mail_grp_all
chmod +x $mail_grp_all
$mail_grp_all

echo `date` " UPDATING PENDING STATUS"
sqlplus -s $uname_passwd <<EOF > /dev/null
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set feed on
set echo on
set pages 0
set lines 4000
set trims on
spool $mail_list_file.sql.log
@$mail_list_file.sql
spool off
commit;
exit
EOF


if [ $? -gt 0 ]; then
        echo `date` " ERROR: updating pending status"
        exit 1 ;
fi
echo "LIST OF pages that were on HOLD: "
echo "-------------------------------"
cat $mail_list_file.HOLD
echo `date` " DONE"

