#!/bin/ksh
#
# File:
#       sgstop50.sh
# EVNT_REG:	HIGH_EXTENTS SEEDMON 1.3
# <EVNT_NAME>Large Segments</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports large segments (High Number of Extents OR size)
# (extents > <EXTTRES> OR bytes/1024/1024 > <MBTRES>)
# 
# REPORT ATTRIBUTES:
# -----------------------------
# owner
# segment_name
# segment_type
# tablespace_name
# bytes
# extents
# max_extents
# initial_extent
# nvl(next_extent,0)  [for 9i LOBSEGMENT issue]
# nvl(pct_increase,0) [for 9i LOBSEGMENT issue]
# 
# 
# 
# PARAMETER       DESCRIPTION                        EXAMPLE
# --------------  ---------------------------------  ---------------------
# EXTTRES         < dba_segments.extents             50
#                 DEFAULT=50 (extents)
#
# MBTRES          < dba_segments.bytes/1024/1024     200
#                 DEFAULT=200 (MB)
#
# EXCLUDE_LIST    NOT IN dba_segments.owner          'SYS', 'SYSTEM'
#                                                    (can be NULL)
#
# SEGTYPE         LIKE dba_segments.segment_type     TABLE% (can be NULL)
#
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        06/24/2002      Created
#       VMOGILEV        02/20/2003	added MBTRES parameter
#					made EXTTRES + EXCLUDE_LIST
#					optional with default values
#	VMOGILEV	01/22/2004	(1.2) added nvl(pct_increase,0)
#					            nvl(next_extent,0)
#       VMOGILEV        10/21/2013      (1.3) Added alter session set recyclebin=off;
#


chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__MBTRES" ]; then
        echo "using default MBTRES parameter: 200mb "
        PARAM__MBTRES=200
fi

if [ ! "$PARAM__EXTTRES" ]; then
        echo "using default EXTTRES parameter: 50 extents "
        PARAM__EXTTRES=50
fi

if [ ! "$PARAM__EXCLUDE_LIST" ]; then
        echo "using default EXCLUDE_LIST parameter: 'no_exclusion' "
        PARAM__EXCLUDE_LIST="'no_exclusion'"
fi


sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
alter session set recyclebin=off;
DROP TABLE evnt_sgstop50_temp_$MON__EA_ID;

WHENEVER SQLERROR EXIT FAILURE

CREATE TABLE evnt_sgstop50_temp_$MON__EA_ID
STORAGE(
   INITIAL 5M
   NEXT 5M
   PCTINCREASE 0
)
AS
SELECT
   owner
,  DECODE(INSTR(segment_type,'PARTITION'),
          0,segment_name,
            segment_name||' '||partition_name) segment_name
,  segment_type
,  tablespace_name
,  bytes
,  extents
,  max_extents
,  initial_extent
,  next_extent
,  pct_increase
FROM dba_segments
WHERE owner NOT IN ( $PARAM__EXCLUDE_LIST )
AND   (extents > ${PARAM__EXTTRES} OR bytes/1024/1024 > ${PARAM__MBTRES})
AND   segment_type like '${PARAM__SEGTYPE}%'
ORDER BY owner
,        segment_type
,        segment_name
,        tablespace_name
/

set lines 2000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $chkfile
SELECT 
       owner
||','||segment_name
||','||segment_type
||','||tablespace_name
||','||bytes
||','||extents
||','||max_extents
||','||initial_extent
||','||nvl(next_extent,0)
||','||nvl(pct_increase,0)
FROM evnt_sgstop50_temp_$MON__EA_ID
ORDER BY owner
,        segment_type
,        segment_name
,        tablespace_name
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
set lines 200
set trims on
set pages 60
col owner           format a10
col segment_name    format a55 trunc heading "Segment Name"
col Kbytes_free     format 9999999 heading "KB|Free"
col largest         format 9999999 heading "KB|Largest"
col KB_Initial      format 999999  heading "KB|Init"
col KB_next         format 999999  heading "KB|Next"
col extents         format 999999  heading "NO|Ext"
col max_extents     format 999999  heading "MAX|Ext"
col pct_increase    format 999 heading "%|Inc"
col tablespace_name format a10 trunc heading "TS Name"
col segment_type    format a7  trunc heading "Seg Type"

SELECT /*+ ORDERED */
       stmp.segment_type
,      stmp.tablespace_name
,      fr.Kbytes_free
,      fr.largest
,      stmp.owner||'.'||stmp.segment_name segment_name
,      trunc(stmp.bytes/1024/1024) mbytes
,      stmp.extents
,      stmp.max_extents
,      stmp.initial_extent/1024 KB_Initial
,      stmp.next_extent/1024 KB_next
,      stmp.pct_increase
FROM evnt_sgstop50_temp_$MON__EA_ID stmp
,    (select    sum(bytes)/1024 Kbytes_free
      ,         max(bytes)/1024 largest
      ,         tablespace_name
      from      dba_free_space
      group by tablespace_name)  fr
WHERE stmp.tablespace_name = fr.tablespace_name(+)
ORDER BY stmp.segment_type, stmp.owner||'.'||stmp.segment_name
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

