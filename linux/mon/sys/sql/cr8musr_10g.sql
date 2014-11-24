-- $Id$
--
CREATE USER MON IDENTIFIED BY justagate
DEFAULT TABLESPACE USERS
TEMPORARY TABLESPACE TEMP
QUOTA 5g ON USERS;


GRANT CONNECT, CREATE TABLE, CREATE VIEW, CREATE PROCEDURE TO MON ;

GRANT SELECT ON v_$sort_segment   TO MON ;
GRANT SELECT ON v_$sort_usage     TO MON ;
GRANT SELECT ON v_$parameter      TO MON ;
GRANT SELECT ON v_$instance       TO MON ;
GRANT SELECT ON v_$loghist        TO MON ;
GRANT SELECT ON v_$session        TO MON ;
GRANT SELECT ON v_$process        TO MON ;
GRANT SELECT ON v_$sqltext        TO MON ;
GRANT SELECT ON v_$session_wait   TO MON ;
GRANT SELECT ON v_$session_event  TO MON ;
GRANT SELECT ON v_$locked_object  TO MON ;
GRANT SELECT ON v_$sysstat        TO MON ;
GRANT SELECT ON v_$lock           TO MON ;
GRANT SELECT ON v_$sql            TO MON ;
GRANT SELECT ON v_$sesstat        TO MON ;
GRANT SELECT ON v_$statname       TO MON ;
GRANT SELECT ON v_$rollname       TO MON ;
GRANT SELECT ON v_$rollstat       TO MON ;
GRANT SELECT ON v_$waitstat       TO MON ;
GRANT SELECT ON v_$system_event   TO MON ;
GRANT SELECT ON v_$transaction    TO MON ;
GRANT SELECT ON v_$sqlarea        TO MON ;
GRANT SELECT ON v_$event_name     TO MON ;
GRANT SELECT ON v_$active_session_history TO MON ;
GRANT SELECT ON v_$sqltext_with_newlines TO MON ;
GRANT SELECT ON v_$session_longops TO MON ;

GRANT SELECT ON v_$filestat       TO MON ;
GRANT SELECT ON v_$datafile       TO MON ;
GRANT SELECT ON sys.ts$          TO MON;
GRANT SELECT ON sys.filext$      TO MON;
GRANT SELECT ON sys.file$        TO MON;

GRANT SELECT ON dba_users      TO MON ;
GRANT SELECT ON dba_objects    TO MON ;
GRANT SELECT ON dba_segments   TO MON ;
GRANT SELECT ON dba_services   TO MON ;
GRANT SELECT ON dba_free_space TO MON ;
GRANT SELECT ON dba_data_files TO MON ;
GRANT SELECT ON dba_tables     TO MON ;
GRANT SELECT ON dba_indexes    TO MON ;
GRANT SELECT ON dba_rollback_segs  TO MON ;
GRANT SELECT ON dba_hist_seg_stat TO MON;
GRANT SELECT, REFERENCES ON dba_hist_snapshot TO MON;
GRANT SELECT ON dba_hist_seg_stat_obj TO MON;


GRANT SELECT ON sys.obj$  TO MON ;
GRANT SELECT ON sys.user$ TO MON ;


GRANT SELECT,REFERENCES ON gv_$locked_object to MON;
GRANT SELECT,REFERENCES ON gv_$lock to MON;
GRANT SELECT,REFERENCES ON gv_$session to MON;
GRANT SELECT,REFERENCES ON gv_$sqltext_with_newlines to MON;
GRANT SELECT,REFERENCES ON gv_$session_wait to MON;
GRANT SELECT,REFERENCES ON gv_$asm_diskgroup to MON;
GRANT SELECT,REFERENCES ON gv_$asm_operation to MON;
GRANT SELECT,REFERENCES ON gv_$sysstat to MON;
GRANT SELECT,REFERENCES ON gv_$service_stats to MON;

GRANT execute ON DBMS_LOCK TO MON;

drop table MON.sid_list;
create table MON.sid_list(
et_id   number(15) not null,
inst_id number not null,
sid     number not null,
constraint sid_list_pk primary key (et_id,inst_id,sid))
organization index;

drop table MON.gv_lock_mon;
create table MON.gv_lock_mon as select * from gv$lock where 1=2;
alter table MON.gv_lock_mon add (batch_id number(15));
create index MON.gv_lock_mon_indx on MON.gv_lock_mon(batch_id,type,block);

drop table MON.gv_session;
create table MON.gv_session as select x.*, x.sql_address sql_address_mon, x.sql_hash_value sql_hash_value_mon from gv$session x where 1=2;
alter table MON.gv_session add (batch_id number(15));
create index MON.gv_session_indx on MON.gv_session(batch_id,inst_id,sid);

--drop table MON.gv_sqltext_with_newlines;
--create table MON.gv_sqltext_with_newlines as select * from gv$sqltext_with_newlines x where 1=2;
--alter table MON.gv_sqltext_with_newlines add (batch_id number(15));
--create index MON.gv_sqltext_with_newlines_indx on MON.gv_sqltext_with_newlines(batch_id,inst_id,address,hash_value);

drop table MON.mon_refresh_q;
create table MON.mon_refresh_q(
    table_name      varchar2(30) not null
,   refreshed_date  date         not null
,   batch_id        number(15,0) not null
,   CONSTRAINT mrq_PK primary key (table_name));

