-- make sure to grant the following to MON user:
--    grant select on table_delete_audit to mon;
--    grant select on table_delete_audit_sql to mon;

-- VM 06-28-2004
-- ----------------
-- I am removing USERNAME group by to limit the number of rows
-- in the TRIGGER ATTRIBUTE we still get the detailed OUTPUT

select table_owner
||','||table_name
||','||count(*)
from system.table_delete_audit
group by table_owner, table_name
order by table_owner, table_name;

