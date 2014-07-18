#!/bin/ksh
#
# File:
#       dbinvob.sh
# EVNT_REG:	INVALID_OBJ SEEDMON 1.1
# <EVNT_NAME>Invalid Objects</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports invalid objects
# 
# REPORT ATTRIBUTES:
# -----------------------------
# owner
# object_type
# object_name
# status
# 
# 
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        02/07/2003      Created
#


chkfile=$1
outfile=$2
clrfile=$3

sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
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
||','||object_type
||','||object_name
||','||status
FROM dba_objects
WHERE status != 'VALID'
ORDER BY
   owner
,  object_type
,  object_name
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


col owner format a15 heading "Owner"
col object_type format a25 trunc heading "OBJ Type"
col object_name format a35 trunc heading "OBJ Name"
col status format a10 heading "Status"
col created heading "Created"
col last_ddl_time heading "Last DDL Time"

SELECT
       owner
,      object_type
,      object_name
,      status
,      created
,      last_ddl_time
FROM dba_objects
WHERE status != 'VALID'
ORDER BY
   owner
,  object_type
,  object_name
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

