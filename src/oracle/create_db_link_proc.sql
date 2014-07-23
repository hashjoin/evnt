CREATE OR REPLACE PROCEDURE CREATE_DB_LINK
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : create_db_link
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : create_db_link_proc.sql
-- DATE CREATED  : 04/02/2001
-- APPLICATION   : EVENTS
-- VERSION       : 1.4
-- DESCRIPTION   : Various Utils (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 05/17/2002   vmogilev    created
-- 03/20/2003   vmogilev    (1.1) fixed bug with mixed case db links
-- 05/17/2008	vmogilev	(1.2) fixed bug with XAGP/AGP db links overlaps
-- 09/29/2009	vmogilev	(1.3) added prefix to all ENVT db link to fix issue with SIDS that start with a number such as 10GR2
--                                    where were causing "ORA-01729: database link name expected" error
-- 07/23/2014	vmogilev	(1.4) switched to using P_TNS_ALIAS for l_db_link_name (used to be p_sid)
-- ---------------------------------------------------------------------
 (P_SID IN VARCHAR2
 ,P_USERNAME IN VARCHAR2
 ,P_PASSWORD IN VARCHAR2
 ,P_TNS_ALIAS IN VARCHAR2
 ,P_DB_LINK_NAME OUT VARCHAR2
 )
 IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   CURSOR cull_db_link_cur(p_db_link_name VARCHAR2,
                           p_username     VARCHAR2) IS
      SELECT db_link, username, host
      FROM user_db_links
      --WHERE INSTR(db_link,UPPER(p_db_link_name)) > 0
      WHERE db_link like UPPER(p_db_link_name)||'%'
      AND   username = UPPER(p_username);
   l_db_link_name SID_CREDENTIALS.sc_db_link_name%type;
   l_curr_sql VARCHAR2(4000);
   cull_db_link cull_db_link_cur%ROWTYPE;
BEGIN
   --l_db_link_name := 'evnt_'||p_sid||'_'||p_username ;
   l_db_link_name := 'evnt_'||P_TNS_ALIAS||'_'||p_username ;
   OPEN cull_db_link_cur(l_db_link_name, p_username);
   FETCH cull_db_link_cur INTO cull_db_link;
   IF cull_db_link_cur%FOUND THEN
      dbms_output.put_line('FOUND');
      CLOSE cull_db_link_cur;
      EXECUTE IMMEDIATE 'DROP DATABASE LINK '||l_db_link_name ;
   END IF;
   l_curr_sql :=  'CREATE DATABASE LINK '||l_db_link_name||
                  ' CONNECT TO '||p_username||
                  ' IDENTIFIED BY '||p_password||
                  ' USING '||chr(39)||p_tns_alias||chr(39) ;
   dbms_output.put_line(l_curr_sql);
   EXECUTE IMMEDIATE l_curr_sql;
   p_db_link_name := l_db_link_name;
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001,'ERROR: '|| sqlerrm ||CHR(10)||'STMNT: '||CHR(10)|| l_curr_sql);
END create_db_link;
/

