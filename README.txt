# ------------------------------------------------------------------------------
#         Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
# ------------------------------------------------------------------------------
# FILE:		README.txt
# VERSION:	v3.5.12
# LOCATION:	http://kb.dbatoolz.com/tp/1155.download__evnt_-_event_monitoring_system.html
# ABOUT:	(EVNT) EVNT - Event Monitoring System
# CONTACT:	http://kb.dbatoolz.com/tp/1458.evnt_support.html
# ------------------------------------------------------------------------------

1. INSTALLATION
   
   1.0 ARCHITECTURE OVERVIEW
   1.1 SOFTWARE REQUIREMENTS
   1.2 CONFIGURE DATABASE/WEB SERVER
   1.3 INSTALL MANAGEMENT SERVER
   
2. WHAT'S NEXT?

   2.1 REGISTER DATABASE(S) TO MONITOR
   2.2 CREATE REPOSITORY USER ACCOUNTS
   2.3 STARTUP BACKGROUND PROCESSES
   2.4 LOGIN TO REPOSITORY

3. FAQ

   3.1 HOW TO CHANGE MON USER'S PASSWORD?
   3.2 WHAT PRIVILEGES ARE GIVEN TO MON USER?
   3.3 HOW TO REGISTER DATABASES MANUALLY (NO "addsid.sh")?
   3.4 HOW TO REGISTER STAND ALONE HOST(S)?
   3.5 HOW DO PRIMARY/SECONDARY NOTIFICATIONS WORK (acknowledgments)

________________________________________________________________________________          

1. INSTALLATION
   
   1.0 ARCHITECTURE OVERVIEW
   
      (EVNT) EVNT - Event Monitoring System Event Monitoring System consists of the following components:
      	(RP) - Repository on Oracle 8174 with partitioning option
      	(WS) - Oracle IAS Apache with mod_plsql
      	(MS) - Management server on SUN SPARC or LINUX
      	(RA) - Remote agents on SUN SPARC or LINUX
      
      The installation can be configured in one of the following ways:
      	(ST) Single tier
      		o RP + WS + MS
      	
      	(MT1) Multi tier option 1
      		o [tier 1] RP
      		o [tier 2] WS
      		o [tier 3] MS
      	
      	(MT2) Multi tier option 2
      		o [tier 1] RP + WS 
      		o [tier 2] MS
      	
      	(RT)  Remote agents reside on monitored servers
      	      these agents are optional - they only serve
      	      events that require remote execution.
                    (os file usage, log miners, process monitors etc.)
      
      The following grants are required for the owner of repository/packages
      (this information is just FYI - installation scripts take care of 
       all required grants):
       
         GRANT ALTER SESSION TO <owner_of_glob_web_pkg>;
         GRANT EXECUTE ON dbms_lock TO <owner_of_coll_util_pkg>;
         GRANT CREATE DATABASE LINK TO evnt;
         GRANT CREATE TABLE TO evnt;
         GRANT CREATE PUBLIC SYNONYM TO evnt;
         
         "ALTER SESSION" is needed to allow for SQL_TRACE from mod_plsql
      
            It can be configured in wdbsvr.app as follows (EXAMPLE):
            
            [DAD_EVNTT]
            connect_string   =  mgm1
            ;password   =
            ;username   =
            ;default_page   =
            ;document_table   =
            ;document_path   =
            ;document_proc   =
            ;upload_as_long_raw   =
            ;upload_as_blob   =
            name_prefix   =
            ;always_describe   =
            after_proc   = glob_web_pkg.trace_off
            before_proc   = glob_web_pkg.trace_on
            reuse   =  Yes
            connmax   = 10
            ;pathalias   =
            ;pathaliasproc   =
            enablesso   =  No
            ;sncookiename   =
            stateful   =  No
            ;custom_auth   =
      
   
   1.1 SOFTWARE REQUIREMENTS
   
      Database/Web Server
      --------------------
         ORACLE RDBMS 8.1.7.4 with Partitioning Option 
            (Personal Oracle 8i will work)
         Oracle IAS with PL/SQL Toolkit
            (IAS that is shipped with Oracle 8i will work)
      
      Management Server
      ------------------
         ORACLE Client 8.1.7.4
         SOLARIS 2.6/2.8/2.9 or 
         RedHat Linux with KSH
   

   1.2 CONFIGURE DATABASE/WEB SERVER
   
      ***********************************************
      *** BEFORE YOU BEGIN MAKE SURE TO READ $1.1 ***
      ***********************************************
      
      Set the following parameters in INIT.ORA of the 
      database you designated for EVNT repository
      ----------------------------------------------------
         global_names=false
         open_links=50
         
         bounce database
      
      Configure IAS PL/SQL Toolkit on the web server
      you designated to serve EVNT's mod_plsql pkgs
      -------------------------------------------------
         UNIX> vi $ORACLE_HOME/Apache/modplsql/cfg/wdbsvr.app
         
         WINDOWS> write <VALUE_OF_ORACLE_HOME_FROM_REGEDIT>\Apache\modplsql\cfg\wdbsvr.app
         EXAMPLE:
         WINDOWS> write C:\oracle\ora81\Apache\modplsql\cfg\wdbsvr.app
         
         ADD THE FOLLOWING:
         	cut and paste from (change <mgm_tns_alias> to TNS ALIAS for repository)
         	   http://kb.dbatoolz.com/ex/uploads/4389.wdbsvr.app.example.txt
         
         bounce IAS
      
   
   1.3 INSTALL MANAGEMENT SERVER
   
      ***********************************************
      *** BEFORE YOU BEGIN MAKE SURE TO READ $1.1 ***
      ***********************************************
         
      Unload EVNT software distribution
      ----------------------------------
         UNIX> tar -xvf <distribution_file>.tar
            WHERE <distribution_file> is the tar file you either 
                  downloaded or received from http://kb.dbatoolz.com/tp/1155.download__evnt_-_event_monitoring_system.html
         
      
      Configure the environment
      --------------------------
         above step should create "mon" subdirectory
         UNIX> cd mon
         UNIX> vi MON.env
         
         The following VARIABLES need to be supplied:
         
            MON_TOP		absolute path to "mon" directory
            ping_cmd		absolute path to "ping" executable
            sendmail_cmd	absolute path to "sendmail" executable
            replyto		reply email address will be used on all alerts
            sysadmin		email address of EVNT administrator
            			(low level EVNT system errors will be send to this address)
            global_mail_prefix	prefix that will be used for subject on all alerts
         
         EXAMPLE:
         
            MON_TOP=/u01/app/oracle/admin/scripts/mon; export MON_TOP
            ping_cmd="/bin/ping"; export ping_cmd
            sendmail_cmd="/usr/lib/sendmail"; export sendmail_cmd
            replyto=oracle.dba@yourcom.com; export replyto
            sysadmin=you@yourcom.com; export sysadmin
            global_mail_prefix="ALRT_"; export global_mail_prefix
         
         Source the environment:
         UNIX> . MON.env
      
      
      Configure Oracle SQL*Net aliases
      ---------------------------------
         To avoid any conflicts with your current configuration and 
         to provide for centralized administration of TNS aliases
         EVNT monitoring system uses it's own TNS_ADMIN directory
         which is set to the following:
            
            TNS_ADMIN=$MON_TOP/TNSADMIN
         
         UNIX> cd $TNS_ADMIN
         UNIX> vi tnsnames.ora
            
            Configure TNS Alias for the database you designated for
            EVNT repository use as well as all databases that will
            be monitored by EVNT system.
         
         NOTE:
            It is not recommended to use Oracle's names server to
            resolve TNS Aliases due to the high volume of connections 
            generated by EVNT system.
            
      
      Install repository
      -------------------
         UNIX> cd $SYS_TOP/install
         UNIX> install.sh
             (follow prompts)


