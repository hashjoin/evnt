usage()
{
echo "`basename $0` <ea_id>"
exit 1;
}


sqlplus -s $uname_passwd <<EOF
VARIABLE out_ref_id NUMBER
BEGIN
   evnt_util_pkg.set_event_env($1,:out_ref_id);
END;
/
set lines 3000
set trims on
set feed off
set pages 0
spool env.log
SELECT eupo_out
FROM   evnt_util_pkg_out
WHERE  eupo_ref_id = :out_ref_id;
spool off
exit
EOF
. env.log

