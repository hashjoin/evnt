-- $header$ unauth_delete.out.sql v1.2
-- 08-FEB-2006	VMOGILEV	(1.2) limited number of rows to 20

set lines 115
set pages 60
set trims on

set feed off
alter session set nls_date_format='RR-MON-DD HH24:MI';
set feed on

col table_owner format a7 trunc heading "Owner"
col table_name format a15 trunc heading "Table"
col USERNAME format a10 trunc 
col OSUSER   format a8 trunc
col MACHINE  format a8 trunc
col process format a8
col program format a12 trunc
col row_id format a20

ttit "Detail of last 20 deletes"

select * from (
select row_id, table_owner, table_name, username, program, osuser, machine, process, delete_date
from system.table_delete_audit
--order by table_owner, table_name, delete_date
order by delete_date desc)
where rownum < 21;

