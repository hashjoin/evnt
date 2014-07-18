#!/bin/ksh
#
# File:
#       dblanal.sh
# EVNT_REG:     DB_LANALZ SEEDMON 1.1
# <EVNT_NAME>DB Last Analyze</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Reports last analyze date(day) for tables and indexes
#
# REPORT ATTRIBUTES:
# -----------------------------
# day_last_analyzed (RRRR/MM/DD)
# owner
# type_of_object (TABLE|INDEX)
# count_of_objects
#
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        10-02-2003      Created
#

chkfile=$1
outfile=$2
clrfile=$3

## get trigger attributes
##
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
select to_char(last_analyzed,'RRRR/MM/DD')
||','||owner
||','||'TABLE'
||','||count(*)
from dba_tables
where last_analyzed is not null
group by to_char(last_analyzed,'RRRR/MM/DD'), owner
order by to_char(last_analyzed,'RRRR/MM/DD') desc, owner
/

select to_char(last_analyzed,'RRRR/MM/DD')
||','||owner
||','||'INDEX'
||','||count(*)
from dba_indexes
where last_analyzed is not null
group by to_char(last_analyzed,'RRRR/MM/DD'), owner
order by to_char(last_analyzed,'RRRR/MM/DD') desc, owner
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
set lines 250
set pages 60
set trims on

col owner format a15

break on day_last_analyzed skip 1
compute sum of count on day_last_analyzed

select to_char(last_analyzed,'RRRR/MM/DD') day_last_analyzed
,      owner
,      'TABLE' otype
,      count(*) count
from dba_tables
where last_analyzed is not null
group by to_char(last_analyzed,'RRRR/MM/DD'), owner
union all
select to_char(last_analyzed,'RRRR/MM/DD') day_last_analyzed
,      owner
,      'INDEX' otype
,      count(*) count
from dba_indexes
where last_analyzed is not null
group by to_char(last_analyzed,'RRRR/MM/DD'), owner
order by day_last_analyzed desc, owner, otype
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

