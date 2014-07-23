#!/bin/ksh
#
# File:
#       os3parm.sh
# EVNT_REG:     OS3PAR_IOM CUSTMON 1.4
# <EVNT_NAME>3PAR IOPs Monitor</EVNT_NAME>
#
# Author:
#       vmogilevskiy (dbatoolz.com)
#
# Usage:
# <EVNT_DESC>
# This event checks for 3PAR IOPs utilization in total and per host
#
# REPORT ATTRIBUTES:
# -----------------------------
#
#
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# HSTIO           Host level IOPs threshold               5000
# TOTIO           Total 3PAR IOPs threshold               60000
# MAXMS           Host level service times in ms          10
# MAXQL           Host level Qlen count                   150
# </EVNT_DESC>
#
#
# History:
#       vmogilevskiy        17-DEC-2013      v1.0 Created
#       vmogilevskiy        23-JUL-2014      v1.4 Added MY3PARARRAY and MYID to 3pariom.sh
#

chkfile=$1
outfile=$2
clrfile=$3

MY3PARARRAY=$MON__H_NAME
MYID=${MON__EA_ID}

## get trigger attributes
##
touch $chkfile
$CUSTMON/3pariom.sh $MY3PARARRAY $MYID $PARAM__HSTIO $PARAM__TOTIO $PARAM__MAXMS $PARAM__MAXQL | grep "\- ISSUE\:" | sed -e 's/^\t\- ISSUE: *//g' > $chkfile

## check for errors
##
if [ $? -gt 0 ]; then
        cat $chkfile
        exit 1;
fi


## check if attribute file has any output
## if not exit if yes continue with
## getting trigger output
##
if [ `cat $chkfile | wc -l` -eq 0 ]; then
        exit 0 ;
fi


## get trigger output (from cache)
##
$CUSTMON/3pariom.sh $MY3PARARRAY $MYID $PARAM__HSTIO $PARAM__TOTIO $PARAM__MAXMS $PARAM__MAXQL Y > $outfile

## check for errors
##
if [ $? -gt 0 ]; then
        cat $outfile
        exit 1;
fi
