# ------------------------------------------------------------------------------
#         Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
# ------------------------------------------------------------------------------
# FILE:		README_DEMO.txt
# VERSION:	v3.5.02
# LOCATION:	http://kb.dbatoolz.com/ex/uploads/4389.EVNT_DEMO.txt
# ABOUT:	(EVNT) EVNT - DEMO Event Monitoring System
# CONTACT:	http://kb.dbatoolz.com/tp/1458.evnt_support.html
# ------------------------------------------------------------------------------

1. INSTALLATION
   
   1.0 SOFTWARE REQUIREMENTS
   1.1 CONFIGURE WEB SERVER
   1.2 INSTALL DEMO REPOSITORY
   
2. WHAT'S NEXT?

   2.0 LOGIN TO REPOSITORY

3. FAQ

   3.1 HOW TO DROP DEMO REPOSITORY?

________________________________________________________________________________          

1. INSTALLATION
      
   
   1.0 SOFTWARE REQUIREMENTS
   
      Database/Web Server
      --------------------
         ORACLE RDBMS 8.1.7.4 with Partitioning Option 
            (Personal Oracle 8i will work)
         Oracle IAS with PL/SQL Toolkit
            (IAS that is shipped with Oracle 8i will work)
      

   1.1 CONFIGURE WEB SERVER
   
      ***********************************************
      *** BEFORE YOU BEGIN MAKE SURE TO READ $1.0 ***
      ***********************************************
      
      Configure IAS PL/SQL Toolkit on the web server
      you designated to serve EVNT's mod_plsql pkgs
      -------------------------------------------------
         UNIX> vi $ORACLE_HOME/Apache/modplsql/cfg/wdbsvr.app
         
         WINDOWS> write <VALUE_OF_ORACLE_HOME_FROM_REGEDIT>\Apache\modplsql\cfg\wdbsvr.app
         EXAMPLE:
         WINDOWS> write C:\oracle\ora81\Apache\modplsql\cfg\wdbsvr.app
         
         ADD THE FOLLOWING:
         	cut an paste from
         	   http://kb.dbatoolz.com/ex/uploads/4389.wdbsvr.app.example.txt
         	(make sure to change <mgm_tns_alias> to the TNS Alias of your database)
         
         bounce IAS
      

   1.2 INSTALL DEMO REPOSITORY
      
      Unzip evnt_demo.dmp.gz using whatever unzip utility you prefer (gunzip, 
      unzip, etc.)
   
      WARNING:
         DO NOT INSTALL THIS DEMO on the same database that hosts your existing 
         repository!  It should be installed on a separate database with at 
         least 300mb of free space in TOOLS tablespace (based on 160K extents).
      
      Prepare database for demo import.  Login to sqlplus as SYS and execute the 
      following commands:

         CREATE USER webproc identified by welcome
         DEFAULT TABLESPACE tools
         TEMPORARY TABLESPACE temp;
         GRANT CONNECT TO webproc;
         CREATE ROLE webproc_role;
         GRANT webproc_role TO webproc;
         CREATE user evnt identified by evnt;
         alter user evnt default tablespace tools;
         alter user evnt temporary tablespace temp;
         grant connect , resource to evnt;
         GRANT ALTER SESSION TO evnt;
         GRANT EXECUTE ON dbms_lock TO evnt;
         GRANT CREATE DATABASE LINK TO evnt;
         GRANT CREATE TABLE TO evnt;
         GRANT CREATE PUBLIC SYNONYM TO evnt;      
      
      Import demo repository:
         imp evnt/evnt file=evnt_demo.dmp log=evnt_demo.dmp.imp_log

      Import should complete with the following message:
         "Import terminated successfully without warnings."

2. WHAT'S NEXT?

   2.0 LOGIN TO REPOSITORY
      
      If you configured your IAS mod_plsql module as described in
      $1.1 your should be able to login to EVNT repository using
      the following URL:
      
         http://webserver.yourcom.com/pls/EVNT/web_nav_pkg.evnt
      
      Change "webserver.yourcom.com" to the webserver name you configured in 
      $1.1.  This page is password protected, any user that was given 
      webproc_role (see $2.2) can login and use the repository.  Installation 
      process creates one seeded account that has webproc_role it's called 
      WEBPROC the default password is WELCOME.


3. FAQ

   3.1 HOW TO DROP DEMO REPOSITORY?
      
      Login to sqlplus as SYS or SYSTEM and issue the following commands:
         drop user EVNT cascade;
         drop user WEBPROC cascade;
         drop role WEBPROC_ROLE;


________________________________________________________________________________
            Copyright (c) 2009 HASHJOIN Corporation All rights reserved.