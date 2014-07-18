REM
REM DBAToolZ NOTE:
REM	This script was obtained from DBAToolZ.com
REM	It's configured to work with SQL Directory (SQLDIR).
REM	SQLDIR is a utility that allows easy organization and
REM	execution of SQL*Plus scripts using user-friendly menu.
REM	Visit DBAToolZ.com for more details and free SQL scripts.
REM
REM 
REM File:
REM 	c_user_rbs.sql
REM
REM <SQLDIR_GRP>RBS USER TRACE</SQLDIR_GRP>
REM 
REM Author:
REM 	Frank Naude (frank@onwe.co.za)
REM 
REM Purpose:
REM	<SQLDIR_TXT>
REM	Shows active (in progress) transactions
REM	</SQLDIR_TXT>
REM
REM Usage:
REM	c_user_rbs.sql
REM 
REM Example:
REM	c_user_rbs.sql
REM
REM
REM History:
REM	04-12-1998	Frank Naude	Created
REM	09-07-2001	VMOGILEV	Added to DBAToolZ
REM
REM

set verify off
set lines 132
set pages 60

set feed off
col bk_size new_value x noprint

select value bk_size from v$parameter where name = 'db_block_size';

set feed on

col sid format 999 headin "Sid"
col name format a8
col username format a8
col USED_kb format 9999999 heading "Used|KB"
col osuser format a15
col start_time format a17
col status format a12
col terminal format a10
tti 'All Active transactions'

select sid, serial#,s.status,username, terminal, osuser,
       t.start_time, r.name, (t.used_ublk*'&x')/1024 USED_kb, t.used_ublk "ROLLB BLKS",
       decode(t.space, 'YES', 'SPACE TX',
          decode(t.recursive, 'YES', 'RECURSIVE TX',
             decode(t.noundo, 'YES', 'NO UNDO TX', t.status)
       )) status
from sys.v_$transaction t, sys.v_$rollname r, sys.v_$session s
where t.xidusn = r.usn
  and t.ses_addr = s.saddr
  order by sid
/

