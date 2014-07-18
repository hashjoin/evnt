#!/bin/ksh
#
# $Header collproc.sh 04/04/2003 1.4
#
# File:
#	collproc.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV
#
# Purpose:
#	Process COLLECTION
#
# Usage:
#	collproc.sh COLL_ASSIGMENTS.CA_ID
#
# History:
#	19-AUG-2002	VMOGILEV	(1.1) Created
#	03-APR-2003	VMOGILEV	(1.2) removed set_status
#	04-APR-2003	VMOGILEV	(1.3) removed logfile*
#	21-OCT-2013	VMOGILEV	(1.4) Added alter session set recyclebin=off;
#


BASENAME=`basename $0`
HOSTNAME=`hostname`
CTIME=`date`
usage()
{
echo "USAGE: collproc.sh COLL_ASSIGMENTS.CA_ID"
exit 1;
}

if [ "$1" ]; then
	ASSIGMENT_ID=$1
else
	usage;
fi

echo "Starting collection on $CTIME "

echo "SHARE_TOP="$SHARE_TOP

if [ ! "$SHARE_TOP" ]; then
	echo "ERROR:   SHARE_TOP not set!"
	exit 1;
fi

if [ ! "$uname_passwd" ]; then
	echo "ERROR:   uname_passwd not set!"
	exit 1;
fi

if [ ! "$time_format" ]; then
	echo "ERROR:   time_format not set!"
	exit 1;
fi


process_date=`sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set feed off
set pages 0
set trims on
select TO_CHAR(SYSDATE,'$time_format') from dual;
exit
EOF
`

echo "checking for holds ..."
sqlplus -s $uname_passwd <<EOF 
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set trims on
set lines 100
VARIABLE level NUMBER;
VARIABLE hold_reason VARCHAR2(100);

-- check for blackouts
BEGIN
   IF coll_util_pkg.collection_on_hold(
         $ASSIGMENT_ID , 
         :hold_reason) THEN
      :level := 5 ;
   ELSE
      :level := 0 ;
   END IF;
END;
/
commit;
print hold_reason
exit :level
EOF

exit_code=$?
echo "EXIT CODE= " $exit_code

if [ $exit_code -gt 0 ]; then
        if [ $exit_code -eq 5 ]; then
                echo "HOLD EXISTS, exiting ..."
                exit 0;
        fi

        # if I got here there was an error
        echo "Failure to check for blackout on `date` !"
        exit 1;
fi


echo "starting collection ..."
sqlplus -s $uname_passwd <<EOF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
set pages 500
set trims on

VARIABLE l_s_id NUMBER;
VARIABLE l_c_id NUMBER;
VARIABLE l_cp_id NUMBER;
VARIABLE l_sc_id NUMBER;

VARIABLE view_code VARCHAR2(4000);
VARIABLE view_name VARCHAR2(100);
VARIABLE l_db_link VARCHAR2(256);
VARIABLE rcon_str  VARCHAR2(150);

-- connect string
col rcon_str noprint new_value N_rcon_str
col view_name format a80
col l_db_link format a80


-- load variables
BEGIN
   coll_util_pkg.set_coll_env(
      p_ca_id        => $ASSIGMENT_ID
   ,  p_out_s_id     => :l_s_id 
   ,  p_out_c_id     => :l_c_id 
   ,  p_out_cp_id    => :l_cp_id
   ,  p_out_sc_id    => :l_sc_id
   ,  p_out_rcon_str => :rcon_str
   ,  p_out_db_link  => :l_db_link);
END;
/

-- print curr vars
print l_s_id
print l_c_id
print l_cp_id
print l_sc_id
print l_db_link
print rcon_str

BEGIN
   coll_util_pkg.get_view(
      p_c_id      => :l_c_id
   ,  p_cp_id     => :l_cp_id
   ,  p_ca_id     => $ASSIGMENT_ID
   ,  p_view_code => :view_code
   ,  p_view_name => :view_name);
END;
/

print view_code
print view_name


-- create SOURCE PULL VIEW
connect &N_rcon_str
alter session set recyclebin=off;
DECLARE
   l_view_code VARCHAR2(4000);
   l_cur   NUMBER;
   l_rec   NUMBER;
BEGIN
   l_view_code := REPLACE(:view_code,';') ;
   l_cur := dbms_sql.open_cursor;
  
   dbms_sql.parse(
      l_cur
   ,  l_view_code
   ,  dbms_sql.native);
 
   l_rec := dbms_sql.execute(l_cur);

   dbms_sql.close_cursor(l_cur); 
END;
/


connect $uname_passwd
alter session set recyclebin=off;
-- perform PULL
BEGIN
   coll_util_pkg.pull(:l_c_id,:l_cp_id,:l_s_id, $ASSIGMENT_ID ,:view_name,:l_db_link);
END;
/

commit;


-- drop SOURCE PULL VIEW
connect &N_rcon_str
alter session set recyclebin=off;
DECLARE
   l_cur   NUMBER;
   l_rec   NUMBER;
   l_drop  VARCHAR2(300);
BEGIN
   l_drop := 'drop view '||:view_name ;

   l_cur := dbms_sql.open_cursor;
   
   dbms_sql.parse(
      l_cur
   ,  l_drop
   ,  dbms_sql.native);

   l_rec := dbms_sql.execute(l_cur);

   dbms_sql.close_cursor(l_cur); 
END;
/

commit;

exit
EOF

if [ $? -gt 0 ]; then
	echo "Failure on `date` !"
	exit 1;
fi

echo "Done on `date` !"