2. WHAT'S NEXT?

   2.1 REGISTER DATABASE(S) TO MONITOR

      To register new databases with EVNT monitoring system
      use "addsid.sh" program found on the management server:
      
         UNIX> cd $SYS_TOP/bin
         UNIX> addsid.sh
             (follow prompts)
      
      "addsid.sh" will create MON schema on supplied database
      to be used for monitoring and collections.  MON schema
      will only have SELECT privileges on various performance
      and stats database views as well as APPS tables/views if 
      supplied database hosts Oracle Applications (APPS).
      

   2.2 CREATE REPOSITORY USER ACCOUNTS
      
      Any existing database user can be allowed to use EVNT
      monitoring system by giving them webproc_role ROLE:
      
         SQLPLUS@EVNT_repository> connect system
         SQLPLUS@EVNT_repository> GRANT webproc_role to <new_user>;

   2.3 STARTUP BACKGROUND PROCESSES
      
      On the management server:
         UNIX> cd $SYS_TOP/bin
         UNIX> startup.sh local bgproc/justagate@<EVNT_REP>
            <EVNT_REP>	= TNS Alias for EVNT repository
      
      To verify EVNT background processes:
         UNIX> cd $SYS_TOP/bin
         UNIX> bstat
      
      To shutdown EVNT background processes:
         UNIX> cd $SYS_TOP/bin
         UNIX> shutdown.sh
     

   2.4 LOGIN TO REPOSITORY
      
      If you configured your IAS mod_plsql module as described in
      $1.2 your should be able to login to EVNT repository using
      the following URL:
      
         http://webserver.yourcom.com/pls/EVNT/web_nav_pkg.evnt
      
      Change "webserver.yourcom.com" to the webserver name you
      configured in $1.2.  This page is password protected, any
      user that was given webproc_role (see $2.2) can login and
      use the repository.  Installation process creates one seeded
      account that has webproc_role it's called WEBPROC the default 
      password is WELCOME.  Make sure to change this password.
      


