#!/bin/ksh
#
# $Header evntlistl.sh 04/04/2003 1.7
#
# File:
#	evntlistl.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV www.dbatoolz.com
#
# Usage:
#	evntlistl.sh <list_file> <error_file>
#
# Desc:
#	Builds list of LOCAL pending EVENTS to process
#
# History:
#	26-SEP-2002	VMOGILEV	1.1 Created
#	26-MAR-2003	VMOGILEV	1.2 enabled max proc check
#	27-MAR-2003	VMOGILEV	1.3 switched to scheduling thru PKG
#	28-MAR-2003	VMOGILEV	1.4 switched to glob_pend_assignments
#	03-APR-2003	VMOGILEV	1.5 changed grep to EVNT
#	03-APR-2003	VMOGILEV	1.6 added bgman.sh filter
#	04-APR-2003	VMOGILEV	1.7 switched to pid file from ps lookup
#

spoolfile=$1
errorfile=$2

APROC=`find $SHARE_TOP/wrk -name "EVNT*pid" | wc -l`
NPROC=$(($evnt_max_proc-$APROC));

echo "   APROC=$APROC NPROC=$NPROC "

sqlplus -s $uname_passwd <<EOF > $errorfile
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

BEGIN
   glob_util_pkg.set_pend(
      p_type => 'EVNT'
   ,  p_max_proc => ${NPROC});
END;
/

commit;


set feed off
set pages 0
set trims on

SELECT gpa_val
FROM glob_pend_assignments
ORDER BY gpa_seq


spool $spoolfile
/
spool off

exit
EOF

if [ $? -gt 0 ]; then
	exit 1;
fi

