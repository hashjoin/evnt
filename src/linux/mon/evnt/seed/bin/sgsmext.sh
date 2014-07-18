#!/bin/ksh
#
# File:
#       sgsmext.sh
# EVNT_REG:	MAXEXT_LIMIT SEEDMON 1.2
# <EVNT_NAME>Maxextents Limit</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports Segments Reaching Maximum Number of Extents
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
# next_extent
# pct_increase
# 
# 
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# MAXEXT_LIMIT    < dba_segments.MAX_EXTENTS - EXTENTS    20
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        06/25/2002      Created
#       VMOGILEV        10/21/2013      Added alter session set recyclebin=off;
#


chkfile=$1
outfile=$2
clrfile=$3

sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
alter session set recyclebin=off;
DROP TABLE evnt_sgsmext_temp_$MON__EA_ID;

WHENEVER SQLERROR EXIT FAILURE

CREATE TABLE evnt_sgsmext_temp_$MON__EA_ID
STORAGE(
   INITIAL 5m
   NEXT 5M
   PCTINCREASE 0
)
AS
SELECT
   owner
,  segment_name
,  segment_type
,  tablespace_name
,  bytes
,  extents
,  max_extents
,  initial_extent
,  next_extent
,  pct_increase
FROM dba_segments
WHERE MAX_EXTENTS - EXTENTS < $PARAM__EXTTRES
AND   MAX_EXTENTS > 0
ORDER BY owner
,        segment_name
,        segment_type
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
||','||next_extent
||','||pct_increase
FROM evnt_sgsmext_temp_$MON__EA_ID
ORDER BY owner
,        segment_name
,        segment_type
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
col segment_name    format a45
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
FROM evnt_sgsmext_temp_$MON__EA_ID stmp
,    (select    sum(bytes)/1024 Kbytes_free
      ,         max(bytes)/1024 largest
      ,         tablespace_name
      from      dba_free_space
      group by tablespace_name)  fr
WHERE stmp.tablespace_name = fr.tablespace_name(+)
ORDER BY stmp.segment_type, stmp.owner||'.'||stmp.segment_name, extents DESC
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

