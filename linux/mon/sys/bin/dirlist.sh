#!/bin/ksh
#
#     Copyright (c) 1998 DBAToolZ.com All rights reserved.
# 
# FILE:
#	dirlist.bat
# 
# AUTHOR:
#	Vitaliy Mogilevskiy VMOGILEV (www.dbatoolz.com)
#	DBAToolZ.com
#
# PURPOSE:
#	Creates directory listing for the SQLDIR program
#
# USAGE:
#	dirlist.sh <sql_directory_name>
#	dirlist.sh
#
# EXAMPLE:
#	To list all sqlfiles contained in /tmp directory:
#		$ dirlist.sh /tmp
#
#	To list all sqlfiles in the default SQLDIR directory (../sql):
#		$ dirlist.sh
#
# HISTORY:
#	04-NOV-2001	VMOGILEV	Created
#

sqldir=$1

if [ ! "$sqldir" ]; then
	sqldir=../sql
fi

echo "Listing directory: " $sqldir

ls -l $sqldir/*.sql | awk '{ print $9 }' > sqldir.list

sqldir sqldir.list groups.cfg

