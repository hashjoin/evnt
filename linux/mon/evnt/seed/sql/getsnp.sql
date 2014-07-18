REM
REM DBAToolZ NOTE:
REM     This script is configured to work with SQL Directory (SQLDIR).
REM     SQLDIR is a utility that allows easy organization and
REM     execution of SQL*Plus scripts using user-friendly menu.
REM     Visit DBAToolZ.com for more details and free SQL scripts.
REM
REM
REM     Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
REM
REM File:
REM     getsnp.sql
REM
REM <SQLDIR_GRP></SQLDIR_GRP>
REM
REM Author:
REM     Vitaliy Mogilevskiy
REM     VMOGILEV
REM     (vit100gain@earthlink.net)
REM
REM Purpose:
REM     <SQLDIR_TXT>
REM     Gets curr/prev snapshot table names for events that
REM     are based on collections.
REM
REM     NOTES:
REM     ========
REM       1. if collection is running it will sleep until it's done.
REM     
REM       2. collection will be locked during this event to prevent
REM          changes to curr/prev tables
REM     
REM       3. if curr/prev tables are not present or if collection
REM          does not have PENDING status this event will fail
REM          THIS IS BY DESIGN do not modify since if I handle
REM          this exception user might believe that everything is OK
REM          even if collections are not running
REM     </SQLDIR_TXT>
REM
REM Usage:
REM     getsnp.sql <CP_CODE> <S_ID> <CA_ID>
REM        <CP_CODE> = coll_parameters.cp_code
REM        <S_ID>    = sids.s_id
REM        <CA_ID>   = coll_assigments.ca_id
REM
REM Example:
REM     getsnp.sql EVNT_DBEVNT 1 25
REM
REM
REM
REM History:
REM     12-17-2002      VMOGILEV        Created
REM     01-28-2002      VMOGILEV        Made compatible with 1.8.1
REM     10-21-2013      VMOGILEV        Added alter session set recyclebin=off;
REM
REM

alter session set recyclebin=off;

set serveroutput on size 100000
set trims on

col l_out_csnp noprint new_value X_out_csnp
col l_out_psnp noprint new_value X_out_psnp

VARIABLE l_out_csnp VARCHAR2(256);
VARIABLE l_out_psnp VARCHAR2(256);

BEGIN
   coll_util_pkg.evnt_snps(
      p_cp_code  => '&1'
   ,  p_s_id     => '&2'
   ,  p_ca_id    => '&3'
   ,  p_out_csnp => :l_out_csnp
   ,  p_out_psnp => :l_out_psnp);
END;
/

print l_out_csnp
print l_out_psnp

