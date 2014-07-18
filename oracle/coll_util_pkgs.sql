CREATE OR REPLACE PACKAGE coll_util_pkg AS
-- =============================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =============================================================================
-- PROGRAM NAME  : coll_util_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : coll_util_pkgs.sql
-- DATE CREATED  : 07/02/2002
-- APPLICATION   : COLLECTIONS
-- VERSION       : 1.8.8
-- DESCRIPTION   : Various Utils (see module for the details)
-- EXAMPLE       :
-- =============================================================================
-- MODIFICATION HISTORY
-- =============================================================================
-- DATE      NAME          DESCRIPTION
-- -----------------------------------------------------------------------------
-- 07/02/02  vmogilev    created
--
-- 12/17/02  vmogilev    evnt_snps - created for event system calls
--
-- 12/18/02  vmogilev    evnt_snps - added coll_chk_cur cursor to
--                          enable colletion lock while event based
--                          on this collections is running
--                       grant_select - created to be called from
--                          evnt_snps to avoid implicit commit
--                       evnt_snps - added coll_running_cur to check
--                          for running collections
--
-- 12/30/02  vmogilev    fix_coll_internal - added two more "fixes"
--                          for C/P and P/O failures
--
-- 01/16/03  vmogilev    (1.7.1)
--                       part_enabled - created
--                          I am moving towards having partitioned
--                          ARCHIVE as an option vs requirement
--                          this will enable running on Standard
--                          version of Oracle database as well as
--                          reduce number of partitions for collections
--                          that don't generate a lot of data
--
-- 01/23/03  vmogilev    (1.7.2)
--                       renamed part_enabled to part_allowed
--                          changed part_cur CUR to v$option
--                          vs. v$version.  I am going back to
--                          having PARTITIONING as a requirement
--                          for this product since personal Oracle 8i
--                          has PARTITIONING option and is pretty cheap
--                          making it affordable for smaller clients
--
-- 01/26/03  vmogilev    (1.7.3)
--                       fix_coll_internal - fixed a bug where
--                          ORA-01403: no data found was raised
--                          when trying to create empty missing sn
--                          tables because I had tablespace_name
--                          together with COUNT(*) in the SELECT INTO.
--                          Pulled tablespace_name out of it and placed
--                          in later in the create table IF/THEN
--
--
-- 01/27/03  vmogilev    (1.7.4)
--                       evnt_get_ca - created to be called from
--                          events (evntcoll.sh)
--                          IF collections assigment doesn't exist
--                          creates one
--
-- 01/28/03  vmogilev    (1.8.1)
--                       *** NOT COMPATABLE WITH PREVIOUS VERSIONS
--                       evnt_get_ca
--                       evnt_snps
--                       fix_coll_internal
--                       pull
--                       get_view
--                          To guarantee uniqueness of collection tables     
--                          when same collection is scheduled agaist same 
--                          sid embedded CA_ID into the pull table
--                          
--                          effected external code:
--                            o all coll based events
--                            o collproc.sh [coll_util_pkg.get_view]
--                            o evntcoll.sh [coll_util_pkg.evnt_get_ca]
--                            o getsnp.sql  [coll_util_pkg.evnt_snps]
--
-- 01/29/03  vmogilev   (1.8.2)
--                      evnt_get_ca - added check for failed collections
--                         to avoid creating a new CA if prev. CA failed
--
--                         OLD BEHAVIOR - if not found CA.CA_PHASE_CODE='P'
--                            create new CA
--                         NEW BEHAVIOR - if CA.CA_PHASE_CODE='E'
--                            fail the event
--
-- 01/31/03  vmogilev   (1.8.3)
--                      exec_sql - created to avoid implicit commit
--                         from pull procedure
--                      fix_coll - fixed bug with ca_id not being passed
--                         to fix_coll_internal
--                      fix_coll_internal - dbms_output parameters and
--                         table names
--                      pull - made many changes to flow of the program
--                         making sure that updates to history table 
--                         take place only after dynamic SQL execs
--                         to avoid inconsistency in history and real
--
-- 02/03/03  vmogilev   (1.8.4)
--                      evnt_get_ca - 
--                         I NO LONGER FAIL AN EVEN IF COLLECTION
--                         IS FAILED.  I am working on stabilizing
--                         pull procedure to avoid unrecoverable failures
--                         so that when collection fails you simply rerun it
--                         without the need for cleanups using coll_fix
--                         
--                         EXTERNAL CHANGES:
--                            colllist.sh - change ca_phase_code from 
--                               = 'P' to IN ('P','E')
--
-- 02/05/03  vmogilev   (1.8.5)
--                      exec_sql - added commit to avoid "ORA-06519"
--
-- 02/26/03  vmogilev   (1.8.6)
--                      evnt_snps - filtered our archived snaps (A) from
--                         being dbms_output(ed) to avoid for potential
--                         blowup of the dbms output buffer, only loop
--                         thru C and P snaps now
--
-- 03/27/03  vmogilev   (1.8.7)
--                      set_pend - created
--
-- 03/28/03  vmogilev   (1.8.8)
--                      set_pend - moved to glob_util_pkg 
-- -----------------------------------------------------------------------------
PROCEDURE evnt_get_ca(
   p_cp_code  IN VARCHAR2 DEFAULT NULL
,  p_s_id     IN NUMBER   DEFAULT NULL
,  p_sc_id    IN NUMBER   DEFAULT NULL
,  p_pl_id    IN NUMBER   DEFAULT NULL
,  p_ea_id    IN NUMBER   DEFAULT NULL
,  p_ca_id_out OUT NUMBER
,  p_ret_code  OUT VARCHAR2);

PROCEDURE evnt_snps(
   p_cp_code IN VARCHAR2
,  p_s_id    IN NUMBER
,  p_ca_id   IN NUMBER
,  p_out_csnp OUT VARCHAR2
,  p_out_psnp OUT VARCHAR2);

PROCEDURE set_coll_env(
   p_ca_id        IN NUMBER
,  p_out_s_id     OUT NUMBER
,  p_out_c_id     OUT NUMBER
,  p_out_cp_id    OUT NUMBER
,  p_out_sc_id    OUT NUMBER
,  p_out_rcon_str OUT VARCHAR2
,  p_out_db_link  OUT VARCHAR2);

PROCEDURE get_view(
   p_c_id IN NUMBER
,  p_cp_id IN NUMBER
,  p_ca_id IN NUMBER
,  p_view_code OUT VARCHAR2
,  p_view_name OUT VARCHAR2);

PROCEDURE pull(
   p_c_id IN NUMBER
,  p_cp_id IN NUMBER
,  p_s_id IN NUMBER
,  p_ca_id IN NUMBER
,  p_view_name IN VARCHAR2
,  p_db_link IN VARCHAR2);

PROCEDURE ctrl(
   p_ca_id IN NUMBER
,  p_stage IN VARCHAR2);

FUNCTION collection_on_hold(
   p_ca_id IN NUMBER
,  p_hold_reason OUT VARCHAR2)
RETURN BOOLEAN;

PROCEDURE fix_coll(
   p_ca_id IN NUMBER DEFAULT NULL);

FUNCTION part_allowed RETURN BOOLEAN;

/* global vars */
g_view_pref CONSTANT VARCHAR2(11) := 'coll_pull__';

END coll_util_pkg;
/
show error
