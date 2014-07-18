#!/bin/ksh
#
# $Header install.sh 08/11/2004 1.3
#
# File:
#	install.sh
#
# Author:
#	Vitaliy Mogilevskiy VMOGILEV ()
#
# Usage
#	% install.sh
#
# Desciption:
#	Installs repository for EVNT module (must be run from the database node where EVNT is being installed)
#
# History:
#	17-MAR-2003	VMOGILEV	(1.1) Created
#	17-MAR-2003	VMOGILEV	(1.2) Ported to 9i [/ as sysdba]
#	29-SEP-2009	VMOGILEV	(1.3) Ported to 10g/local db host install only
#	18-OCT-2013	VMOGILEV	(1.4) added DEF_TS to cr8_privs call
#

LOG=/tmp/$$.evnt_inst.log
WHERE_IAM=$PWD

if [ ! -f $SYS_TOP/bin/evntrall.sh ]; then
	echo "can't locate $SYS_TOP/bin/evntrall.sh ..."
	echo "did you source MON.env?"
	echo "exiting ..."
	exit 1;
fi

chke() {
ES=$1
EM="$2"
ELOG=$3
if [ $ES -gt 0 ]; then
	echo $EM
	cat $ELOG
	echo "exiting ..."
	exit 1;
fi
## END chke
}

dadcfg() {

echo "

To configure ORACLE AS PL/SQL DAD for EVNT's modify

   vi /u01/app/oracle/product/10.2.0/ohs_1/Apache/modplsql/conf/dads.conf

Add the following:
- - - - - - - - - cut here - - - - - - - -
<Location /evnt>
  SetHandler pls_handler
  Order deny,allow
  Allow from all
  AllowOverride None
  PlsqlDatabaseConnectString    ${HOSTNAME}:1521:${ORACLE_SID} SIDFormat
  PlsqlAuthenticationMode       Basic
  PlsqlDefaultPage              web_nav_pkg.evnt
  PlsqlNLSLanguage              American_America.WE8ISO8859P1
</Location>
- - - - - - - - - - end here - - - - - - - -
"

## END dadcfg
}



ireg() {
## register local host as loopback
## for event purge collections
echo "ireg:	start ..."
echo "parsing repository hostname ..."
echo "  LOCAL_HOSNAME=[${LOCAL_HOSNAME}]"

##sqlplus -s sys/$SYS_PASS@$REP_TNS <<EOF  > $LOG.dbname
sqlplus -s "/ as sysdba" <<EOF  > $LOG.dbname
WHENEVER SQLERROR EXIT FAILURE
set lines 3000
set trims on
set pages 0
set feed off
SELECT
   '$LOCAL_HOSNAME,"EVNT Management server DO NOT REMOVE!",'||name||
   ',"EVNT Management server DATABASE DO NOT REMOVE!",bgpurge,justagate,$REP_TNS'
from v\$database

spool $SYS_TOP/bin/SERVER.dat
/
spool off
exit
EOF
chke $? "local host/sid parse failure ..." $LOG.dbname

echo "registering repository host/sid ..."
cd $SYS_TOP/bin
trgint.sh SERVER.dat evnt/evnt@$REP_TNS >$LOG.reghost 2>&1
chke $? "local host/sid registration failure ..." $LOG.reghost

echo "registering installed events ..."
evntrall.sh $REP_TNS evnt > $LOG.evnt 2>&1
chke $? "event registration failure ..." $LOG.evnt

echo "installing char based interface ..."
sqlplus -s evnt/evnt@$REP_TNS @sqldir_ddl.sql > $LOG.char 2>&1
chke $? "event char based install failure ..." $LOG.char

SIDNAME=`cut -d"," -f3 $SYS_TOP/bin/SERVER.dat`
cd $WHERE_IAM
echo "uploading seeded data ..."
expimp.sh imp evnt/evnt@$REP_TNS $SIDNAME > $LOG.upld 2>&1
chke $? "seeded upload failure ..." $LOG.upld

echo "ireg:	end ..."
## END ireg
}



irep() {
## install repository
echo "irep:	start ..."
echo "installing repository ..."
##sqlplus -s sys/$SYS_PASS@$REP_TNS <<EOF  > $LOG.rep
sqlplus -s "/ as sysdba" <<EOF  > $LOG.rep
@install.sql $REP_TNS $DEF_TS
undefine 1
undefine 2
--connect sys/$SYS_PASS@$REP_TNS
connect / as sysdba
set echo on
@cr8_privs.sql $REP_TNS evnt $DEF_TS
exit
EOF

chke $? "repository install failure ..." $LOG.rep

echo "irep:	end ..."
## END irep
}

