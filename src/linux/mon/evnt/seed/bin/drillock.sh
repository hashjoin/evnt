#!/bin/ksh
#
# $Header drillock.sh 11/18/2013 1.1
#
# File:
#       drillock.sh
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV (dbatoolz.com)
#
# Purpose:
#       Drill script to v$session* and locks
#
# Usage:
#       drillock.sh <sid_list_comma_sep_file>
#
# History:
#       VMOGILEV        11/18/2013      v1.0	Created
#       VMOGILEV        11/18/2013      v1.1	Added outfile.local


sesfile=$1
outfile=$2

if [ `grep "enq: TX" $sesfile | wc -l` -gt 0 ]; then
	echo "found locks drilling into it ..."
else
	echo "no locks found - exiting ..."
	exit 0;
fi


sqlplus -s $MON__CONNECT_STRING <<CHK > $outfile.local
WHENEVER SQLERROR EXIT FAILURE

set serveroutput on size unlimited
variable l_lock_batch_id number;
variable l_sess_batch_id number;
begin
    mon_refresh_proc( p_table_name  => 'GV_LOCK_MON', p_max_lag => 25, p_max_batches => 8, p_batch_id => :l_lock_batch_id );
    mon_refresh_proc( p_table_name  => 'GV_SESSION',  p_max_lag => 25, p_max_batches => 8, p_batch_id => :l_sess_batch_id );
end;
/
print :l_lock_batch_id;
print :l_sess_batch_id;
select
       table_name
,      to_char(refreshed_date,'yyyy-mon-yy hh24:mi:ss') refreshed_date
,      batch_id
from mon_refresh_q;

spool $outfile

prompt Current locks:
prompt ~~~~~~~~~~~~~~~
set pages 80
clear col
clear breaks
ttit off
set lines 132
@$EVNT_TOP/seed/sql/s_locked_obj.sql :l_lock_batch_id :l_sess_batch_id

spool off

-- commit to release the lock on mon_refresh_q
commit;
exit
CHK

if [ $? -gt 0 ]; then
	cat $outfile.local >> $outfile
	exit 1;
fi

rm -f $outfile.local

