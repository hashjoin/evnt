#!/bin/ksh
#
# File:
#       test.sh
# EVNT_REG:     TEST SEEDMON 1.1
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

##echo "`date` going to sleep for $PARAM__SLEEP_TIME" > $chkfile
touch $chkfile
sleep $PARAM__SLEEP_TIME

##echo "done!" >> $chkfile

