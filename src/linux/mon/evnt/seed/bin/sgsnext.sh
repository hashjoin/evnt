#!/bin/ksh
#
# File:
#       sgsnext.sh
# EVNT_REG:	NEXTEXT_SIZE SEEDMON 1.3
# <EVNT_NAME>Next Extent Too Big</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports Segments with next_extent > MAX free tablesapce space
# 
# REPORT ATTRIBUTES:
# -----------------------------
# segment_type
# owner
# segment_name
# next_extent (KB)
# max_free_ts_space (KB)
# sum_free_ts_space (KB)
# tablespace_name
# 
# 
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        02/07/2003      Created
#       VMOGILEV        05/29/2003      1.2 changed >= to > for next_extent
#       VMOGILEV        10/21/2013      (1.3) Added alter session set recyclebin=off;
#


chkfile=$1
outfile=$2
clrfile=$3

sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err

alter session set recyclebin=off;

DROP TABLE evnt_sgsnext_temp_$MON__EA_ID
/
WHENEVER SQLERROR EXIT FAILURE
set lines 2000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
CREATE TABLE evnt_sgsnext_temp_$MON__EA_ID AS
SELECT
   tablespace_name
,  MAX(bytes) max_bytes
,  SUM(bytes) sum_bytes
FROM dba_free_space
GROUP BY tablespace_name
/

spool $chkfile
SELECT /*+ ORDERED */ 
       ds.segment_type
||','||ds.owner
||','||DECODE(INSTR(ds.segment_type,'PARTITION'),
          0,ds.segment_name,
            ds.segment_name||' '||ds.partition_name)
||','||ds.next_extent/1024
||','||dfs.max_bytes/1024
||','||dfs.sum_bytes/1024
||','||ds.tablespace_name
FROM dba_segments ds
,    evnt_sgsnext_temp_$MON__EA_ID dfs
WHERE next_extent > max_bytes
AND   ds.tablespace_name = dfs.tablespace_name
ORDER BY ds.owner
,        ds.segment_type
,        ds.segment_name
/
spool off
exit
CHK

if [ $? -gt 0 ]; then
	cat $chkfile.err
        rm $chkfile.err
	exit 1;
fi

rm $chkfile.err


if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi

sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET NLS_DATE_FORMAT='RRRR-MON-DD HH24:MI:SS';
spool $outfile
set lines 250
set pages 60
set trims on

col owner format a10 trunc heading "Owner"
col segment_type format a17 trunc heading "SEG Type"
col segment_name format a55 trunc heading "SEG Name"
col extents heading "Extents"
col tot_seg_kb heading "Tot Kb"
col pct_increase format 999 heading "Pct|Inc"
col next_extent_kb heading "Next KB"
col max_kbytes heading "TS MaxF Kb"
col sum_kbytes heading "TS TotF Kb"
col tablespace_name format a20 trunc heading "Tablespace"


SELECT /*+ ORDERED */
   ds.owner
,  ds.segment_type
,  DECODE(INSTR(ds.segment_type,'PARTITION'),
          0,ds.segment_name,
            ds.segment_name||' '||ds.partition_name) segment_name
,  ds.extents
,  ds.bytes/1024 tot_seg_kb
,  ds.pct_increase
,  ds.next_extent/1024 next_extent_kb
,  dfs.max_bytes/1024 max_kbytes
,  dfs.sum_bytes/1024 sum_kbytes
,  ds.tablespace_name
FROM dba_segments ds
,    evnt_sgsnext_temp_$MON__EA_ID dfs
WHERE next_extent > max_bytes
AND   ds.tablespace_name = dfs.tablespace_name
ORDER BY ds.owner
,        ds.segment_type
,        ds.segment_name
/

spool off
exit
CHK

if [ $? -gt 0 ]; then
        cat $outfile.err
        rm $outfile.err
        exit 1;
fi

rm $outfile.err

