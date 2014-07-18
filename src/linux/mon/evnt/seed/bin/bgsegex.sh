#!/bin/ksh
#
# File:
#       bgsegex.sh
# EVNT_REG:	DB_SEGEX SEEDMON 1.3 Y
# <EVNT_NAME>Fast Growing Segments</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports database segments that have extended by a number of extents
# (predefined threshold).
#
# REQUIRES COLLECTION from dba_segments.  Makes comparison
# of previous and current snapshots from dba_segments.
#
#
# REPORT ATTRIBUTES:
# -----------------------------
# owner
# segment_type
# segment_name
# tablespace_name
# bytes/1024 beg_kbytes
# bytes/1024 end_kbytes
# extents beg_extents
# extents end_extents
# next_extent
# pct_increase
#
#
# PARAMETER       DESCRIPTION                                         EXAMPLE
# --------------  --------------------------------------------------  ------------
# EXT_GROWTH      curr_snap.extents - prev_snap.extents threshold     2
#                 triggers when <EXT_GROWTH> is >= diff of the above
#                 DEFAULT=1 (extents)
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        12/17/2002      Created
#       VMOGILEV        01/28/2003      Made compatible with 1.8.1
#       VMOGILEV        02/05/2003      (1.2) 
#					put outerjoin to prev snp
#                                       to allow for new segs to show up
#       VMOGILEV        02/28/2003      (1.3) 
#					changed > to >= for the thres
#


chkfile=$1
outfile=$2
clrfile=$3

if [ "$PARAM__EXT_GROWTH" ]; then
	EXT_GROWTH="$PARAM__EXT_GROWTH"
else
	echo "using default value (1 extents) for EXT_GROWTH ..."
	EXT_GROWTH="1"
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
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
set lines 2000

--
-- call collection parser
-- to get curr/prev table names
--
@$EVNT_TOP/seed/sql/getsnp.sql $COLL_CODE $MON__S_ID $CA_ID

set verify off

spool $chkfile

SELECT e.owner
||','||e.segment_type
||','||e.segment_name
||','||e.tablespace_name
||','||NVL(b.bytes,0)/1024
||','||e.bytes/1024
||','||NVL(b.extents,0)
||','||e.extents
||','||e.next_extent
||','||e.pct_increase
FROM &&X_out_psnp b
,    &&X_out_csnp e
WHERE e.owner = b.owner(+)
AND   e.segment_type = b.segment_type(+)
AND   e.segment_name = b.segment_name(+)
AND   (e.extents - NVL(b.extents,0)) >= $EXT_GROWTH
ORDER BY e.owner
,        e.segment_type
,        e.segment_name
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