drep() {
echo "drep:	start ..."
echo "dropping repository ..."
##sqlplus -s sys/$SYS_PASS@$REP_TNS <<EOF > $LOG.drop
sqlplus -s "/ as sysdba" <<EOF > $LOG.drop
WHENEVER SQLERROR EXIT FAILURE
drop user evnt cascade;
WHENEVER SQLERROR CONTINUE
drop user bgproc cascade;
drop user webproc cascade;
drop user bgpurge cascade;
drop ROLE bgproc_role;
drop ROLE webproc_role;
DROP PUBLIC SYNONYM glob_web_pkg ;
DROP PUBLIC SYNONYM glob_web_pkg ;
DROP PUBLIC SYNONYM evnt_web_pkg ;
DROP PUBLIC SYNONYM coll_web_pkg ;
DROP PUBLIC SYNONYM web_nav_pkg  ;
DROP PUBLIC SYNONYM event_triggers_all_v ;
exit
EOF

chke $? "repository drop failure ..." $LOG.drop

echo "drep:	end ..."
## END drep
}


vinit() {
echo "vinit:	start ..."
echo "validating supplied parameters ..."
##sqlplus -s sys/$SYS_PASS@$REP_TNS <<EOF > $LOG.init
sqlplus -s "/ as sysdba" <<EOF > $LOG.init
WHENEVER SQLERROR EXIT FAILURE
create user test123456789 identified by test
default tablespace $DEF_TS temporary tablespace TEMP;
drop user test123456789;
exit
EOF

chke $? "can't validate initial parameters ... " $LOG.init ;

echo "validating database parameters ..."
##sqlplus -s sys/$SYS_PASS@$REP_TNS <<EOF > $LOG.init
sqlplus -s "/ as sysdba" <<EOF > $LOG.init
WHENEVER SQLERROR EXIT FAILURE
DECLARE
   l_value VARCHAR2(255);
BEGIN
   select value
   into l_value
   from v\$parameter
   where name='global_names'
   and UPPER(value)='FALSE';
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001,'global_names must be set to FALSE!');
END;
/
exit
EOF

chke $? "database parameters are not set correctly ... " $LOG.init ;
echo "vinit:	end ..."
## END vinit
}

lastw() {
echo "

	INSTALL IS COMPLETE
	--------------------

	What's next:

	   o startup EVNT processes:

		% cd $SYS_TOP/bin
		% startup.sh local bgproc/justagate@$REP_TNS

           o shutdown EVNT processes:

                % cd $SYS_TOP/bin
                % shutdown.sh

           o check status of EVNT processes:

                % cd $SYS_TOP/bin
                % bstat

	   o configure hosts/sids that will be monitored by EVNT:
             
                % cd $SYS_TOP/bin
                % addsid.sh

           o use HTTP interface [provided default port 7777] to
                - to view installed EVENTS
                - schedule EVENT monitoring
                - configure paging blackout
                - configure page lists
              
                http://$HOSTNAME:7777/evnt/evnt_web_pkg.ep_form
                   USERNAME: webproc
                   PASSWORD: welcome

	   o to change EVNT account's password

                % sqlplus evnt/evnt
                  [use password command]
"

## END lastw
}

if [ "x${ORACLE_SID}" == "x" ]; then
	echo "ERROR: Installation must be performed on the database node -- ORACLE_SID is not set, exiting ..."
	exit 1;
fi


echo "
You are about to install/remove monitoring repository
in the following database ORACLE_SID=$ORACLE_SID

   [if this is not what you want to do EXIT now (ctl-C)]

Provide the following information about the
database you designated to use as repository:
"
##read REP_TNS?"	Enter TNS alias: "
## read SYS_PASS?"	Enter sys password: "
read DEF_TS?"	Enter tablespace: "
read ACTION?"	Do you want to Install or [D]drop repository [ENTER=Install]: "

if [ "$ACTION" = "D" -o "$ACTION" = "d" ]; then
	DROP="yes"
fi

export DROP
export REP_TNS=$ORACLE_SID
## to support install on 9i
##export SYS_PASS
export DEF_TS

echo "
ORACLE_SID=$ORACLE_SID
REP_TNS=$REP_TNS
SYS_PASS=$SYS_PASS
DEF_TS=$DEF_TS
INSTALL=$INSTALL
DROP=$DROP
" > $LOG

## validate init parameters
vinit ;

if [ "$DROP" ]; then
	read junk?"   Are you sure you want to drop EVNT schema in ORACLE_SID=$ORACLE_SID [ctl-C to cancel]? "
	drep;
else
	read junk?"   Are you sure you want to install EVNT schema in ORACLE_SID=$ORACLE_SID [ctl-C to cancel]? "
	irep;
	ireg;
	lastw;
	dadcfg;
fi