3. FAQ

   3.1 HOW TO CHANGE MON USER'S PASSWORD?
         
         If a database was registered using "addsid.sh" program
         username/password is fixed:
            mon/justagate
         
         if you wish to change password do so on the database level then
         update EVNT.sid_credentials.sc_password:
         
            UPDATE EVNT.sid_credentials
            SET sc_password = '<new_password>'
            WHERE s_id = (SELECT s_id FROM sids 
                          WHERE s_name = UPPER('&sid_name'))
            AND UPPER(sc_username) = 'MON';

   
   3.2 WHAT PRIVILEGES ARE GIVEN TO MON USER?

      A list of privileges given to MON user can be reviewed in:
         $SYS_TOP/sql/cr8musr.sql (DATABASE privs)
         $SYS_TOP/sql/cr8musra.sql (APPS privs)

   
   3.3 HOW TO REGISTER DATABASES MANUALLY (NO "addsid.sh")?

      It's recommended to use "addsid.sh" when adding new databases to
      EVNT monitoring system, but to understand the process or to be 
      able to add a large number of new databases the following steps
      should be followed:

      Create MON schema
      ------------------
         UNIX> cd $SYS_TOP/sql
         UNIX> sqlplus evnt/evnt_password@mgm_tns_alias
         
         For each SID that you will monitor complete the following steps:

         SQLPLUS> @cr8musr.sql <SYSPWD> <RSID_TNS> <MON_USER> <DEF_TS>
            <SYSPWD>   = sys user password
            <RSID_TNS> = remote SID Tns Alias (remote sid to monitor)
            <MON_USER> = monitoring user on remote sid (will be created)
            <DEF_TS>   = monitoring user's default tablespace (has to exist)
            
            NOTE:
               monitoring user's password will be "justagate"
               you can change it right after "cr8musr.sql"
         
         Complete the next step if monitored SID is 11i database
         SQLPLUS> @cr8musra.sql <MON_USER> <MON_PASS> <APPS_PASS> <RSID_TNS>
            <MON_USER>  = monitoring user on remote sid
            <MON_PASS>  = monitoring user password
            <APPS_PASS> = apps user password
            <RSID_TNS>  = remote SID Tns Alias
            
      
      Import server/sid information
      -------------------------------
         UNIX> cd $SYS_TOP/bin
         UNIX> vi SERVER.dat
         
            -- SERVER.dat EXAMPLE START
            server_name1,"Server1 Desc",SID1_NAME,"SID Desc",MON_USER,MON_PASSWORD,SID1_TNS_ALIAS
            server_name2,"Server2 Desc",SID2_NAME,"SID Desc",MON_USER,MON_PASSWORD,SID2_TNS_ALIAS
            server_name3,"Server3 Desc",SID3_NAME,"SID Desc",MON_USER,MON_PASSWORD,SID3_TNS_ALIAS
            -- SERVER.dat EXAMPLE END
         
         ## import sid/host information
         UNIX> trgint.sh SERVER.dat evnt/evnt_password@mgm_tns_alias


   3.4 HOW TO REGISTER STAND ALONE HOST(S)?
   
      To register hosts that don't have Oracle databases installed
      use "trgint.sh" program leaving sid related information blank:
      
         UNIX> cd $SYS_TOP/bin
         UNIX> vi SERVER.dat
         
            -- SERVER.dat EXAMPLE START
            server_name1,"Server1 Desc",,,,,

         ## import sid/host information
         UNIX> trgint.sh SERVER.dat evnt/evnt_password@mgm_tns_alias

   3.5 HOW DO PRIMARY/SECONDARY NOTIFICATIONS WORK (acknowledgments)
      
      1. acknowledgment is required for the first trigger occurrence ONLY
      2. PRIMARY pager is notified every "ack_notif_freq" minutes
      3. SECONDARY pager is notified when PRIMARY has received "ack_notif_tres" 
         notifications and "ack_notif_freq" minutes has elapsed since the last PRIMARY 
         notification
      4. notifications are not send for subsequent and "CLEARED" event triggers 
         created by event assignments who's page list require acknowledgment; this is 
         done to suppress unnecessary pages in the middle of the night (the typical 
         case for these types of page lists is to have 24/7 pagers)

________________________________________________________________________________
            Copyright (c) 2009 HASHJOIN Corporation All rights reserved.