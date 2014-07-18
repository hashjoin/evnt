#!/bin/ksh
#
# File:
#       tbwaste.sh
# EVNT_REG:	TAB_WASTAGE SEEDMON 1.1
# <EVNT_NAME>Table Fragmentation</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Checks for tables with high number of free list blocks, reporting
# wasted number of kbytes, initial and next extents, number of rows,
# number of empty blocks.  Only accurate if statistics are up-to-date.
# 
# 
# REPORT ATTRIBUTES:
# -----------------------------
# owner
# table_name
# blocks
# num_freelist_blocks
# empty_blocks
# percent ratio of free list blocks
# num_rows
# 
# 
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  --------
# FREE_LIST_PCT   Threshold for the percent ratio of free list blocks  50
#                 to blocks in DBA_TABLES.  DEFAULT=30
# 
# MIN_BLOCKS      Threshold for minimum number of blocks in a table    2000
#                 that will be checked by this event. DEFAULT=1000
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        09/06/2002      Created
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__MIN_BLOCKS" ]; then
	PARAM__MIN_BLOCKS=1000
fi

if [ ! "$PARAM__FREE_LIST_PCT" ]; then
	PARAM__FREE_LIST_PCT=30
fi

sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $chkfile
SELECT owner
||','||table_name
||','||blocks
||','||num_freelist_blocks
||','||empty_blocks
||','||TRUNC(((num_freelist_blocks*100)/blocks))
||','||num_rows
FROM dba_tables
WHERE ((num_freelist_blocks*100)/blocks) > $PARAM__FREE_LIST_PCT
AND   blocks > $PARAM__MIN_BLOCKS
AND   owner != 'SYS'
ORDER BY owner
,        table_name
/
spool off
exit
CHK

## check for errors
##
if [ $? -gt 0 ]; then
        cat $chkfile.err
        rm $chkfile.err
        exit 1;
fi


## if I got here remove error chk file
##
rm $chkfile.err


if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi

sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
spool $outfile
set lines 300
set trims on
col owner                 format a10 trunc
col table_name            format a30 trunc
col blocks                format 999999999 heading "Blocks"
col freelist_blocks       format 999999999 heading "FreeList|Blocks"
col freelist_block_ratio  format 999 heading "%|FreeList|Blocks"
col num_rows              format 999999999 heading "Num Rows"
col empty_blocks          format 999999999 heading "Empty|Blocks"
col last_analyzed                          heading "Last Analyzed"

col freelist_blocks_kbytes  format 999999999 heading "KB|FreeList"
col empty_blocks_kbytes     format 999999999 heading "KB|Empty"

col total_wasted_kb       format 999999999 heading "KB|Wasted"
col total_seg_kb          format 999999999 heading "KB|Total"

SELECT /*+ ORDERED */
   t.owner
,  t.table_name
,  t.blocks
,  t.freelist_blocks
,  t.freelist_block_ratio
,  t.empty_blocks
,  t.freelist_blocks_kbytes
,  t.empty_blocks_kbytes
,  t.freelist_blocks_kbytes+
      t.empty_blocks_kbytes total_wasted_kb
,  s.bytes/1024 total_seg_kb
,  t.num_rows
,  t.last_analyzed
,  s.extents
,  s.initial_extent/1024 initial_kb
,  s.next_extent/1024 next_kb
FROM (SELECT t.owner
      ,      t.table_name
      ,      t.blocks
      ,      t.num_freelist_blocks freelist_blocks
      ,      TRUNC(((t.num_freelist_blocks*100)/t.blocks)) freelist_block_ratio
      ,      t.num_rows
      ,      t.empty_blocks
      ,      TO_CHAR(t.last_analyzed,'RRRR-MON-DD HH24:MI:SS') last_analyzed 
      ,      (p.value*t.num_freelist_blocks)/1024 freelist_blocks_kbytes
      ,      (p.value*t.empty_blocks)/1024 empty_blocks_kbytes
      FROM dba_tables t
      ,    v\$parameter p
      WHERE ((t.num_freelist_blocks*100)/t.blocks) > $PARAM__FREE_LIST_PCT
      AND   t.blocks > $PARAM__MIN_BLOCKS
      AND   t.owner != 'SYS'
      AND   p.name='db_block_size') t
,   dba_segments s
WHERE t.owner = s.owner
AND   t.table_name = s.segment_name
ORDER BY t.freelist_blocks_kbytes DESC
,        t.freelist_block_ratio DESC
/
spool off
exit
CHK

## check for errors
##
if [ $? -gt 0 ]; then
        cat $outfile.err
        rm $outfile.err
        exit 1;
fi

## if I got here remove error chk file
##
rm $outfile.err


