#!/bin/ksh
#
# $Header chkmon.sh v1.3 VMOGILEV dbatoolz.com
#
# v1.0 18-DEC-2008 VMOGILEV created
# v1.1 16-JAN-2014 VMOGILEV removed $$ from outfile
# v1.2 25-JUL-2014 VMOGILEV switched to ea_status check to all but 'I' to pick up stale events
# v1.3 25-JUL-2014 VMOGILEV fixed target formatting
#


## --- start user config vars ---
##

##ORACLE_HOME=/u01/app/oracle/product/10.2.0/client_1; export ORACLE_HOME
##PATH=$ORACLE_HOME/bin:$PATH:.; export PATH

export ORACLE_BASE=/oracle/orabin
export ORACLE_HOME=/oracle/orabin/11203/db_1
export ORA_GRID_HOME=/oracle/11203/grid
export PATH=/bin:/sbin:/usr/lib64/qt-3.3/bin:/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/X11R6/bin:/root/bin:/data/svc/sysstat/bin
export PATH=${ORACLE_HOME}/bin:${ORA_GRID_HOME}/bin:${ORACLE_HOME}/OPatch:${PATH}
export PATH=${PATH}:/oracle/crfuser/gui_home/bin:/usr/lib/oracrf/bin
export TNS_ADMIN=${ORA_GRID_HOME}/network/admin
export ORACLE_SID=EVNT1



UNAMEP=evnt/evnt
DBA="VitaliyMogilevskiy@domain.com"
SYSADMIN="VitaliyMogilevskiy@domain.com"
ENV_FILE=~/admin/scripts/mon/MON.env

##
## --- end user config vars ---


BASENAME=`basename $0`
BASEDIR=/tmp
if [ ! $HOSTNAME ]; then
        HOSTNAME=`hostname`
fi
HSTNAME=${HOSTNAME%%.*}
CURR=${BASEDIR}/${BASENAME}_curr.txt
PREV=${BASEDIR}/${BASENAME}_prev.txt
REPORT=${BASEDIR}/${BASENAME}_report.txt

if [ $1 ]; then
	TARGET=$1
else
	echo "usage: $BASENAME <target-db>"
	exit 1;
fi


if [ ! -f $ENV_FILE ]; then
	echo "ERROR: `date` - ENV file $ENV_FILE is missing!"
	exit 1;
else
	. $ENV_FILE
fi

if [ ! -f $PREV ]; then
	touch $PREV
fi


alert_dba() {
for x in $DBA
do
	$SYS_TOP/bin/sendmail.sh $x "$HSTNAME - Events are 30 minutes late" $REPORT
done
}


run_report() {

sqlplus -s $UNAMEP@$TARGET <<EOF > /dev/null
alter session set nls_date_format='YYYY-MON-DD HH24:MI';

set trims on
col event format a15
col target format a15

spool $REPORT

select sysdate from dual;

SELECT /*+ ORDERED */
    ea_id
,   decode(substr(e.e_code_base,1,1),'*','remote','local') agent
,   e_code event
,   h.H_NAME||decode(s.S_NAME,null,null,':'||s.S_NAME) target
,   ea_start_time shed_time
,   trunc((sysdate - ea_start_time)*24*60) min_late
FROM event_assigments ea
,    events e
,    hosts h
,    sids s
WHERE /*e.e_code_base NOT LIKE '*%'
AND   */ea.e_id = e.e_id
--AND   ea_status in ('A','B')
AND   ea_status <> ('I') /* all but inactive to pickup stale runs */
AND   ea_start_time <= SYSDATE-30/24/60
and   ea.h_id = h.h_id
and   ea.s_id = s.s_id(+)
ORDER BY ea_start_time;


spool off
exit
EOF

}

outfile=/tmp/$BASENAME.out

sqlplus -s $UNAMEP@$TARGET <<EOF > $outfile
alter session set nls_date_format='YYYY-MON-DD HH24:MI';

set lines 132
set trims on
col event format a15
col target format a35

spool $CURR

SELECT /*+ ORDERED */
    ea_id
,   decode(substr(e.e_code_base,1,1),'*','remote','local') agent
,   e_code event
,   h.H_NAME||decode(s.S_NAME,null,null,':'||s.S_NAME) target
,   ea_start_time shed_time
FROM event_assigments ea
,    events e
,    hosts h
,    sids s
WHERE /*e.e_code_base NOT LIKE '*%'
AND   */ea.e_id = e.e_id
--AND   ea_status in ('A','B')
AND   ea_status <> ('I') /* all but inactive to pickup stale runs */
AND   ea_start_time <= SYSDATE-30/24/60
and   ea.h_id = h.h_id
and   ea.s_id = s.s_id(+)
ORDER BY ea_start_time;


spool off
exit
EOF


if [ $? -gt 0 ]; then
	echo `date` >> $outfile
	mailx -s "$HSTNAME - $BASENAME can't check Event database $TARGET" $SYSADMIN < $outfile
fi

if [ `diff $PREV $CURR | wc -l` -gt 0 ]; then
	run_report;
	alert_dba;
fi

mv $PREV $PREV.old
mv $CURR $PREV

