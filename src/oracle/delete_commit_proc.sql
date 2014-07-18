create or replace procedure DELETE_COMMIT
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : DELETE_COMMIT
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : delete_commit_proc.sql
-- DATE CREATED  : 10/28/2002
-- APPLICATION   : GLOBAL
-- VERSION       : 1.0
-- DESCRIPTION   : DELETE_COMMIT large delete stmns
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 10/28/02  vmogilev    created (based on procedure from oracle support)
-- ---------------------------------------------------------------------
( p_statement in varchar2,
  p_commit_batch_size   in number default 10000)
is
        cid                             integer;
        changed_statement               varchar2(2000);
        finished                        boolean;
        nofrows                         integer;
        lrowid                          rowid;
        rowcnt                          integer;
        errpsn                          integer;
        sqlfcd                          integer;
        errc                            integer;
        errm                            varchar2(2000);
begin
  /*
  || If the actual statement contains a WHERE clause, then append a
  || rownum < n clause after that using AND, else use WHERE
  || rownum < n clause
  */
  if ( upper(p_statement) like '% WHERE %')
  then
     changed_statement := p_statement||' AND rownum < '||to_char(p_commit_batch_size + 1);
  else
     changed_statement := p_statement||' WHERE rownum < '||to_char(p_commit_batch_size + 1);
  end if;


  begin
     -- Open a cursor for the task
     cid := dbms_sql.open_cursor;

     -- parse the cursor.
     dbms_sql.parse(cid,changed_statement, dbms_sql.native);

     -- store for some future reporting
     rowcnt := dbms_sql.last_row_count;
  exception
     when others
     then
     	-- gives the error position in the changed sql
        -- delete statement if anything happens
        errpsn := dbms_sql.last_error_position;

        -- function code can be found in the OCI manual
        sqlfcd := dbms_sql.last_sql_function_code;


        -- store all these values for error reporting. However
        -- all these are really useful in a stand-alone proc
        -- execution for dbms_output to be successful, not
        -- possible when called from a form or front-end tool.
        lrowid := dbms_sql.last_row_id;
        errc := SQLCODE;
        errm := SQLERRM;
        dbms_output.put_line('Error '||to_char(errc)||
                             ' Posn '||to_char(errpsn)||
                        ' SQL fCode '||to_char(sqlfcd)||
                            ' rowid '||rowidtochar(lrowid));

        -- this will ensure the display of at least the error
        -- message if something happens, even in a front-end
        -- tool.
        raise_application_error(-20000,errm);
   end;



   finished := FALSE;
   while not (finished)
   loop
      -- keep on executing the cursor till there is no more to process.
      begin
         nofrows := dbms_sql.execute(cid);
         rowcnt := dbms_sql.last_row_count;
      exception
         when others
         then
            errpsn := dbms_sql.last_error_position;
            sqlfcd := dbms_sql.last_sql_function_code;
            lrowid := dbms_sql.last_row_id;
            errc := SQLCODE;
            errm := SQLERRM;
            dbms_output.put_line('Error '||to_char(errc)||
                                 ' Posn '||to_char(errpsn)||
                            ' SQL fCode '||to_char(sqlfcd)||
                                ' rowid '||rowidtochar(lrowid));
            raise_application_error(-20000,errm);
      end;

      if nofrows = 0
      then
         finished := TRUE;
      else
         finished := FALSE;
      end if;
      commit;
   end loop;


   begin
      -- close the cursor for a clean finish
      dbms_sql.close_cursor(cid);
   exception
      when others
      then
         errpsn := dbms_sql.last_error_position;
         sqlfcd := dbms_sql.last_sql_function_code;
         lrowid := dbms_sql.last_row_id;
         errc := SQLCODE;
         errm := SQLERRM;
         dbms_output.put_line('Error '||to_char(errc)||
                              ' Posn '||to_char(errpsn)||
                         ' SQL fCode '||to_char(sqlfcd)||
                             ' rowid '||rowidtochar(lrowid));
         raise_application_error(-20000,errm);
    end;
end;
/


prompt EXAMPLES:
prompt ========
prompt -- execute DELETE_COMMIT('delete from SALES where Customer_ID=12',1000);
prompt -- execute DELETE_COMMIT('delete from SALES where State_Code = ''NH''',500)
