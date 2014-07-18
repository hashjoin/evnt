#!/bin/ksh
#
# File:
#       intmail.sh
# EVNT_REG:	INTERNAL_MAILFLOOD SEEDMON 1.1
# <EVNT_NAME>Mail Notification Flood</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# Internally set by evnt_util_pkg.get_pending_mail when the number of 
# pending event trigger notifications is unreasonably high 
# (controlled by predefined threshold at the OS level MON.env [mail_max_notif])
# 
# NOTE:
#   do not schedule this event -- it's just a placeholder used internally by the system
# 
# REPORT ATTRIBUTES:
# -----------------------------
# N/A
#
# NO Parameters
# 
# </EVNT_DESC>
#
# History:
#       VMOGILEV        09-MAR-2005      intmail.sh Created
#


chkfile=$1
outfile=$2
clrfile=$3

touch $chkfile
touch $outfile

