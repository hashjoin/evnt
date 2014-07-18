#!/bin/ksh
#
# $Header drilwait.sh 11/04/2003 1.3
#
# File:
#       drilspace.sh
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV (dbatoolz.com)
#
# Purpose:
#       Drill script to dba_hist_seg_stat
#
# Usage:
#       drilwait.sh <tsname_list_comma_sep_file>
#
# History:
#       VMOGILEV        11/04/2013      (1.0)	created
#       VMOGILEV        11/05/2013      (1.1)	added report since last DBF creation
#       VMOGILEV        11/22/2013      (1.2)	switched to awr_refresh_proc()
#       VMOGILEV        12/05/2013      (1.3)	increased sizes of obj and subobj colums


tsfile=$1
outfile=$2


##TS_LIST=`awk 'BEGIN { FS = "," } { if ( NR == 1 ) { printf("'%s'", $1) } if ( NR > 1 ) { printf(",'%s'", $1) } }' $tsfile`
TS_LIST=`awk 'BEGIN { FS = "," } { if ( NR == 1 ) { printf("'\''%s'\''", $1) } if ( NR > 1 ) { printf(",'\''%s'\''", $1) } }' $tsfile`

cat $tsfile

sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.tmp
WHENEVER SQLERROR EXIT FAILURE
--exec dbms_workload_repository.create_snapshot();
exec awr_refresh_proc(10);
spool $outfile

ttit "Fast Extending Segments in the last ${MON__EA_MIN_INTERVAL} minutes"

set lines 169
set pages 100
set trims on

col end_interval_time   format a26
col owner               format a20
col object_name         format a23
col subobject_name      format a27
col instance_number     format 999 heading "I#"
col mbytes              format 999999999999

break on report
compute sum of mbytes on report

select
   s.end_interval_time
,  h.INSTANCE_NUMBER
,  n.tablespace_name
,  n.owner
,  n.object_name
,  n.subobject_name
,  n.object_type
,  h.space_allocated_delta/1024/1024 mbytes
from dba_hist_seg_stat h,
     dba_hist_snapshot s,
     dba_hist_seg_stat_obj n
where h.snap_id = s.snap_id
  and h.INSTANCE_NUMBER = s.INSTANCE_NUMBER
  and h.dbid = s.dbid
  and h.ts# = n.ts#
  and h.dbid = n.dbid
  and h.dataobj# = n.dataobj#
  and h.obj# = n.obj#
  and n.tablespace_name in (${TS_LIST})
  and h.space_allocated_delta > 0
  and s.end_interval_time >= sysdate-${MON__EA_MIN_INTERVAL}/24/60
order by s.end_interval_time;

ttit "Fast Extending Segments since last added Datafile"

select
   s.end_interval_time
,  h.INSTANCE_NUMBER
,  n.tablespace_name
,  n.owner
,  n.object_name
,  n.subobject_name
,  n.object_type
,  h.space_allocated_delta/1024/1024 mbytes
from dba_hist_seg_stat h,
     dba_hist_snapshot s,
     dba_hist_seg_stat_obj n,
     (select max(creation_time) max_creation_time, ts# from v\$datafile group by ts#) d
where h.snap_id = s.snap_id
  and h.INSTANCE_NUMBER = s.INSTANCE_NUMBER
  and h.dbid = s.dbid
  and h.ts# = n.ts#
  and h.dbid = n.dbid
  and h.dataobj# = n.dataobj#
  and h.obj# = n.obj#
  and n.tablespace_name in (${TS_LIST})
  and h.space_allocated_delta > 0
  and s.end_interval_time >= d.max_creation_time
  and n.ts# = d.ts#
order by s.end_interval_time;


spool off
exit
CHK

if [ $? -gt 0 ]; then
	cat $outfile.tmp
	exit 1;
fi

rm -f $outfile.tmp

