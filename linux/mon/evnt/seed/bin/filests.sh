#!/bin/ksh
#
# File:
#       filests.sh
# EVNT_REG:	DB_FILE_IO SEEDMON 1.2 Y
# <EVNT_NAME>Slow Io Ratio (DBF)</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports data files with high AVG read/write times.
#
# REQUIRES COLLECTION from v$filestat.  Makes comparison
# of previous and current snapshots from v$filestat.
#
#
# REPORT ATTRIBUTES:
# -----------------------------
# tablespace_name
# file_name
# avg_rdt
#
#
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  ------------
# AVG_IOTIME      (milliseconds) event is triggered if diff of        30
#                 curr-prev snapshots values of avg read time 
#                 exceeds <AVG_IOTIME>
#                 DEFAULT=20
#
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        12/20/2002      Created
#       VMOGILEV        01/28/2002      Made compatible with 1.8.1
#       VMOGILEV        01/29/2002      fixed bug with 1/100 sec vs Ms (see SR# 50)
#                                       only check read times write times are
#                                       all over the place anywhere from 0-300 ms
#       VMOGILEV        10/21/2013      Added alter session set recyclebin=off;
#


chkfile=$1
outfile=$2
clrfile=$3

if [ "$PARAM__AVG_IOTIME" ]; then
	AVG_IOTIME="$PARAM__AVG_IOTIME"
else
	echo "using default value (20 msec) for AVG_IOTIME ..."
	AVG_IOTIME="20"
fi

if [ "$CA_ID" ]; then
        echo "CA_ID=${CA_ID}"
else
        echo "CA_ID is not set, exiting ..."
        exit 1;
fi

if [ "$PARAM__cp_code" ]; then
        COLL_CODE="$PARAM__cp_code"
else
        echo "PARAM__cp_code is not set, exiting ..."
        exit 1;
fi


sqlplus -s $uname_passwd <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set lines 2000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off

alter session set recyclebin=off;

--
-- call collection parser
-- to get curr/prev table names
--
@$EVNT_TOP/seed/sql/getsnp.sql $COLL_CODE $MON__S_ID $CA_ID

spool $chkfile

SELECT tablespace_name
||','||file_name
||','||ROUND(phys_rd_time/DECODE(phys_reads,0,1,phys_reads),3)
FROM(
select b.tablespace_name,
       b.file_name,
       e.pyr-b.pyr phys_reads,
       e.pbr-b.pbr phys_blks_rd,
       e.prt-b.prt phys_rd_time,
       e.pyw-b.pyw phys_writes,
       e.pbw-b.pbw phys_blks_wr,
       e.pwt-b.pwt phys_wrt_tim,
       e.file_size_kbytes
  from &&X_out_psnp b, &&X_out_csnp e
       where b.file_name=e.file_name)
WHERE phys_rd_time/DECODE(phys_reads,0,1,phys_reads) > $AVG_IOTIME
ORDER BY phys_rd_time/DECODE(phys_reads,0,1,phys_reads) DESC
/

spool off

-- since collection based events
-- depend on collection tables
-- we have to run report right from this session
-- to avoid commit and release of the lock from
-- collection bg process that might drop these tables

set verify off
set pages 60
set head on
set feed on

col tablespace_name format a10 trunc heading "TS Name"
col file_name format a35 trunc heading "File Name"
col avg_rdt format 9999.00 heading "AvgRDT"
col avg_wrt format 9999.00 heading "AvgWTT"
col phys_reads format 999999999 heading "PHYReads"
col phys_blks_rd format 999999999 heading "PHYBlkRead"
col phys_rd_time format 999999999 heading "PHYReadTime"
col phys_writes format 999999999 heading "PHYWrites"
col phys_blks_wr format 999999999 heading "PHYBlkWritten"
col phys_wrt_tim format 999999999 heading "PHYWriteTime"
col file_size_kbytes format 9999999999 heading "FileSizeKB"

spool $outfile

SELECT tablespace_name
,      file_name
,      ROUND(phys_rd_time/DECODE(phys_reads,0,1,phys_reads),2) avg_rdt
,      ROUND(phys_wrt_tim/DECODE(phys_writes,0,1,phys_writes),2) avg_wrt
,      phys_reads
,      phys_blks_rd
,      phys_rd_time
,      phys_writes
,      phys_blks_wr
,      phys_wrt_tim                        
,      file_size_kbytes
FROM(
select b.tablespace_name,
       b.file_name,
       e.pyr-b.pyr phys_reads,
       e.pbr-b.pbr phys_blks_rd,
       e.prt-b.prt phys_rd_time,
       e.pyw-b.pyw phys_writes,
       e.pbw-b.pbw phys_blks_wr,
       e.pwt-b.pwt phys_wrt_tim,
       e.file_size_kbytes
  from &&X_out_psnp b, &&X_out_csnp e
       where b.file_name=e.file_name)
WHERE phys_rd_time/DECODE(phys_reads,0,1,phys_reads) > $AVG_IOTIME
ORDER BY phys_rd_time/DECODE(phys_reads,0,1,phys_reads) DESC
/

spool off

commit;

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


