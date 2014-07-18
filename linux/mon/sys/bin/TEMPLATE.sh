#!/bin/ksh
#
# File:
#       <event_file_name>
# EVNT_REG:     <EVENT_CODE> <BASENAME> <VERSION>
# <EVNT_NAME>Event Description</EVNT_NAME>
#
# Author:
#       <AUTHOR_LONG> (<AUTHOR_EMAIL>)
#
# Usage:
# <EVNT_DESC>
# This event checks for ...
#
# REPORT ATTRIBUTES:
# -----------------------------
#
#
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# </EVNT_DESC>
#
#
# History:
#       <AUTHOR>        <DATE>      Created
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
SELECT
       col1
||','||col2
||','||col3
||','||col4
FROM table
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
SELECT 
   col1
,  col2
,  col3
,  col4
FROM table;
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

#######################
### END TEMPLATE.sh ###
#######################

