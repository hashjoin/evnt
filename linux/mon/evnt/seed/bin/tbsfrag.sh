#!/bin/ksh
#
# File:
#       tbsfrag.sh
# EVNT_REG:     TABSP_FRAG SEEDMON 1.2
# <EVNT_NAME>Tablespace Fragmentation</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy VMOGILEV (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Performs tablespace analysis looking for fragments of
# free space that are potentially wasted.  The goal here
# is to find free space fragments that are smaller then
# the next extent of "active" segments [segments that are
# either extending or are large].  Active segment list is
# built using collection from DBA_SEGMENTS that you can
# control using SEG% parameters (See below):
#
#      owner NOT IN ( <SEG_OWNER_EXCLD> ) AND
#      (extents > <SEG_EXTENTS> OR bytes/1024/1024 > <SEG_MBYTES>)
# 
# To fix this issue you have two options:
#    1. Reorganize tablespace.
#    2. Alter the <NEXT_EXTENT> of any of the 
#       active segments to fill up the space.
# 
# REPORT ATTRIBUTES:
# -----------------------------
# count of fragments
# fragment size (KB)
# total size [cnt*fragment_size](KB)
# tablespace name
# 
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------------
# FRAG_CNT        number of fragments threshold           30
#                 DEFAULT=10
# 
# TABSP_EXCLD     tablespace name list to exclude         'RBS','SYSTEM'
#                 used in NOT IN (<LIST>) should
#                 include single quotes and commas
#                 DEFAULT='RBS'
#
# SEG_OWNER_EXCLD owner list to exclude                   'SYS','SYSTEM'
#                 used in NOT IN (<LIST>) should
#                 include single quotes and commas
#                 DEFAULT='SYS','SYSTEM'
#
# SEG_EXTENTS     number of extents threshold             100
#                 DEFAULT=50
#
# SEG_MBYTES      segment's MB size threshold             500
#                 DEFAULT=200(mb)
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV	01-MAY-2003	1.1 Created
#       VMOGILEV	21-OCT-2013	1.2 Added alter session set recyclebin=off;
#

chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__FRAG_CNT" ]; then
	echo "using default FRAG_CNT = 10"
	PARAM__FRAG_CNT=10
fi

if [ ! "$PARAM__TABSP_EXCLD" ]; then
	echo "using default TABSP_EXCLD = 'no_exclusion'"
	PARAM__TABSP_EXCLD="'RBS'"
fi

if [ ! "$PARAM__SEG_OWNER_EXCLD" ]; then
	echo "using default SEG_OWNER_EXCLD = 'SYS','SYSTEM'"
	PARAM__SEG_OWNER_EXCLD="'SYS','SYSTEM'"
fi

if [ ! "$PARAM__SEG_EXTENTS" ]; then
	echo "using default SEG_EXTENTS = 50"
	PARAM__SEG_EXTENTS=50
fi

if [ ! "$PARAM__SEG_MBYTES" ]; then
	echo "using default SEG_MBYTES = 200 (mb)"
	PARAM__SEG_MBYTES=200
fi


## get trigger attributes
##
sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
alter session set recyclebin=off;

drop table evnt_tbsfrag_extmap;
drop table evnt_tbsfrag_fragmap;

WHENEVER SQLERROR EXIT FAILURE

create table evnt_tbsfrag_extmap
as
select OWNER,
       DECODE(INSTR(segment_type,'PARTITION'),
          0,segment_name,
            segment_name||' '||partition_name) segment_name,
       segment_type,
       extents, pct_increase, tablespace_name,
       next_extent
from dba_segments
WHERE owner NOT IN ( ${PARAM__SEG_OWNER_EXCLD} )
AND   (extents > ${PARAM__SEG_EXTENTS} OR bytes/1024/1024 > ${PARAM__SEG_MBYTES})
AND   tablespace_name NOT IN ( ${PARAM__TABSP_EXCLD} )
AND   segment_name NOT LIKE 'EVNT_SGS%TEMP%'
/

create table evnt_tbsfrag_fragmap
as
select f.cnt, f.bytes,
       f.tablespace_name
from (select count(*) cnt, bytes, tablespace_name
      from dba_free_space
      where tablespace_name NOT IN ( ${PARAM__TABSP_EXCLD} )
      group by tablespace_name, bytes
      having count(*) > ${PARAM__FRAG_CNT}) f
where NOT EXISTS (select 'x'
                  from evnt_tbsfrag_extmap m
                  where (f.bytes = m.next_extent OR m.next_extent < f.bytes)
                  and   f.tablespace_name = m.tablespace_name)
/


set lines 2000
set pages 0
set trims on
set head off
set feed off
set echo off
set verify off

select cnt
||','||bytes/1024
||','||cnt*bytes/1024
||','||tablespace_name
from evnt_tbsfrag_fragmap
order by tablespace_name

spool $chkfile
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


## check if attribute file has any output
## if not exit if yes continue with 
## getting trigger output
##
if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi


## get trigger output
##
sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET NLS_DATE_FORMAT='RRRR-MON-DD HH24:MI:SS';
spool $outfile

set trims on
col SEGMENT_NAME format a65 trunc heading "Segment"
col SEGMENT_type format a15 trunc heading "Seg Type"
col TABLESPACE_NAME format a15 trunc heading "TS Name"
col pct      format 999
col nkbytes  heading "Next Kb"
col fkbytes  heading "Fragment Kb"
col tfkbytes heading "Total Kb"
col cnt      heading "Number Of|Fragments"

set pages 55
set lines 60
ttit "Potentially wasted fragments of free space | [grouped by tablespace fragment]"
break on report
compute sum of tfkbytes on report


select cnt, bytes/1024 fkbytes,
       cnt*bytes/1024 tfkbytes,
       tablespace_name
from evnt_tbsfrag_fragmap
order by fkbytes desc
/

set lines 128
ttit "Segments that will not fit into space fragments | [they were used to create above projection]"
clear breaks
clear computes


select m.owner||'.'||m.SEGMENT_NAME SEGMENT_NAME,
       m.segment_type,
       m.EXTENTS , m.PCT_INCREASE pct,
       m.next_extent/1024 nkbytes,
       m.tablespace_name
from  evnt_tbsfrag_extmap m
where EXISTS (select 'x'
              from evnt_tbsfrag_fragmap f
              where f.tablespace_name = m.tablespace_name
              and   m.next_extent > f.bytes)
order by m.tablespace_name, m.owner, m.SEGMENT_NAME
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