insert into MON.mon_refresh_q
(table_name,refreshed_date,batch_id)
values
(upper('gv_lock_mon'),sysdate-10,0);

insert into MON.mon_refresh_q
(table_name,refreshed_date,batch_id)
values
(upper('gv_session'),sysdate-10,0);



create or replace procedure mon.pt
( p_query in varchar2,
  p_nulls in boolean default true )
AUTHID CURRENT_USER
is
    l_theCursor     integer default dbms_sql.open_cursor;
    l_columnValue   varchar2(4000);
    l_status        integer;
    l_descTbl       dbms_sql.desc_tab;
    l_colCnt        number;
begin
    execute immediate
    'alter session set
        nls_date_format=''dd-mon-yyyy hh24:mi:ss'' ';

    dbms_sql.parse(  l_theCursor,  p_query, dbms_sql.native );
    dbms_sql.describe_columns
    ( l_theCursor, l_colCnt, l_descTbl );

    for i in 1 .. l_colCnt loop
        dbms_sql.define_column
        (l_theCursor, i, l_columnValue, 4000);
    end loop;

    l_status := dbms_sql.execute(l_theCursor);

    while ( dbms_sql.fetch_rows(l_theCursor) > 0 ) loop
        for i in 1 .. l_colCnt loop
            dbms_sql.column_value
            ( l_theCursor, i, l_columnValue );
                        if ( p_nulls OR l_columnValue is not null )
                        then
                dbms_output.put_line
                ( rpad( l_descTbl(i).col_name, 30 )
                || ': ' ||
                substr( l_columnValue, 1, 200 ) );
                        end if;
        end loop;
        dbms_output.put_line( '-----------------' );
    end loop;
    execute immediate
        'alter session set nls_date_format=''dd-MON-rr'' ';
exception
    when others then
      execute immediate
          'alter session set nls_date_format=''dd-MON-rr'' ';
      raise;
end;
/


create or replace procedure MON.mon_refresh_proc(p_table_name  in varchar2,
                                             p_max_lag     in number,
                                             p_max_batches in number,
                                             p_batch_id    in out number)
as
    l_refreshed_date    date;
    l_max_batch         integer;
    we_are_done         exception;
    resource_busy       exception;

    pragma exception_init( resource_busy, -54 );

    function next_batch(p_max in number, p_curr in number) return number
    is
        l_return number;
    begin
        if ( p_curr >= p_max )
        then l_return := 1;
        else l_return := p_curr+1;
        end if;
        dbms_output.put_line('p_curr = '||p_curr);
        dbms_output.put_line('p_max = '||p_max);
        dbms_output.put_line('parsed batch_id = '||l_return);
        return l_return;
    end;
begin
    p_batch_id := null;

    select refreshed_date, batch_id
      into l_refreshed_date, p_batch_id
      from mon_refresh_q
     where table_name = upper(p_table_name)
     for update;

    if ( l_refreshed_date >= sysdate-(p_max_lag/24/60/60) )
    then
        --commit;
        raise we_are_done;
    end if;

    -- if we got here refresh
    if ( upper(p_table_name) = 'GV_LOCK_MON' )
    then
        p_batch_id := next_batch(p_max_batches,p_batch_id);

        delete gv_lock_mon where batch_id=p_batch_id;
        insert into gv_lock_mon select l.*, p_batch_id from gv$lock l;
    end if;

    if ( upper(p_table_name) = 'GV_SESSION' )
    then
        p_batch_id := next_batch(p_max_batches,p_batch_id);

        delete gv_session where batch_id=p_batch_id;
        insert into gv_session select l.*,
            decode(rawtohex(sql_address),'00',prev_sql_addr,sql_address),
            decode(sql_hash_value,0,prev_hash_value,sql_hash_value),
            p_batch_id
        from gv$session l;
    end if;

    update mon_refresh_q
       set refreshed_date = sysdate
       ,   batch_id = p_batch_id
     where table_name = upper(p_table_name);
    --commit;

exception
    when we_are_done then null;
end;
/
show errors


grant execute on dbms_workload_repository to mon;

create or replace procedure MON.awr_refresh_proc(p_max_lag in number)
as
    l_snap_id number;
begin
    select max(snap_id)
      into l_snap_id
      from dba_hist_snapshot
     where end_interval_time >= sysdate-(p_max_lag/24/60);

    if ( l_snap_id is null )
    then
        dbms_workload_repository.create_snapshot();
    else
        dbms_output.put_line(l_snap_id);
    end if;
end;
/
show errors

-- 10G
drop table MON.top_sessions;
CREATE GLOBAL TEMPORARY TABLE MON.top_sessions ON COMMIT DELETE ROWS
as
select ash.SAMPLE_ID ea_id,
       w.secs ash_secs,
       s.machine,
       s.process,
       s.OSUSER,
       s.PADDR,
       s.LOGON_TIME,
       s.service_name,
       ash.*
from v$active_session_history ash
,    (
        select count(*) secs, min(sample_id) mins, max(sample_id) maxs, session_id,session_serial#
        from v$active_session_history
        where sample_time > sysdate-5/24/60
        --and session_type <> 'BACKGROUND'
        group by session_id,session_serial#
        having count(*) > 30
     ) w
,    v$session s
where (ash.sample_id between w.mins and w.maxs)
  and ash.session_id = w.session_id
  and ash.session_serial# = w.session_serial#
  and ash.session_id = s.sid(+)
  and ash.session_serial# = s.serial#(+)
  and 1=2
;

