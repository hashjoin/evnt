#!/bin/ksh
#
# File:
#       dbmproc.sh
# EVNT_REG:     DB_MAX_PROCS SEEDMON 1.1
# <EVNT_NAME>Max DB processes limit</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Triggers if percent of database processes is reaching
# maximum allowable my instance parameters (v$parameter)
#
# REPORT ATTRIBUTES:
# -----------------------------
#
#
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# PCT_USED        threshold for the following value:      80
#                    used_procs*100/max_procs
#                 DEFAULT=90
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        29-SEP-2003      Created
#

chkfile=$1
outfile=$2
clrfile=$3

if [ "$PARAM__PCT_USED" ]; then
	PCT_USED=${PARAM__PCT_USED}
else
	echo "using default PCT USED = 90"
	PCT_USED=90
fi

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
select count(ADDR)
||','||to_number(value)
||','||trunc(count(ADDR)*100/to_number(value))
from v\$process p
,    v\$parameter r
where r.name='processes'
group by value
having $PCT_USED <= trunc(count(ADDR)*100/to_number(value))
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

ttit "Percent of used database procs. vs max procs. is >= ($PCT_USED)"

col used_procs heading "Used Procs"
col max_procs  heading "Max Procs"
col pct_used   heading "% Used"

select count(ADDR) used_procs
,      to_number(value) max_procs
,      trunc(count(ADDR)*100/to_number(value)) pct_used
from v\$process p
,    v\$parameter r
where r.name='processes'
group by value
having $PCT_USED <= trunc(count(ADDR)*100/to_number(value))
/

@$EVNT_TOP/seed/sql/s_user_ses_cnt.sql

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

