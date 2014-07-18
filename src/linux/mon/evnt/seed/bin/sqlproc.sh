#!/bin/ksh
#
# File:
#       sqlproc.sh
# EVNT_REG:     SQL_SCRIPT SEEDMON 1.4
# <EVNT_NAME>SQL Script Processor</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# This event runs custom SQL*Plus scripts.  Use it to plug and play your
# custom sql scripts without the need for writing your own custom events.
#
# The following steps need to be completed to "register" custom
# sql script with this event:
#
#    1. Make two copies of your existing sql script or create 
#       two new sql files with the following extensions:
#
#          [CHK file] $EVNT_TOP/cust/sql/script_name.chk.sql
#          [OUT file] $EVNT_TOP/cust/sql/script_name.out.sql
#
#    2. CHK file should return comma delimited data:
#
#          -------- example ---------------
#          attribute1,attribute2,attributeX
#          attribute1,attribute2,attributeX
#          attribute1,attribute2,attributeX
#          --------- end ------------------
#
#       for example you can use the following syntax to generate comma 
#       delimited output:
#
#          SELECT
#                 col1
#          ||','||col2
#          ||','||col3
#          ||','||col4
#          FROM table;
#
#       attribute(s) are parsed and stored in the repository - 
#       they are used to compare event triggers when evaluating 
#       their status:
#       
#          STATUS  CONDITION
#          ------- --------------------------------------------------
#          OFF     when check file's output has 0 lines
#          ON      when check file's output has >0 lines and 
#                  previous attributes don't match current attributes
#          CLEARED when check file's output has 0 lines and previous 
#                  status was ON
#
#   3. OUT file can return output in free format as long as it's line size
#      not exceeding 255 chars.  Output of this script will be loaded into
#      the repository and will be available on trigger output screen.
#
# REPORT ATTRIBUTES:
# -----------------------------
# custom [based on sql script run]
#
#
# PARAMETER       DESCRIPTION                                       EXAMPLE
# --------------  ------------------------------------------------  --------
# SQL_SCRIPT      name of the sql script                            tabsp
#
#                 event will automatically append the following
#                 to the SQL_SCRIPT name:
#                 
#                    $EVNT_TOP/cust/sql/${SQL_SCRIPT}.chk.sql
#                    $EVNT_TOP/cust/sql/${SQL_SCRIPT}.out.sql
#
#                 for example if you created CHK and OUT files and
#                 named them:
#
#                    $EVNT_TOP/cust/sql/tabsp.chk.sql
#                    $EVNT_TOP/cust/sql/tabsp.out.sql
#                 simply supply "tabsp" for SQL_SCRIPT parameter
#
# SQL_PARAMS      positional parameters (1 2 3 4) to your sql script
#                 for example if your script is
#
#                    select * 
#                    from user_free_space
#                    where tablespace_name='&1'
#                    and bytes >= &2
#
#                 SQL_PARAMS could be "TOOLS 300" (no quotes)
#                    
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        10-29-2003      Created
#       VMOGILEV        11-10-2003      1.2 added SQL_PARAMS
#       VMOGILEV        11-10-2003      1.3 added "set verify off" on OUT run
#       VMOGILEV        11-30-2013      1.4 fixed a bug which left runf and chk file when no EVNT was triggered
#

chkfile=$1
outfile=$2
clrfile=$3


chk=$EVNT_TOP/cust/sql/${PARAM__SQL_SCRIPT}.chk.sql
out=$EVNT_TOP/cust/sql/${PARAM__SQL_SCRIPT}.out.sql

if [ -f $chk ]; then
	echo "sql chk file [$chk]"
else
	echo "can't access sql chk file [$chk]"
	exit 1;
fi


if [ -f $out ]; then
	echo "sql out file [$out]"
else
	echo "can't access sql out file [$out]"
	exit 1;
fi

runf=$SHARE_TOP/tmp/$$.${PARAM__SQL_SCRIPT}.sql

## get trigger attributes
##

echo "
set lines 2000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $chkfile
@$chk "$PARAM__SQL_PARAMS"
spool off
exit" > $runf

sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
@$runf
CHK
## check for errors
##
if [ $? -gt 0 ]; then
        cat $chkfile.err
        rm $chkfile.err
	rm $runf
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
        rm $chkfile.err
	rm $runf
        exit 0 ;
fi


## get trigger output
##
echo "
ALTER SESSION SET NLS_DATE_FORMAT='RRRR-MON-DD HH24:MI:SS';
spool $outfile
set verify off
set lines 250
set pages 60
set trims on
@$out "$PARAM__SQL_PARAMS"
spool off
exit" > $runf

sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
@$runf
CHK

## check for errors
##
if [ $? -gt 0 ]; then
        cat $outfile.err
        rm $outfile.err
	rm $runf
        exit 1;
fi

## if I got here remove error chk file
##
rm $outfile.err
rm $runf


