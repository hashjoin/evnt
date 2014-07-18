set scan off

CREATE OR REPLACE PACKAGE BODY glob_web_pkg AS
/* GLOBAL FORMATING */
   d_THC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('THC');  /* Table Header Color     */
   d_TRC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRC');  /* Table Row Color        */
   d_TRSC web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRSC'); /* Table SubRow Color        */
   d_PHCM web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCM'); /* Page Header Main Color */
   d_PHCS web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCS'); /* Page Header Sub Color  */

   d_BRC_A web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('BRC_A'); /* Blackout Row Color ACTIVE */

   d_LRC_A web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('LRC_A'); /* Page List Email Row Color ACTIVE */
   d_LRC_I web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('LRC_I'); /* Page List Email Row Color INACTIVE */

-- PRIVATE MODULES
--

FUNCTION trim_all(
   p_string IN VARCHAR2) RETURN VARCHAR2
IS
-- =====================================================================
-- PROGRAM NAME  : trim_all
-- DESCRIPTION   : trims all SPACES and TABS from begging of the string
--                 LTRIM can only trims occurences of similar chars
--                 at a time making it very hard to trim the following:
--                  'SPACE|TAB|SPACE|TAB|TAB|some_string'
--                 you get the picture ...
-- ---------------------------------------------------------------------
   l_len INTEGER;
   l_cur_char VARCHAR2(1);
   l_str  VARCHAR2(32000);
   l_cur_str VARCHAR2(32000);
   l_trim_char VARCHAR2(20) := CHR(9)||CHR(10)||CHR(13)||CHR(32);
BEGIN
   l_str := p_string;
   l_len := LENGTH(l_str);

   FOR i IN 1..l_len LOOP
      l_cur_char := SUBSTR(l_str,i,1);

      --dbms_output.put_line('PASS_'||i||': ['||l_cur_char||']');

      l_cur_str := SUBSTR(l_str,i);

      IF ( INSTR(l_trim_char,l_cur_char) > 0 ) THEN
         NULL;
      ELSE
         exit;
      END IF;

   END LOOP;

   l_str := l_cur_str;

   RETURN l_str;
END trim_all;


FUNCTION highlight(
   p_pos IN INTEGER
,  p_string IN VARCHAR2) RETURN VARCHAR2
IS
   l_return_string VARCHAR2(32000);
BEGIN
   SELECT htf.escape_sc(SUBSTR(p_string,1,p_pos))||
             '<font color="red"><b>'||
             htf.escape_sc(SUBSTR(p_string,p_pos+1,1))||
             '</b></font>'||
             htf.escape_sc(SUBSTR(p_string,p_pos+2))
   INTO l_return_string
   FROM dual;
   
   RETURN l_return_string;
END highlight;


PROCEDURE parse_binds(
   p_query      IN VARCHAR2
,  p_bind_cnt   OUT INTEGER
,  p_bind_array OUT char_array)
IS
   l_query LONG; 
   l_char VARCHAR2(1); 
   l_in_quotes BOOLEAN DEFAULT FALSE; 
   l_in_bind   BOOLEAN DEFAULT FALSE; 
   l_bind_array char_array;
   l_bind_name  VARCHAR2(255);
   l_bind_cnt  INTEGER DEFAULT 0;
   -- CHR(10) = line feed
   -- CHR(13) = carriage return
   -- CHR(9) = tab
   l_delimeters VARCHAR2(50) := ' !@#$%^&*()-=+\|`~{[]};:",<.>/?'||CHR(9)||CHR(10)||CHR(13);
   
BEGIN 
   FOR i IN 1 .. LENGTH(p_query) LOOP 
      l_char := substr(p_query,i,1); 
      
      IF ( l_char = '''' AND l_in_quotes ) THEN 
         l_in_quotes := FALSE; 
      
      ELSIF ( l_char = '''' AND NOT l_in_quotes ) THEN 
         l_in_quotes := TRUE; 
      END IF;
      
      
      IF ( NOT l_in_quotes AND l_char = ':' ) THEN
         l_in_bind := TRUE;
      
      ELSIF ( NOT l_in_quotes
              AND l_in_bind 
              AND (INSTR(l_delimeters,l_char) > 0)
      ) THEN
         l_in_bind := FALSE;
         l_bind_cnt := l_bind_cnt + 1;
         -- strip out last carrige return
         l_bind_array(l_bind_cnt) := l_bind_name;
         l_bind_name := NULL;
      END IF;
      
      
      IF ( l_in_bind ) THEN 
         l_bind_name := l_bind_name || l_char;
      END IF; 
      
   END LOOP;
   
   IF ( l_in_bind ) THEN
      l_bind_cnt := l_bind_cnt + 1;
      -- strip out last carriage return
      l_bind_array(l_bind_cnt) := l_bind_name;
   END IF;
   
   p_bind_cnt := l_bind_cnt;
   p_bind_array := l_bind_array;

END parse_binds; 


PROCEDURE prompt_bind(
   p_bind_name IN VARCHAR2
,  FIRST       IN BOOLEAN)
IS
   CURSOR param_cur IS
      SELECT
         rsp_name
      ,  rsp_type
      ,  rsp_list_sql
      FROM report_shr_prms
      WHERE rsp_code = UPPER(SUBSTR(p_bind_name,2));
   param param_cur%ROWTYPE;
   
   list_cur INTEGER;
   LIST_TYPE CONSTANT VARCHAR2(1) := 'L';
   CONST_TYPE CONSTANT VARCHAR2(1) := 'C';

BEGIN
   IF FIRST THEN
      htp.p('<tr>');
      htp.p('<td colspan=2><font class="TRT"><b><font class="TRT">Please supply the following parameter(s):</b></font></td>');
      htp.p('</tr>');
   END IF;

   OPEN param_cur;
   FETCH param_cur INTO param;
   CLOSE param_cur;

   htp.p('<tr>');
   htp.p('<td><font class="TRT">'||NVL(param.rsp_name,p_bind_name)||'</font></td>');
   htp.p('<td>');
   htp.p('<input type="hidden" name="p_bind_names" value="'||p_bind_name||'">');
   
   IF param.rsp_list_sql IS NOT NULL AND
      param.rsp_type = LIST_TYPE AND
      INSTR(trim_all(UPPER(param.rsp_list_sql)),'SELECT') = 1
   THEN

      -- I am no longer parsing LOV cursor
      -- using owa_util.bind_variables since
      -- it uses dbms_sys_sql.parse_as_user
      -- which causes problems when running
      -- this as WEBPROC_ROLE users (they don't
      -- have SELECT privs on LOV tables)
      --
      -- because of that I now ensure that
      -- LOV cursor is actually a SELECT stmnt (see above)
      -- owa_util.bind_variables used to take care
      -- of that for me ...
      --
      --list_cur := owa_util.bind_variables(param.rsp_list_sql); 
      
      list_cur := dbms_sql.open_cursor;
      dbms_sql.parse(list_cur, param.rsp_list_sql, dbms_sql.native);
      owa_util.listprint(list_cur, 'p_bind_values', null, null); 
      dbms_sql.close_cursor(list_cur); 
   
   ELSE
      htp.p('<input type=text name=p_bind_values size=15 maxlength=255 value="">');
   END IF;

   htp.p('</td>');
   htp.p('</tr>');
   
END prompt_bind;


-- GLOBAL MODULES
--

PROCEDURE exec_sql(
   p_report      IN VARCHAR2   DEFAULT NULL
,  p_cursor      IN INTEGER    DEFAULT NULL
,  p_bind_names  IN char_array DEFAULT empty_array
,  p_bind_values IN char_array DEFAULT empty_array
,  p_pag         IN VARCHAR2   DEFAULT NULL
,  p_pag_str     IN NUMBER     DEFAULT 1
,  p_pag_int     IN NUMBER     DEFAULT 19
,  p_heading     IN VARCHAR2   DEFAULT 'Query Results'
,  p_rep_what    IN VARCHAR2   DEFAULT NULL
,  p_rep_with    IN VARCHAR2   DEFAULT NULL)
IS
   CURSOR rep_sql_cur IS
      SELECT REPLACE(r_sql,p_rep_what,p_rep_with) r_sql
      FROM reports
      WHERE r_code = p_report;
   
   l_sql   LONG;
   l_cur   INTEGER; 
   l_rec   NUMBER; 

   l_cols  INTEGER; 
   l_cols_desc dbms_sql.desc_tab;
   l_cols_pos  NUMBER;
   
   l_curr_col_val VARCHAR2(4000);
   
   l_curr_bind VARCHAR2(255);
   l_bind_array char_array;
   l_bind_cnt INTEGER;
   
   ret_chr VARCHAR2(5) DEFAULT chr(10);
   
   ERRPOS INTEGER;
   
   SELECT_STMNT BOOLEAN DEFAULT FALSE;
   
   BIND_READY BOOLEAN DEFAULT TRUE;
   
   invalid_report EXCEPTION;
   invalid_select EXCEPTION;
   invalid_pcursor EXCEPTION;
   
BEGIN
   web_std_pkg.print_styles;
   
   EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_DATE_FORMAT=''RRRR-MON-DD HH24:MI:SS''';
   
   IF p_report IS NOT NULL THEN
      OPEN rep_sql_cur;
      FETCH rep_sql_cur INTO l_sql;
      
      IF rep_sql_cur%FOUND THEN
         CLOSE rep_sql_cur;
         
         -- check stmnt type
         --
         IF INSTR(trim_all(UPPER(l_sql)),'SELECT') != 1 THEN
            RAISE invalid_select;
         
         ELSE
            SELECT_STMNT := TRUE;
            
            -- check for paginate
            IF ( p_pag IS NOT NULL )
            THEN
               
               l_sql := 'select * '||ret_chr||
                        '   from ( select rownum r, a.* '||ret_chr||
                        '          from ( '||l_sql||' ) a '||ret_chr||
                        '          where rownum <= :END_ROW) '||ret_chr||
                        'where r >= :START_ROW';
            END IF;
         END IF;
      
      ELSE
         CLOSE rep_sql_cur;
         RAISE invalid_report;
      END IF;
      
      -- if I got here I should have
      -- ready SQL to open/parse
   
      l_cur := dbms_sql.open_cursor;
      
      dbms_sql.parse(
         l_cur
      ,  l_sql
      ,  dbms_sql.native);
   
   ELSIF p_cursor IS NOT NULL THEN
      l_cur := p_cursor;
   
   ELSE
      RAISE invalid_pcursor;
   END IF;
   
   
   -- PARSE BINDS
   IF SELECT_STMNT THEN
      
      parse_binds(
          l_sql
      ,   l_bind_cnt
      ,   l_bind_array);
      
      IF l_bind_cnt > 0 THEN
         --htp.p('detected '||l_bind_cnt||' variable(s)<br>');
         htp.p('<form method="POST" action="glob_web_pkg.exec_sql">');
         htp.p('<table cellpadding="0" cellspacing="2" border="0">');
      
         FOR i IN 1 .. l_bind_cnt LOOP
            
            BEGIN
               l_curr_bind := p_bind_names(i);
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  l_curr_bind := NULL;
            END;
            
            IF ( l_curr_bind = l_bind_array(i) AND
                 l_curr_bind NOT IN (':START_ROW',':END_ROW') AND
                 p_bind_values(i) IS NOT NULL )
            THEN
      
               dbms_sql.bind_variable(l_cur, l_curr_bind, p_bind_values(i));
               htp.p('<input type="hidden" name="p_bind_names" value="'||htf.escape_sc(l_curr_bind)||'">');
               htp.p('<input type="hidden" name="p_bind_values" value="'||htf.escape_sc(p_bind_values(i))||'">');
      
            /* code below fires when the above IF fails
             * to stuff START/END row boudaries for
             * paginate fuctionality.  This ensures
             * that we use bind variables for paginate
             */
            ELSIF ( l_bind_array(i) = ':START_ROW' )
            THEN
               -- process paginate START
               dbms_sql.bind_variable(l_cur, l_bind_array(i), p_pag_str);
               htp.p('<input type="hidden" name="p_bind_names" value="'||htf.escape_sc(l_bind_array(i))||'">');
               htp.p('<input type="hidden" name="p_bind_values" value="'||htf.escape_sc(TO_CHAR(p_pag_str))||'">');
      
            ELSIF ( l_bind_array(i) = ':END_ROW' )
            THEN
               -- process paginate END
               dbms_sql.bind_variable(l_cur, l_bind_array(i), p_pag_str + p_pag_int);
               htp.p('<input type="hidden" name="p_bind_names" value="'||htf.escape_sc(l_bind_array(i))||'">');
               htp.p('<input type="hidden" name="p_bind_values" value="'||htf.escape_sc(TO_CHAR(p_pag_str + p_pag_int))||'">');
            /* end paginate */
      
            ELSE
               prompt_bind(l_bind_array(i),i=1);
               BIND_READY := FALSE;
            END IF;
         END LOOP;
      
         IF NOT BIND_READY THEN
            -- CONTROLS
            htp.p('<tr>');
            htp.p('<td>');
            htp.p('<input type="SUBMIT" value="Run query">');
            htp.p('</td>');
            htp.p('</tr>');
         
            -- HIDDEN
            htp.p('<input type="hidden" name="p_report" value="'||htf.escape_sc(p_report)||'">');
            htp.p('<input type="hidden" name="p_pag" value="'||htf.escape_sc(p_pag)||'">');
            htp.p('<input type="hidden" name="p_pag_str" value="'||htf.escape_sc(p_pag_str)||'">');
            htp.p('<input type="hidden" name="p_pag_int" value="'||htf.escape_sc(p_pag_int)||'">');
            htp.p('<input type="hidden" name="p_heading" value="'||htf.escape_sc(p_heading)||'">');
            htp.p('<input type="hidden" name="p_rep_what" value="'||htf.escape_sc(p_rep_what)||'">');
            htp.p('<input type="hidden" name="p_rep_with" value="'||htf.escape_sc(p_rep_with)||'">');
         END IF;   
         
         htp.p('</form>');
         htp.p('</table>');
      END IF;
   
   -- END SELECT_STMNT
   END IF;

   
   
   IF BIND_READY THEN

      -- DESCRIBE COLUMNS
      --
      dbms_sql.describe_columns(
         l_cur
      ,  l_cols
      ,  l_cols_desc);
      
      
      -- DEFINE COLUMNS
      --
      l_cols_pos := l_cols_desc.first;
      WHILE l_cols_pos <= l_cols_desc.last LOOP
         dbms_sql.define_column(l_cur, l_cols_pos, l_curr_col_val,4000);
         l_cols_pos := l_cols_desc.next(l_cols_pos);  
      END LOOP;
      
      l_rec := dbms_sql.execute(l_cur);
      
      
      IF p_heading != 'NONE' THEN
         htp.p('<h2>'||p_heading||'</h2>');
      END IF;
      
      -- OPEN HTML TABLE
      --
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      
      -- BUILD HEADER
      --
      l_cols_pos := l_cols_desc.first;
      WHILE l_cols_pos <= l_cols_desc.last LOOP 
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">'||l_cols_desc(l_cols_pos).col_name||'</font></TH>'); 
         l_cols_pos := l_cols_desc.next(l_cols_pos);  
      END LOOP; 
      
      
      -- DISPLAY THE DATA
      --
      LOOP
         IF dbms_sql.fetch_rows(l_cur)>0 THEN
      
            htp.p('<TR>');
            
            l_cols_pos := l_cols_desc.first;
            WHILE l_cols_pos <= l_cols_desc.last LOOP 
               -- get column values of the row
               dbms_sql.column_value(l_cur, l_cols_pos, l_curr_col_val);
               htp.p('<TD nowrap><font class="TRT">'||l_curr_col_val||'</font></TD>');
               l_cols_pos := l_cols_desc.next(l_cols_pos);  
            END LOOP; 
      
            htp.p('</TR>');
      
         ELSE
            -- NO MORE ROW TO COPY
            EXIT;
         END IF;
      END LOOP;   
      
      htp.p('</TABLE>');
      
      -- GET THE NUMBER OF ROWS
      --
      l_rec := dbms_sql.last_row_count;
      IF l_rec > 1 THEN
         htp.p(l_rec||' rows selected.');
      END IF;
      
      
      -- if paginate enabled and SELECT_STMNT and number
      -- of rows selected was >= paginate interval
      -- THEN
      -- spit out bind names/values and give NEXT button
      --
      IF ( p_pag IS NOT NULL AND (l_rec >= p_pag_int) AND SELECT_STMNT )
      THEN
         
         htp.p('<form method="POST" action="glob_web_pkg.exec_sql">');
         htp.p('<table cellpadding="0" cellspacing="2" border="0">');

         
         -- only loop thru p_bind_names/p_bind_values
         -- if l_bind_cnt > 2 since it can be 2 only when there
         -- are no other bind variables but :START_ROW/:END_ROW pair
         --
         IF l_bind_cnt > 2 THEN
            FOR i IN 1 .. l_bind_cnt
            LOOP
               htp.p('<input type="hidden" name="p_bind_names" value="'||htf.escape_sc(p_bind_names(i))||'">');
               htp.p('<input type="hidden" name="p_bind_values" value="'||htf.escape_sc(p_bind_values(i))||'">');
            END LOOP;
         END IF;
         
         
         -- CONTROLS
         htp.p('<tr>');
         htp.p('<td>');
         htp.p('<input type="SUBMIT" value="Next">');
         htp.p('</td>');
         htp.p('</tr>');

         -- HIDDEN
         htp.p('<input type="hidden" name="p_report" value="'||htf.escape_sc(p_report)||'">');
         htp.p('<input type="hidden" name="p_pag" value="'||htf.escape_sc(p_pag)||'">');
         -- start next paginate with (last start + insterval + 1)
         -- to avoid repeating last row
         htp.p('<input type="hidden" name="p_pag_str" value="'||htf.escape_sc(TO_CHAR(p_pag_str+p_pag_int+1))||'">');
         htp.p('<input type="hidden" name="p_pag_int" value="'||htf.escape_sc(p_pag_int)||'">');
         htp.p('<input type="hidden" name="p_heading" value="'||htf.escape_sc(p_heading)||'">');
         htp.p('<input type="hidden" name="p_rep_what" value="'||htf.escape_sc(p_rep_what)||'">');
         htp.p('<input type="hidden" name="p_rep_with" value="'||htf.escape_sc(p_rep_with)||'">');

         htp.p('</form>');
         htp.p('</table>');
         
      -- END PAGINATE
      END IF;
         
   -- END BIND_READY
   END IF;
   
   -- only close cursor if I opened it
   -- just like owa_util does it ...
   IF SELECT_STMNT THEN
      dbms_sql.close_cursor(l_cur);
   END IF;
   
   
EXCEPTION
   WHEN invalid_report  THEN
      RAISE_APPLICATION_ERROR(-20001,'Invalid Report Code='||p_report);
      
   WHEN invalid_select  THEN
      RAISE_APPLICATION_ERROR(-20002,'Invalid Select Statement='||l_sql);
      
   WHEN invalid_pcursor THEN
      RAISE_APPLICATION_ERROR(-20003,'Invalid Cursor='||p_cursor);
   
   WHEN OTHERS THEN
      IF SELECT_STMNT THEN
         ERRPOS := dbms_sql.last_error_position;
         
         IF dbms_sql.is_open(l_cur) THEN
            dbms_sql.close_cursor(l_cur);
         END IF;
         
         htp.p('ERROR OCCURED EXECUTING SQL: '||SQLERRM);
         htp.p('<PRE>'||highlight(ERRPOS,l_sql)||'</PRE>');
      ELSE
         IF dbms_sql.is_open(l_cur) THEN
            dbms_sql.close_cursor(l_cur);
         END IF;
         htp.p('ERROR OCCURED EXECUTING SQL: '||SQLERRM);
      END IF;
      
END exec_sql;


PROCEDURE page_lists(
   p_pl_id             IN VARCHAR2 DEFAULT NULL
,  p_pld_id            IN VARCHAR2 DEFAULT NULL
,  p_ae_id             IN VARCHAR2 DEFAULT NULL
,  p_a_id              IN VARCHAR2 DEFAULT NULL
,  p_a_name            IN VARCHAR2 DEFAULT NULL
,  p_a_desc            IN VARCHAR2 DEFAULT NULL
,  p_ae_email          IN VARCHAR2 DEFAULT NULL
,  p_ae_desc           IN VARCHAR2 DEFAULT NULL
,  p_ae_append_logfile IN VARCHAR2 DEFAULT NULL
,  p_date_modified     IN VARCHAR2 DEFAULT NULL
,  p_modified_by       IN VARCHAR2 DEFAULT NULL
,  p_pl_code           IN VARCHAR2 DEFAULT NULL
,  p_pl_desc           IN VARCHAR2 DEFAULT NULL
,  p_pl_ack_required   IN VARCHAR2 DEFAULT NULL
-- ADMIN BACKUPS
,  p_ab_id             IN VARCHAR2 DEFAULT NULL
,  p_pa_id             IN VARCHAR2 DEFAULT NULL
,  p_ba_id             IN VARCHAR2 DEFAULT NULL
,  p_bae_id            IN VARCHAR2 DEFAULT NULL
,  p_operation         IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR admins_cur IS
      SELECT a_name
      ,      a_id
      FROM admins
      ORDER BY a_name;
      
   CURSOR admin_backup_cur(
      p_pa_id IN NUMBER,
      p_ba_id IN NUMBER,
      b_bae_id IN NUMBER) IS
      SELECT 
         ab_id
      ,  primary_a_id
      ,  backup_a_id
      ,  backup_ae_id
      ,  TO_CHAR(date_modified,'RRRR-MON-DD HH24:MI:SS') date_modified
      FROM admin_backups
      WHERE primary_a_id = p_pa_id
      AND   backup_a_id = p_ba_id
      AND   backup_ae_id = b_bae_id;
   admin_backup admin_backup_cur%ROWTYPE;

   CURSOR lists_cur IS
      SELECT
         pl_id
      ,  pl_code
      ,  pl_ack_required
      ,  DECODE(pl_ack_required,'Y','N','N','Y') ack_reversed
      ,  DECODE(pl_ack_required,'Y','ack','N','no ack') ack_decoded
      ,  TO_CHAR(date_modified,'RRRR-MON-DD HH24:MI:SS') date_modified
      FROM page_lists
      ORDER BY pl_code;

   CURSOR emails_cur IS
      SELECT
         ae_id
      ,  ae.a_id
      ,  a_name||'('||ae_email||')' email
      ,  ae_desc
      FROM admin_emails ae
      ,    admins a
      WHERE ae.a_id = a.a_id
      ORDER by ae.a_id, ae_desc;

   CURSOR assigned_cur(p_pl_id IN NUMBER,
                  p_ae_id IN NUMBER,
                  p_a_id IN NUMBER) IS
      SELECT pld_id
      ,      pld_status
      ,      TO_CHAR(date_modified,'DD-MON-RRRR HH24:MI:SS') date_modified
      FROM page_list_definitions
      WHERE pl_id = p_pl_id
      AND   ae_id = p_ae_id
      AND   a_id = p_a_id;
   assigned assigned_cur%ROWTYPE;

   -- SWITCHES
   PRINT_REPORT_BANNER BOOLEAN DEFAULT FALSE;
   PRINT_LIST_REPORT BOOLEAN DEFAULT FALSE;
   PRINT_BACK_REPORT BOOLEAN DEFAULT FALSE;
      
   PRINT_INS_ADMIN     BOOLEAN DEFAULT FALSE;
   PRINT_INS_EMAIL     BOOLEAN DEFAULT FALSE;
   PRINT_INS_PLIST     BOOLEAN DEFAULT FALSE;

   PRINT_FOOTER        BOOLEAN DEFAULT TRUE;

   EMAIL_ASSIGNED      BOOLEAN DEFAULT FALSE;
   BACKUP_ASSIGNED     BOOLEAN DEFAULT FALSE;
   
   l_col_cnt INTEGER;

BEGIN
   IF p_operation = 'DEACTIVATE' THEN

      glob_api_pkg.pld(
         p_pld_id        => p_pld_id
      ,  p_date_modified => TO_DATE(p_date_modified,'DD-MON-RRRR HH24:MI:SS')
      ,  p_modified_by   => USER
      ,  p_created_by    => NULL
      ,  p_pl_id         => NULL
      ,  p_a_id          => NULL
      ,  p_ae_id         => NULL
      ,  p_pld_status    => 'I'
      ,  p_operation     => 'U');

   ELSIF p_operation = 'ACTIVATE' THEN

      glob_api_pkg.pld(
         p_pld_id        => p_pld_id
      ,  p_date_modified => TO_DATE(p_date_modified,'DD-MON-RRRR HH24:MI:SS')
      ,  p_modified_by   => USER
      ,  p_created_by    => NULL
      ,  p_pl_id         => NULL
      ,  p_a_id          => NULL
      ,  p_ae_id         => NULL
      ,  p_pld_status    => 'A'
      ,  p_operation     => 'U');

   ELSIF p_operation = 'I' THEN

      glob_api_pkg.pld(
         p_pld_id        => NULL
      ,  p_date_modified => NULL
      ,  p_modified_by   => NULL
      ,  p_created_by    => USER
      ,  p_pl_id         => p_pl_id
      ,  p_a_id          => p_a_id
      ,  p_ae_id         => p_ae_id
      ,  p_pld_status    => 'A'
      ,  p_operation     => 'I');

   ELSIF p_operation = 'I-ADMIN' THEN

      glob_api_pkg.a(
         p_a_id           => NULL
      ,  p_date_modified  => NULL
      ,  p_modified_by    => NULL
      ,  p_created_by     => USER
      ,  p_a_name         => p_a_name
      ,  p_a_desc         => p_a_desc
      ,  p_operation      => 'I');

   ELSIF p_operation = 'I-EMAIL' THEN

      glob_api_pkg.ae(
         p_ae_id             => NULL
      ,  p_date_modified     => NULL
      ,  p_modified_by       => NULL
      ,  p_created_by        => USER
      ,  p_a_id              => p_a_id
      ,  p_ae_email          => p_ae_email
      ,  p_ae_append_logfile => p_ae_append_logfile
      ,  p_ae_desc           => p_ae_desc
      ,  p_operation         => 'I');

   ELSIF p_operation = 'I-PLIST' THEN
      
      glob_api_pkg.pl(
         p_pl_id           => NULL
      ,  p_date_modified   => NULL
      ,  p_modified_by     => NULL
      ,  p_created_by      => USER
      ,  p_pl_code         => p_pl_code
      ,  p_pl_desc         => p_pl_desc
      ,  p_pl_ack_required => p_pl_ack_required
      ,  p_operation       => 'I');

   ELSIF p_operation = 'PL_ACK_UPD' THEN
      glob_api_pkg.pl(
         p_pl_id           => p_pl_id
      ,  p_date_modified   => TO_DATE(p_date_modified,'RRRR-MON-DD HH24:MI:SS')
      ,  p_modified_by     => USER
      ,  p_created_by      => NULL
      ,  p_pl_code         => NULL
      ,  p_pl_desc         => NULL
      ,  p_pl_ack_required => p_pl_ack_required
      ,  p_operation       => 'U-ACK');
      
   ELSIF p_operation = 'BACK_DEL' THEN
      glob_api_pkg.ab(
         p_ab_id          => p_ab_id
      ,  p_date_modified  => NULL
      ,  p_modified_by    => NULL
      ,  p_created_by     => NULL
      ,  p_primary_a_id   => NULL
      ,  p_backup_a_id    => NULL
      ,  p_backup_ae_id   => NULL
      ,  p_operation      => 'D');

   ELSIF p_operation = 'BACK_INS' THEN
      glob_api_pkg.ab(
         p_ab_id          => NULL
      ,  p_date_modified  => NULL
      ,  p_modified_by    => NULL
      ,  p_created_by     => USER
      ,  p_primary_a_id   => p_pa_id
      ,  p_backup_a_id    => p_ba_id
      ,  p_backup_ae_id   => p_bae_id
      ,  p_operation      => 'I');
      
   END IF;


   PRINT_REPORT_BANNER := TRUE;
   PRINT_LIST_REPORT := TRUE;
   PRINT_BACK_REPORT := TRUE;
   PRINT_INS_ADMIN := TRUE;
   PRINT_INS_EMAIL := TRUE;
   PRINT_INS_PLIST := TRUE;


   IF PRINT_REPORT_BANNER THEN
      web_std_pkg.header('Monitoring System - Page Lists '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'GLOB');
   END IF;
   
   
   IF PRINT_LIST_REPORT THEN
      
      SELECT COUNT(pl_id)+2 cnt
      INTO l_col_cnt
      FROM page_lists;
      
      
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      htp.p('<TR>');
      htp.p('<TH ALIGN="center" VALIGN="Bottom" colspan="'||l_col_cnt||'" BGCOLOR="'||d_THC||'"><font class="THT">Page List Assignments</font></TH>');
      htp.p('</TR>');
      htp.p('<TH ALIGN="Left" VALIGN="Bottom" BGCOLOR="'||d_THC||'"><font class="THT">Email</font></TH>');
      htp.p('<TH ALIGN="Left" VALIGN="Bottom" BGCOLOR="'||d_THC||'"><font class="THT">Name</font></TH>');

      -- BUILD TABLE HEADER
      --
      FOR lists IN lists_cur LOOP
         htp.p('<TD ALIGN="Left" BGCOLOR="'||d_TRC||'"><a href="glob_web_pkg.page_lists?p_pl_id='||lists.pl_id||
                                                          '&p_pl_ack_required='||lists.ack_reversed||
                                                          web_std_pkg.encode_url('&p_date_modified='||lists.date_modified)||
                                                          '&p_operation=PL_ACK_UPD"><font class="TRL">'||lists.pl_code||'</br>('||lists.ack_decoded||')</font></a></TD>');
      END LOOP;
      
      
      -- BUILD TABLE ROWS
      FOR emails IN emails_cur LOOP
      
         htp.p('<TR BGCOLOR="'||d_TRC||'">');
         htp.p('<TD nowrap><font class="TRT">'||emails.email||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||emails.ae_desc||'</font></TD>');
      
         FOR lists IN lists_cur LOOP
            OPEN assigned_cur(lists.pl_id,
                              emails.ae_id,
                              emails.a_id);
            FETCH assigned_cur INTO assigned;
            IF assigned_cur%FOUND THEN
               CLOSE assigned_cur;
               EMAIL_ASSIGNED := TRUE;
            ELSE
               CLOSE assigned_cur;
               EMAIL_ASSIGNED := FALSE;
            END IF;
      
      
            IF EMAIL_ASSIGNED AND
               assigned.pld_status = 'A' THEN
      
               htp.p('<TD BGCOLOR="'||d_LRC_A||'" nowrap><a href="glob_web_pkg.page_lists?p_pld_id='||assigned.pld_id||
                                                          web_std_pkg.encode_url('&p_date_modified='||assigned.date_modified)||
                                                          '&p_operation=DEACTIVATE"><font class="TRL">D</font></a></TD>');
            ELSIF EMAIL_ASSIGNED AND
                  assigned.pld_status = 'I' THEN
      
               htp.p('<TD BGCOLOR="'||d_LRC_I||'" nowrap><a href="glob_web_pkg.page_lists?p_pld_id='||assigned.pld_id||
                                                          web_std_pkg.encode_url('&p_date_modified='||assigned.date_modified)||
                                                          '&p_operation=ACTIVATE"><font class="TRL">A</font></a></TD>');
      
            ELSE
               htp.p('<TD BGCOLOR="'||d_LRC_I||'" nowrap><a href="glob_web_pkg.page_lists?p_pl_id='||lists.pl_id||
                                                          '&p_ae_id='||emails.ae_id||
                                                          '&p_a_id='||emails.a_id||
                                                          '&p_operation=I"><font class="TRL">A</font></a></TD>');
            END IF;
         END LOOP;
      
      htp.p('</TR>');
      END LOOP;


      -- TABLE FOOTER
      htp.p('<TR BGCOLOR="'||d_PHCS||'">');
      htp.p('<TD nowrap colspan="'||l_col_cnt||'">');
      htp.p('<font class="TRT">A=activate paging</font></br>');
      htp.p('<font class="TRT">D=deactivate paging</font></br>');
      htp.p('<font class="TRT">(no ack)=acknowledgment is not required [click to activate]</font></br>');
      htp.p('<font class="TRT">(ack)=acknowledgment is required [click to deactivate]</font>');
      htp.p('</TD>');
      htp.p('</TR>');
      htp.p('</TABLE>');

      
   -- PRINT_LIST_REPORT
   END IF;


   IF PRINT_BACK_REPORT THEN
   	
      htp.p('</BR>');

      SELECT COUNT(a_id)+2 cnt
      INTO l_col_cnt
      FROM admins;

      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      htp.p('<TR>');
      htp.p('<TH ALIGN="center" VALIGN="Bottom" colspan="'||l_col_cnt||'" BGCOLOR="'||d_THC||'"><font class="THT">Admin Backup Assignments</font></TH>');
      htp.p('</TR>');
      htp.p('<TH ALIGN="Left" VALIGN="Bottom" BGCOLOR="'||d_THC||'"><font class="THT">Email</font></TH>');
      htp.p('<TH ALIGN="Left" VALIGN="Bottom" BGCOLOR="'||d_THC||'"><font class="THT">Name</font></TH>');

      -- BUILD TABLE HEADER
      --
      FOR admins IN admins_cur LOOP
         htp.p('<TD ALIGN="Left" BGCOLOR="'||d_TRC||'"><font class="TRT">'||admins.a_name||'</font></TD>');
      END LOOP;
      
      
      -- BUILD TABLE ROWS
      FOR emails IN emails_cur LOOP
      
         htp.p('<TR BGCOLOR="'||d_TRC||'">');
         htp.p('<TD nowrap><font class="TRT">'||emails.email||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||emails.ae_desc||'</font></TD>');
      
         FOR admins IN admins_cur LOOP
            OPEN admin_backup_cur(admins.a_id,
                              emails.a_id,
                              emails.ae_id);
            FETCH admin_backup_cur INTO admin_backup;
            IF admin_backup_cur%FOUND THEN
               CLOSE admin_backup_cur;
               BACKUP_ASSIGNED := TRUE;
            ELSE
               CLOSE admin_backup_cur;
               BACKUP_ASSIGNED := FALSE;
            END IF;
      
      
            IF BACKUP_ASSIGNED THEN
               htp.p('<TD BGCOLOR="'||d_LRC_A||'" nowrap><a href="glob_web_pkg.page_lists?p_ab_id='||admin_backup.ab_id||
                                                          '&p_operation=BACK_DEL"><font class="TRL">D</font></a></TD>');
            ELSE
               htp.p('<TD BGCOLOR="'||d_LRC_I||'" nowrap><a href="glob_web_pkg.page_lists?p_pa_id='||admins.a_id||
                                                          '&p_ba_id='||emails.a_id||
                                                          '&p_bae_id='||emails.ae_id||
                                                          '&p_operation=BACK_INS"><font class="TRL">A</font></a></TD>');
            END IF;
         END LOOP;
      
      htp.p('</TR>');
      END LOOP;

     
      -- TABLE FOOTER
      htp.p('<TR BGCOLOR="'||d_PHCS||'">');
      htp.p('<TD nowrap colspan="'||l_col_cnt||'">');
      htp.p('<font class="TRT">A=activate backup paging</font></br>');
      htp.p('<font class="TRT">D=deactivate backup paging</font>');
      htp.p('</TD>');
      htp.p('</TR>');
      htp.p('</TABLE>');
      
      
   -- PRINT_BACK_REPORT
   END IF;



   -- INSERT FORMS
   --
   htp.p('</BR>');
   
   htp.p('<table cellpadding="0" cellspacing="2" border="0">');
   
   IF PRINT_INS_PLIST THEN
      htp.p('<form method="POST" action="glob_web_pkg.page_lists">');

      -- SEPARATOR
      htp.p('<tr>');
      htp.p('<td colspan="2"><HR></td>');
      htp.p('</tr>');
   	
      -- PL_CODE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Page List Name: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_pl_code size=20 maxlength=50 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- PL_ACK_REQUIRED
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Acknowledgment: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_pl_ack_required">');

      htp.p('<option value="N" >NOT REQUIRED</option>');
      htp.p('<option value="Y" >REQUIRED</option>');

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');

      -- PL_DESC
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Description: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_pl_desc size=50 maxlength=512 value="">');
      htp.p('</td>');
      htp.p('</tr>');


      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Create">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="I-PLIST">');
      htp.p('</form>');
   END IF;


   IF PRINT_INS_ADMIN THEN
      htp.p('<form method="POST" action="glob_web_pkg.page_lists">');

      -- SEPARATOR
      htp.p('<tr>');
      htp.p('<td colspan="2"><HR></td>');
      htp.p('</tr>');

      -- A_NAME
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Admin Name: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_a_name size=20 maxlength=50 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- A_DESC
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Description: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_a_desc size=50 maxlength=512 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Create">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="I-ADMIN">');
      htp.p('</form>');
   END IF;


   IF PRINT_INS_EMAIL THEN
      htp.p('<form method="POST" action="glob_web_pkg.page_lists">');

      -- SEPARATOR
      htp.p('<tr>');
      htp.p('<td colspan="2"><HR></td>');
      htp.p('</tr>');

      -- A_ID
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Admin: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_a_id">');

      htp.p('<option value="" >------</option>');
      FOR admins IN admins_cur LOOP
         htp.p('<option value="'||admins.a_id||'" >'||admins.a_name||'</option>');
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');

      -- AE_EMAIL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Email/Pager: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ae_email size=20 maxlength=256 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- AE_DESC
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Email/Pager Code: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_ae_desc size=20 maxlength=50 value="">');
      htp.p('</td>');
      htp.p('</tr>');

      -- AE_APPEND_LOGFILE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Append Log: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_ae_append_logfile">');

      htp.p('<option value="Y" >YES</option>');
      htp.p('<option value="N" >NO</option>');

      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Create">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="I-EMAIL">');
      htp.p('</form>');
   END IF;

   -- END FORMS
   htp.p('</table>');
   

   IF PRINT_FOOTER THEN
      web_std_pkg.footer;
   END IF;
END page_lists;

PROCEDURE blackouts(
   p_eb_id          IN VARCHAR2 DEFAULT NULL
,  p_date_created   IN VARCHAR2 DEFAULT NULL
,  p_date_modified  IN VARCHAR2 DEFAULT NULL
,  p_modified_by    IN VARCHAR2 DEFAULT NULL
,  p_created_by     IN VARCHAR2 DEFAULT NULL
,  p_eb_code        IN VARCHAR2 DEFAULT NULL
,  p_eb_type        IN VARCHAR2 DEFAULT NULL
,  p_eb_type_id     IN VARCHAR2 DEFAULT NULL
--
-- START LOCAL
,  p_loc_sd         IN VARCHAR2 DEFAULT NULL
,  p_loc_ed         IN VARCHAR2 DEFAULT NULL
,  p_loc_shh        IN VARCHAR2 DEFAULT NULL
,  p_loc_ehh        IN VARCHAR2 DEFAULT NULL
,  p_loc_smi        IN VARCHAR2 DEFAULT NULL
,  p_loc_emi        IN VARCHAR2 DEFAULT NULL
-- END LOCAL
--
,  p_eb_start_date  IN VARCHAR2 DEFAULT NULL
,  p_eb_end_date    IN VARCHAR2 DEFAULT NULL
,  p_eb_week_day    IN VARCHAR2 DEFAULT NULL
,  p_eb_active_flag IN VARCHAR2 DEFAULT NULL
,  p_eb_desc        IN VARCHAR2 DEFAULT NULL
,  p_operation      IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR blc_cur IS
      SELECT
         eb_id
      ,  date_created
      ,  TO_CHAR(date_modified,'DD-MON-RRRR HH24:MI:SS') date_modified
      ,  DECODE(TO_CHAR(eb_start_date,'DD/MM/RRRR'),'01/01/0001',NULL,TO_CHAR(eb_start_date,'DD/MM/RRRR')) loc_sd
      ,  TO_CHAR(eb_start_date,'HH24')       loc_shh
      ,  TO_CHAR(eb_start_date,'MI')         loc_smi
      ,  DECODE(TO_CHAR(eb_end_date,'DD/MM/RRRR'),'01/01/9000',NULL,TO_CHAR(eb_end_date,'DD/MM/RRRR')) loc_ed
      ,  TO_CHAR(eb_end_date,'HH24')       loc_ehh
      ,  TO_CHAR(eb_end_date,'MI')         loc_emi
      ,  modified_by
      ,  created_by
      ,  start_date
      ,  end_date
      ,  start_time
      ,  end_time
      ,  day
      ,  eb_code
      ,  eb_type_long
      ,  eb_type
      ,  eb_type_id
      ,  eb_type_name
      ,  eb_start_date
      ,  eb_end_date
      ,  eb_week_day
      ,  eb_active_flag
      ,  eb_desc
      FROM event_blackouts_v
      ORDER BY
         eb_type
      ,  eb_type_name
      ,  DECODE(eb_week_day,1,100,eb_week_day)
      ,  start_time
      ,  end_time;

   CURSOR blc_one_cur IS
      SELECT
         eb_id
      ,  date_created
      ,  TO_CHAR(date_modified,'DD-MON-RRRR HH24:MI:SS') date_modified
      ,  DECODE(TO_CHAR(eb_start_date,'DD/MM/RRRR'),'01/01/0001',NULL,TO_CHAR(eb_start_date,'DD/MM/RRRR')) loc_sd
      ,  TO_CHAR(eb_start_date,'HH24')       loc_shh
      ,  TO_CHAR(eb_start_date,'MI')         loc_smi
      ,  DECODE(TO_CHAR(eb_end_date,'DD/MM/RRRR'),'01/01/9000',NULL,TO_CHAR(eb_end_date,'DD/MM/RRRR')) loc_ed
      ,  TO_CHAR(eb_end_date,'HH24')       loc_ehh
      ,  TO_CHAR(eb_end_date,'MI')         loc_emi
      ,  modified_by
      ,  created_by
      ,  eb_code
      ,  eb_type_long
      ,  eb_type
      ,  eb_type_id
      ,  eb_type_name
      ,  eb_start_date
      ,  eb_end_date
      ,  eb_week_day
      ,  eb_active_flag
      ,  eb_desc
      FROM event_blackouts_v
      WHERE eb_id = p_eb_id;
   blc_one blc_one_cur%ROWTYPE;

   CURSOR week_day_cur IS
      SELECT rv_meaning meaning
      ,      rv_low_value value
      FROM   cg_ref_codes
      WHERE  rv_domain = 'EVENT_BLACKOUTS.EB_WEEK_DAY'
      ORDER BY rv_low_value;

   CURSOR blackout_type_all_cur IS
      SELECT rv_meaning meaning
      ,      rv_low_value value
      FROM   cg_ref_codes
      WHERE  rv_domain = 'EVENT_BLACKOUTS.EB_TYPE'
      ORDER BY 1;

   CURSOR blackout_type_cur IS
      SELECT rv_meaning meaning
      ,      rv_low_value value
      FROM   cg_ref_codes
      WHERE  rv_domain = 'EVENT_BLACKOUTS.EB_TYPE'
      AND    rv_low_value = p_eb_type;
   blackout_type_one blackout_type_cur%ROWTYPE;


   CURSOR hosts_cur IS
      SELECT h_id id
      ,      h_name code
      FROM hosts
      ORDER BY h_name;

   CURSOR host_cur IS
      SELECT h_id id
      ,      h_name code
      FROM hosts
      WHERE h_id = p_eb_type_id;
   host host_cur%ROWTYPE;



   CURSOR sids_cur IS
      SELECT s_id id
      ,      s_name code
      FROM   sids
      ORDER BY s_name;

   CURSOR sid_cur IS
      SELECT s_id id
      ,      s_name code
      FROM   sids
      WHERE s_id = p_eb_type_id;
   sid sid_cur%ROWTYPE;



   CURSOR admins_cur IS
      SELECT a_id id
      ,      a_name code
      FROM admins
      ORDER BY a_name;

   CURSOR admin_cur IS
      SELECT a_id id
      ,      a_name code
      FROM admins
      WHERE a_id = p_eb_type_id;
   admin admin_cur%ROWTYPE;



   CURSOR events_cur IS
      SELECT e_id id
      ,      e_code||'('||e_code_base||'/'||e_file_name||')' code
      FROM   events
      ORDER BY e_code;

   CURSOR event_cur IS
      SELECT e_id id
      ,      e_code||'('||e_code_base||'/'||e_file_name||')' code
      FROM   events
      WHERE e_id = p_eb_type_id;
   event event_cur%ROWTYPE;



   CURSOR pages_cur IS
      SELECT ae_id id
      ,      a_name||'/'||ae_desc||'('||ae_email||')' code
      FROM   admins a
      ,      admin_emails ae
      WHERE  ae.a_id = a.a_id
      ORDER BY 2;

   CURSOR page_cur IS
      SELECT ae_id id
      ,      a_name||'/'||ae_desc||'('||ae_email||')' code
      FROM   admins a
      ,      admin_emails ae
      WHERE  ae.a_id = a.a_id
      AND    ae_id = p_eb_type_id;
   page page_cur%ROWTYPE;



   CURSOR evnt_assignments_cur IS
      SELECT /*+ RULE */ ea_id id
      ,      ea.h_name||':'||ea.s_name||'('||e_file_name||'['||ep.ep_code||']'||')' code
      FROM   event_assigments_v ea
      ,      event_parameters ep
      WHERE  ea.ep_id = ep.ep_id
      AND    ea.e_id = ep.e_id
      ORDER BY 2;

   CURSOR evnt_assignment_cur IS
      SELECT /*+ RULE */ ea_id id
      ,      ea.h_name||':'||ea.s_name||'('||e_file_name||'['||ep.ep_code||']'||')' code
      FROM   event_assigments_v ea
      ,      event_parameters ep
      WHERE  ea.ep_id = ep.ep_id
      AND    ea.e_id = ep.e_id
      AND    ea.ea_id = p_eb_type_id;
   evnt_assignment evnt_assignment_cur%ROWTYPE;



   CURSOR coll_assigments_cur IS
      SELECT /*+ RULE */ ca_id id
      ,      s_name||'('||cp_code||')' code
      FROM   coll_parameters cp
      ,      sids s
      ,      coll_assigments ca
      WHERE  ca.s_id = s.s_id
      AND    ca.cp_id = cp.cp_id
      AND    ca.c_id = cp.c_id
      ORDER BY 2;

   CURSOR coll_assigment_cur IS
      SELECT /*+ RULE */ ca_id id
      ,      s_name||'('||cp_code||')' code
      FROM   coll_parameters cp
      ,      sids s
      ,      coll_assigments ca
      WHERE  ca.s_id = s.s_id
      AND    ca.cp_id = cp.cp_id
      AND    ca.c_id = cp.c_id
      AND    ca.ca_id = p_eb_type_id;
   coll_assigment coll_assigment_cur%ROWTYPE;

   -- SWITCHES
   PRINT_BL_TYPE       BOOLEAN DEFAULT FALSE;

   PRINT_REPORT_BANNER BOOLEAN DEFAULT FALSE;
   PRINT_NEW_BANNER    BOOLEAN DEFAULT FALSE;
   PRINT_EDIT_BANNER   BOOLEAN DEFAULT FALSE;

   PRINT_FOOTER        BOOLEAN DEFAULT TRUE;
   PRINT_REPORT        BOOLEAN DEFAULT TRUE;

   PRINT_INSERT_FORM   BOOLEAN DEFAULT FALSE;
   PRINT_UPDATE_FORM   BOOLEAN DEFAULT FALSE;

   l_blackout_type VARCHAR2(50);
   l_bl_reason VARCHAR2(500);
   l_bl_reason_compare VARCHAR2(500);
BEGIN

   -- SET SWITCHES
   --
   IF p_operation IS NULL OR
      (p_operation = 'N-ALL' AND p_eb_type IS NULL) OR
      p_operation = 'U' OR
      p_operation = 'I' OR
      p_operation = 'D' OR
      p_operation = 'CANCEL' THEN

      PRINT_REPORT_BANNER := TRUE;
      PRINT_BL_TYPE := TRUE;
   END IF;

   IF p_eb_type IS NOT NULL AND
      p_operation = 'N-ALL' THEN

      PRINT_NEW_BANNER := TRUE;
      PRINT_INSERT_FORM := TRUE;
   END IF;

   IF p_eb_type IS NOT NULL AND
      p_operation = 'E' THEN

      PRINT_EDIT_BANNER := TRUE;
      PRINT_UPDATE_FORM := TRUE;
   END IF;



   -- PRINT BANNERS
   --
   IF PRINT_NEW_BANNER THEN

      OPEN blackout_type_cur;
      FETCH blackout_type_cur INTO blackout_type_one;
      CLOSE blackout_type_cur;

      l_blackout_type := blackout_type_one.meaning;

      web_std_pkg.header('Monitoring System - New '||l_blackout_type||' blackout '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'GLOB');
   END IF;


   IF PRINT_REPORT_BANNER THEN
      web_std_pkg.header('Monitoring System - Blackouts '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'GLOB');
   END IF;


   IF PRINT_EDIT_BANNER THEN

      OPEN blackout_type_cur;
      FETCH blackout_type_cur INTO blackout_type_one;
      CLOSE blackout_type_cur;

      l_blackout_type := blackout_type_one.meaning;

      web_std_pkg.header('Monitoring System - Edit '||l_blackout_type||' blackout ID='||p_eb_id||' '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'GLOB');
   END IF;
   --
   -- END PRINT BANNERS


   -- OPEN FORM
   htp.p('<form method="POST" action="glob_web_pkg.blackouts">');
   htp.p('<table cellpadding="0" cellspacing="2" border="0">');



   IF PRINT_BL_TYPE THEN
      -- EB_TYPE
      htp.p('<tr>');
      htp.p('<td>');
      htp.p('<select name="p_eb_type">');

      htp.p('<option value="" >--- CHOOSE BLACKOUT TYPE ---</option>');
      FOR blackout_type_all IN blackout_type_all_cur LOOP
         htp.p('<option value="'||blackout_type_all.value||'" >'||blackout_type_all.meaning||'</option>');
      END LOOP;

      htp.p('</select>');
      htp.p('</td>');


      -- CONTROLS
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Create">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="N-ALL">');

      -- END
      htp.p('</form>');
      htp.p('</table>');
   END IF;


   -- START FORMS
   --
   IF PRINT_INSERT_FORM THEN

      -- EB_TYPE
      htp.p('<input type="hidden" name="p_eb_type" value="'||p_eb_type||'">');


      -- EB_TYPE_ID
      -- ~~~~~~~~~~~~~~~~~~~
      --
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Blackout Target: </font></td>');
      --
      -- HOST TYPE
      --
      IF p_eb_type = 'H' THEN
         htp.p('<td>');
         htp.p('<select name="p_eb_type_id">');
         htp.p('<option value="" >--- CHOOSE HOST ---</option>');

         FOR hosts IN hosts_cur LOOP
            IF hosts.id = p_eb_type_id THEN
               htp.p('<option value="'||hosts.id||'" selected>'||hosts.code||'</option>');
            ELSE
               htp.p('<option value="'||hosts.id||'" >'||hosts.code||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
      -- END HOST


      -- SID TYPE
      --
      ELSIF p_eb_type = 'S' THEN
         htp.p('<td>');
         htp.p('<select name="p_eb_type_id">');
         htp.p('<option value="" >--- CHOOSE SID ---</option>');

         FOR sids IN sids_cur LOOP
            IF sids.id = p_eb_type_id THEN
               htp.p('<option value="'||sids.id||'" selected>'||sids.code||'</option>');
            ELSE
               htp.p('<option value="'||sids.id||'" >'||sids.code||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
      -- END SID


      -- ADMIN TYPE
      --
      ELSIF p_eb_type = 'A' THEN
         htp.p('<td>');
         htp.p('<select name="p_eb_type_id">');
         htp.p('<option value="" >--- CHOOSE ADMIN ---</option>');

         FOR admins IN admins_cur LOOP
            IF admins.id = p_eb_type_id THEN
               htp.p('<option value="'||admins.id||'" selected>'||admins.code||'</option>');
            ELSE
               htp.p('<option value="'||admins.id||'" >'||admins.code||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
      -- END ADMIN


      -- EVENT TYPE
      --
      ELSIF p_eb_type = 'E' THEN
         htp.p('<td>');
         htp.p('<select name="p_eb_type_id">');
         htp.p('<option value="" >--- CHOOSE EVENT ---</option>');

         FOR events IN events_cur LOOP
            IF events.id = p_eb_type_id THEN
               htp.p('<option value="'||events.id||'" selected>'||events.code||'</option>');
            ELSE
               htp.p('<option value="'||events.id||'" >'||events.code||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
      -- END EVENT


      -- PAGERS TYPE
      --
      ELSIF p_eb_type = 'P' THEN
         htp.p('<td>');
         htp.p('<select name="p_eb_type_id">');
         htp.p('<option value="" >--- CHOOSE PAGER ---</option>');

         FOR pages IN pages_cur LOOP
            IF pages.id = p_eb_type_id THEN
               htp.p('<option value="'||pages.id||'" selected>'||pages.code||'</option>');
            ELSE
               htp.p('<option value="'||pages.id||'" >'||pages.code||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
      -- END PAGERS


      -- EVNT ASSIGNMENTS TYPE
      --
      ELSIF p_eb_type = 'X' THEN
         htp.p('<td>');
         htp.p('<select name="p_eb_type_id">');
         htp.p('<option value="" >--- CHOOSE EVENT ASSIGNMENT ---</option>');

         FOR evnt_assignments IN evnt_assignments_cur LOOP
            IF evnt_assignments.id = p_eb_type_id THEN
               htp.p('<option value="'||evnt_assignments.id||'" selected>'||evnt_assignments.code||'</option>');
            ELSE
               htp.p('<option value="'||evnt_assignments.id||'" >'||evnt_assignments.code||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
      -- END EVNT ASSIGNMENTS



      -- COLL ASSIGMENTS TYPE
      --
      ELSIF p_eb_type = 'C' THEN
         htp.p('<td>');
         htp.p('<select name="p_eb_type_id">');
         htp.p('<option value="" >--- CHOOSE COLLECTION ASSIGNMENT ---</option>');

         FOR coll_assigments IN coll_assigments_cur LOOP
            IF coll_assigments.id = p_eb_type_id THEN
               htp.p('<option value="'||coll_assigments.id||'" selected>'||coll_assigments.code||'</option>');
            ELSE
               htp.p('<option value="'||coll_assigments.id||'" >'||coll_assigments.code||'</option>');
            END IF;
         END LOOP;

         htp.p('</select>');
         htp.p('</td>');
      -- END COLL ASSIGMENTS
      END IF;
      htp.p('</tr>');

   -- END INSERT FORM PART 1
   END IF;


   -- UPDATE FORM PART 1
   IF PRINT_UPDATE_FORM THEN

      -- EB_ID
      htp.p('<input type="hidden" name="p_eb_id" value="'||p_eb_id||'">');

      -- EB_TYPE
      htp.p('<input type="hidden" name="p_eb_type" value="'||p_eb_type||'">');


      -- EB_TYPE_ID
      -- ~~~~~~~~~~~~~~~~~~~
      --
      htp.p('<input type="hidden" name="p_eb_type_id" value="'||p_eb_type_id||'">');

      htp.p('<tr>');
      htp.p('<td><font class="TRT">Blackout Target: </font></td>');
      --
      -- HOST TYPE
      --
      IF p_eb_type = 'H' THEN
         OPEN host_cur;
         FETCH host_cur INTO host;
         CLOSE host_cur;
         htp.p('<td><font class="TRT">'||NVL(host.code,'INVALID_ID: '||p_eb_type_id)||'</font></td>');
         htp.p('</td>');
      -- END HOST


      -- SID TYPE
      --
      ELSIF p_eb_type = 'S' THEN
         OPEN sid_cur;
         FETCH sid_cur INTO sid;
         CLOSE sid_cur;
         htp.p('<td><font class="TRT">'||NVL(sid.code,'INVALID_ID: '||p_eb_type_id)||'</font></td>');
         htp.p('</td>');
      -- END SID


      -- ADMIN TYPE
      --
      ELSIF p_eb_type = 'A' THEN
         OPEN admin_cur;
         FETCH admin_cur INTO admin;
         CLOSE admin_cur;
         htp.p('<td><font class="TRT">'||NVL(admin.code,'INVALID_ID: '||p_eb_type_id)||'</font></td>');
         htp.p('</td>');
      -- END ADMIN


      -- EVENT TYPE
      --
      ELSIF p_eb_type = 'E' THEN
         OPEN event_cur;
         FETCH event_cur INTO event;
         CLOSE event_cur;
         htp.p('<td><font class="TRT">'||NVL(event.code,'INVALID_ID: '||p_eb_type_id)||'</font></td>');
         htp.p('</td>');
      -- END EVENT


      -- PAGERS TYPE
      --
      ELSIF p_eb_type = 'P' THEN
         OPEN page_cur;
         FETCH page_cur INTO page;
         CLOSE page_cur;
         htp.p('<td><font class="TRT">'||NVL(page.code,'INVALID_ID: '||p_eb_type_id)||'</font></td>');
         htp.p('</td>');
      -- END PAGERS


      -- EVNT ASSIGNMENTS TYPE
      --
      ELSIF p_eb_type = 'X' THEN
         OPEN evnt_assignment_cur;
         FETCH evnt_assignment_cur INTO evnt_assignment;
         CLOSE evnt_assignment_cur;
         htp.p('<td><font class="TRT">'||NVL(evnt_assignment.code,'INVALID_ID: '||p_eb_type_id)||'</font></td>');
         htp.p('</td>');
      -- END EVNT ASSIGNMENTS



      -- COLL ASSIGMENTS TYPE
      --
      ELSIF p_eb_type = 'C' THEN
         OPEN coll_assigment_cur;
         FETCH coll_assigment_cur INTO coll_assigment;
         CLOSE coll_assigment_cur;
         htp.p('<td><font class="TRT">'||NVL(coll_assigment.code,'INVALID_ID: '||p_eb_type_id)||'</font></td>');
         htp.p('</td>');
      -- END COLL ASSIGMENTS
      END IF;
      htp.p('</tr>');

   -- END UPDATE FORM PART 2
   END IF;


   -- COMMON FORM COMPONENTS
   --
   IF PRINT_INSERT_FORM OR
      PRINT_UPDATE_FORM THEN

      -- EB_CODE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Blackout Code: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_eb_code size=20 maxlength=50 value="'||p_eb_code||'">');
      htp.p('</td>');
      htp.p('</tr>');

      -- EB_DESC
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Description: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_eb_desc size=50 maxlength=256 value="'||p_eb_desc||'">');
      htp.p('</td>');
      htp.p('</tr>');

      -- LOC_SD
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Start Date [DD/MM/YYYY]: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_loc_sd size=11 maxlength=10 value="'||p_loc_sd||'">');
      htp.p('<font class="TRT">[NOBOUND=blank]</font></td>');
      htp.p('</tr>');

      -- LOC_ED
      htp.p('<tr>');
      htp.p('<td><font class="TRT">End Date [DD/MM/YYYY]: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_loc_ed size=11 maxlength=10 value="'||p_loc_ed||'">');
      htp.p('<font class="TRT">[NOBOUND=blank]</font></td>');
      htp.p('</tr>');

      -- EB_WEEK_DAY
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Week Day: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_eb_week_day">');
      FOR week_day IN week_day_cur LOOP
         IF week_day.value = p_eb_week_day THEN
            htp.p('<option value="'||week_day.value||'" selected>'||week_day.meaning||'</option>');
         ELSE
            htp.p('<option value="'||week_day.value||'" >'||week_day.meaning||'</option>');
         END IF;
      END LOOP;
      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');



      -- START TIME
      -- LOC_SHH
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Start Time [HH:MI]: </font></td>');
      htp.p('<td>');

      htp.p('<select name="p_loc_shh">');
      htp.p('<option value="00" >00</option>');
      FOR i IN (SELECT LTRIM(TO_CHAR(ROWNUM,'09')) val FROM all_objects WHERE ROWNUM < 24) LOOP
         IF i.val = p_loc_shh THEN
            htp.p('<option value="'||i.val||'" selected>'||i.val||'</option>');
         ELSE
            htp.p('<option value="'||i.val||'" >'||i.val||'</option>');
         END IF;
      END LOOP;
      htp.p('</select>');

      htp.p(':');

      -- LOC_SMI
      htp.p('<select name="p_loc_smi">');
      htp.p('<option value="00" >00</option>');
      FOR i IN (SELECT LTRIM(TO_CHAR(ROWNUM,'09')) val FROM all_objects WHERE ROWNUM < 60) LOOP
         IF i.val = p_loc_smi THEN
            htp.p('<option value="'||i.val||'" selected>'||i.val||'</option>');
         ELSE
            htp.p('<option value="'||i.val||'" >'||i.val||'</option>');
         END IF;
      END LOOP;
      htp.p('</select>');

      htp.p('</td>');
      htp.p('</tr>');
   -- END COMMON FORM COMPONENTS
   END IF;



   -- INSERT FORM PART 2
   --
   IF PRINT_INSERT_FORM THEN
      -- END TIME
      -- LOC_EHH
      htp.p('<tr>');
      htp.p('<td><font class="TRT">End Time [HH:MI]: </font></td>');
      htp.p('<td>');

      htp.p('<select name="p_loc_ehh">');
      htp.p('<option value="00" >00</option>');
      FOR i IN (SELECT LTRIM(TO_CHAR(ROWNUM,'09')) val FROM all_objects WHERE ROWNUM < 24) LOOP
         IF i.val = '23' AND p_loc_ehh IS NULL THEN
            htp.p('<option value="'||i.val||'" selected>'||i.val||'</option>');
         ELSIF i.val = p_loc_ehh THEN
            htp.p('<option value="'||i.val||'" selected>'||i.val||'</option>');
         ELSE
            htp.p('<option value="'||i.val||'" >'||i.val||'</option>');
         END IF;
      END LOOP;
      htp.p('</select>');

      htp.p(':');

      -- LOC_EMI
      htp.p('<select name="p_loc_emi">');
      htp.p('<option value="00" >00</option>');
      FOR i IN (SELECT LTRIM(TO_CHAR(ROWNUM,'09')) val FROM all_objects WHERE ROWNUM < 60) LOOP
         IF i.val = '59' AND p_loc_emi IS NULL THEN
            htp.p('<option value="'||i.val||'" selected>'||i.val||'</option>');
         ELSIF i.val = p_loc_emi THEN
            htp.p('<option value="'||i.val||'" selected>'||i.val||'</option>');
         ELSE
            htp.p('<option value="'||i.val||'" >'||i.val||'</option>');
         END IF;
      END LOOP;
      htp.p('</select>');

      htp.p('</td>');
      htp.p('</tr>');


      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td>');
      htp.p('</td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Create">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="I">');

      -- END
      htp.p('</form>');
      htp.p('</table>');

   -- END INSERT FORM PART 2
   END IF;



   -- UPDATE FORM PART 2
   IF PRINT_UPDATE_FORM THEN

      -- END TIME
      -- LOC_EHH
      htp.p('<tr>');
      htp.p('<td><font class="TRT">End Time [HH:MI]: </font></td>');
      htp.p('<td>');

      htp.p('<select name="p_loc_ehh">');
      htp.p('<option value="00" >00</option>');
      FOR i IN (SELECT LTRIM(TO_CHAR(ROWNUM,'09')) val FROM all_objects WHERE ROWNUM < 24) LOOP
         IF i.val = p_loc_ehh THEN
            htp.p('<option value="'||i.val||'" selected>'||i.val||'</option>');
         ELSE
            htp.p('<option value="'||i.val||'" >'||i.val||'</option>');
         END IF;
      END LOOP;
      htp.p('</select>');

      htp.p(':');

      -- LOC_EMI
      htp.p('<select name="p_loc_emi">');
      htp.p('<option value="00" >00</option>');
      FOR i IN (SELECT LTRIM(TO_CHAR(ROWNUM,'09')) val FROM all_objects WHERE ROWNUM < 60) LOOP
         IF i.val = p_loc_emi THEN
            htp.p('<option value="'||i.val||'" selected>'||i.val||'</option>');
         ELSE
            htp.p('<option value="'||i.val||'" >'||i.val||'</option>');
         END IF;
      END LOOP;
      htp.p('</select>');

      htp.p('</td>');
      htp.p('</tr>');

      -- EB_ACTIVE_FLAG
      htp.p('<tr>');
      htp.p('<td><font class="TRT">Enabled: </font></td>');
      htp.p('<td>');
      htp.p('<select name="p_eb_active_flag">');
      IF p_eb_active_flag = 'Y' THEN
         htp.p('<option value="'||p_eb_active_flag||'" selected>Yes</option>');
         htp.p('<option value="N" >No</option>');
      ELSE
         htp.p('<option value="Y" >Yes</option>');
         htp.p('<option value="'||p_eb_active_flag||'" selected>No</option>');
      END IF;
      htp.p('</select>');
      htp.p('</td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td>');
      htp.p('</td>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Update">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="U">');
      htp.p('<input type="hidden" name="p_date_modified" value="'||p_date_modified||'">');

      -- END
      htp.p('</form>');
      htp.p('</table>');

   -- END UPDATE FORM PART 2
   END IF;


   IF p_operation = 'EDIT' THEN
      OPEN blc_one_cur;
      FETCH blc_one_cur INTO blc_one;
      CLOSE blc_one_cur;

      glob_web_pkg.blackouts(
         p_eb_id          => blc_one.eb_id
      ,  p_date_modified  => blc_one.date_modified
      ,  p_eb_code        => blc_one.eb_code
      ,  p_eb_type        => blc_one.eb_type
      ,  p_eb_type_id     => blc_one.eb_type_id
      ,  p_loc_sd         => blc_one.loc_sd
      ,  p_loc_ed         => blc_one.loc_ed
      ,  p_loc_shh        => blc_one.loc_shh
      ,  p_loc_ehh        => blc_one.loc_ehh
      ,  p_loc_smi        => blc_one.loc_smi
      ,  p_loc_emi        => blc_one.loc_emi
      ,  p_eb_week_day    => blc_one.eb_week_day
      ,  p_eb_active_flag => blc_one.eb_active_flag
      ,  p_eb_desc        => blc_one.eb_desc
      ,  p_operation      => 'E');

      PRINT_REPORT := FALSE;
      PRINT_FOOTER := FALSE;

   -- END EDIT FORM
   END IF;


   IF p_operation = 'COPY' THEN
      OPEN blc_one_cur;
      FETCH blc_one_cur INTO blc_one;
      CLOSE blc_one_cur;

      glob_web_pkg.blackouts(
         p_eb_id          => NULL
      ,  p_date_modified  => NULL
      ,  p_eb_code        => blc_one.eb_code
      ,  p_eb_type        => blc_one.eb_type
      ,  p_eb_type_id     => blc_one.eb_type_id
      ,  p_loc_sd         => blc_one.loc_sd
      ,  p_loc_ed         => blc_one.loc_ed
      ,  p_loc_shh        => blc_one.loc_shh
      ,  p_loc_ehh        => blc_one.loc_ehh
      ,  p_loc_smi        => blc_one.loc_smi
      ,  p_loc_emi        => blc_one.loc_emi
      ,  p_eb_week_day    => blc_one.eb_week_day
      ,  p_eb_active_flag => 'Y'
      ,  p_eb_desc        => blc_one.eb_desc
      ,  p_operation      => 'N-ALL');

      PRINT_REPORT := FALSE;
      PRINT_FOOTER := FALSE;

   -- END EDIT FORM
   END IF;


   IF p_operation = 'CANCEL' THEN

      glob_web_pkg.blackouts;

      PRINT_REPORT := FALSE;
      PRINT_FOOTER := FALSE;

   -- END CANCEL FORM
   END IF;

   --
   -- END FORMS


   -- START DML OPERATION
   --
   IF p_operation = 'I' THEN
      BEGIN

         glob_api_pkg.eb(
            p_eb_id          => NULL
         ,  p_date_modified  => NULL
         ,  p_modified_by    => NULL
         ,  p_created_by     => USER
         ,  p_eb_code        => p_eb_code
         ,  p_eb_type        => p_eb_type
         ,  p_eb_type_id     => p_eb_type_id
         ,  p_eb_start_date  => TO_DATE(NVL(p_loc_sd,'01/01/0001')||' '||p_loc_shh||':'||p_loc_smi,'DD/MM/RRRR HH24:MI')
         ,  p_eb_end_date    => TO_DATE(NVL(p_loc_ed,'01/01/9000')||' '||p_loc_ehh||':'||p_loc_emi,'DD/MM/RRRR HH24:MI')
         ,  p_eb_week_day    => p_eb_week_day
         ,  p_eb_active_flag => 'Y'
         ,  p_eb_desc        => p_eb_desc
         ,  p_operation      => 'I');

      EXCEPTION
         WHEN OTHERS THEN
            htp.p('<b>ERROR</b>: '||SQLERRM);
      END;
   END IF;

   IF p_operation = 'U' THEN
      BEGIN

         glob_api_pkg.eb(
            p_eb_id          => p_eb_id
         ,  p_date_modified  => TO_DATE(p_date_modified,'DD-MON-RRRR HH24:MI:SS')
         ,  p_modified_by    => USER
         ,  p_created_by     => NULL
         ,  p_eb_code        => p_eb_code
         ,  p_eb_type        => p_eb_type
         ,  p_eb_type_id     => p_eb_type_id
         ,  p_eb_start_date  => TO_DATE(NVL(p_loc_sd,'01/01/0001')||' '||p_loc_shh||':'||p_loc_smi,'DD/MM/RRRR HH24:MI')
         ,  p_eb_end_date    => TO_DATE(NVL(p_loc_ed,'01/01/9000')||' '||p_loc_ehh||':'||p_loc_emi,'DD/MM/RRRR HH24:MI')
         ,  p_eb_week_day    => p_eb_week_day
         ,  p_eb_active_flag => p_eb_active_flag
         ,  p_eb_desc        => p_eb_desc
         ,  p_operation      => 'U');

      EXCEPTION
         WHEN OTHERS THEN
            htp.p('<b>ERROR</b>: '||SQLERRM);
      END;
   END IF;

   IF p_operation = 'D' THEN
      BEGIN

         glob_api_pkg.eb(
            p_eb_id          => p_eb_id
         ,  p_date_modified  => NULL
         ,  p_modified_by    => NULL
         ,  p_created_by     => NULL
         ,  p_eb_code        => NULL
         ,  p_eb_type        => NULL
         ,  p_eb_type_id     => NULL
         ,  p_eb_start_date  => NULL
         ,  p_eb_end_date    => NULL
         ,  p_eb_week_day    => NULL
         ,  p_eb_active_flag => NULL
         ,  p_eb_desc        => NULL
         ,  p_operation      => 'D');

      EXCEPTION
         WHEN OTHERS THEN
            htp.p('<b>ERROR</b>: '||SQLERRM);
      END;
   END IF;

   -- END DML OPERATION



   IF PRINT_REPORT THEN
      -- PRINT ALL BLACKOUTS
      --
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Control Links</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Id</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Enabled</font></TH>');

      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Target</font></TH>');

      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Start DATE</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">End DATE</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Start TIME</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">End TIME</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Week DAY</font></TH>');

      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Code</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Type</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Description</font></TH>');

      FOR blc IN blc_cur LOOP

         IF glob_util_pkg.active_blackout(
               p_bl_type => blc.eb_type
            ,  p_bl_type_id => blc.eb_type_id
            ,  p_bl_reason => l_bl_reason) THEN

            -- check if this EB_ID is
            -- actually caused the blackout
            --

            l_bl_reason_compare := blc.eb_type_long||' '||blc.eb_code||' is active EB_ID='||TO_CHAR(blc.eb_id);

            -- DEBUG
            -- =======
            --htp.p('l_bl_reason='||l_bl_reason);
            --htp.p('compare='||l_bl_reason_compare);

            IF l_bl_reason = l_bl_reason_compare THEN
               htp.p('<TR BGCOLOR="'||d_BRC_A||'">');
            ELSE
               htp.p('<TR BGCOLOR="'||d_TRC||'">');
            END IF;
         ELSE
            htp.p('<TR BGCOLOR="'||d_TRC||'">');
         END IF;

         -- ALL RECORD CONTROL LINKS
         -- EDIT LINK
         htp.p('<TD nowrap><a href="glob_web_pkg.blackouts?p_eb_id='||blc.eb_id||
                                                       '&p_operation=EDIT"><font class="TRL">Edit</font></a>'||
         '<font class="TRT">|</font>'||
         /* COPY LINK */
         '<a href='||web_std_pkg.encode_url('"glob_web_pkg.blackouts?p_eb_id='||blc.eb_id||
                                                       '&p_operation=COPY">')||'<font class="TRL">Copy</font></a></TD>');

         htp.p('<TD nowrap><font class="TRT">'||blc.eb_id||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||blc.eb_active_flag||'</font></TD>');

         htp.p('<TD nowrap><font class="TRT">'||blc.eb_type_name||'</font></TD>');

         htp.p('<TD nowrap><font class="TRT">'||blc.start_date||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||blc.end_date||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||blc.start_time||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||blc.end_time||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||blc.day||'</font></TD>');

         htp.p('<TD nowrap><font class="TRT">'||blc.eb_code||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||blc.eb_type_long||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||blc.eb_desc||'</font></TD>');
         htp.p('</TR>');
      END LOOP;

      htp.p('</TABLE>');
   END IF;


   IF PRINT_FOOTER THEN
      web_std_pkg.footer;
   END IF;

END blackouts;


PROCEDURE rpt(
   p_r_code IN VARCHAR2 DEFAULT NULL
,  p_r_type IN VARCHAR2 DEFAULT NULL
,  p_db_link IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR rptd_cur IS
      SELECT
         r_id
      ,  r_code
      ,  r_type
      ,  r_name
      ,  r_desc
      ,  r_sql
      FROM reports
      WHERE r_code = UPPER(p_r_code);
   rptd rptd_cur%ROWTYPE;
   
   PRINT_REPORT BOOLEAN DEFAULT FALSE;
   
   PRINT_FOOTER BOOLEAN DEFAULT TRUE;
   
   invalid_report EXCEPTION;
   l_loc VARCHAR2(4) DEFAULT 'GLOB';
   
BEGIN
   IF p_r_code IS NOT NULL THEN
      PRINT_REPORT := TRUE;
   END IF;
   
   -- derive which page header to call
   SELECT DECODE(UPPER(p_r_type),
             'R','MAIN',
             'E','MAIN',
             'C','COLL',
                 'GLOB')
   INTO l_loc
   FROM dual;
         
   IF PRINT_REPORT THEN
      OPEN rptd_cur;
      FETCH rptd_cur INTO rptd;
      
      IF rptd_cur%NOTFOUND THEN
         CLOSE rptd_cur;
         RAISE invalid_report;
      ELSE
         CLOSE rptd_cur;
      END IF;
      
      web_std_pkg.header('Monitoring System - Run Report '||rptd.r_name||' '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),l_loc);
      
      htp.p('<TABLE border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      htp.p('<TR>');
      htp.p('<TD nowrap><font class="TRT"><b>'||rptd.r_name||'</b></font></TD>');
      htp.p('</TR>');
      
      htp.p('<TR>');
      htp.p('<TD>');
      htp.p('<PRE>');
      htp.p(rptd.r_desc);
      htp.p('</PRE>');
      htp.p('</TD>');
      htp.p('</TR>');
      htp.p('</TABLE>');
      
      -- check if we need to parse out
      -- database link
      IF rptd.r_type = 'R' AND
         p_db_link IS NULL
      THEN
         -- build table with db links
         htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
         htp.p('<TR>');
         htp.p('<TH ALIGN="Center" BGCOLOR="'||d_THC||'" colspan=4><font class="THT">Pick Target Database Link</font></TH>');
         htp.p('</TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Target</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">DB Link</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Username</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">TNS Alias</font></TH>');
         
         FOR links IN (SELECT
                          h.h_name||':'||s.s_name target
                       ,  sc.sc_db_link_name
                       ,  sc.sc_username
                       ,  sc.sc_tns_alias
                       FROM sid_credentials sc
                       ,    sids s
                       ,    hosts h
                       WHERE sc.s_id = s.s_id
                       AND s.h_id = h.h_id
                       ORDER BY 1,3,4)
         LOOP
            htp.p('<TR>');
            htp.p('<TD nowrap><font class="TRT">'||links.target||'</font></TD>');
            htp.p('<TD nowrap><a href='||web_std_pkg.encode_url('"glob_web_pkg.rpt?p_r_type='||p_r_type||'&p_r_code='||rptd.r_code||
                                            '&p_db_link='||links.sc_db_link_name||'">')||
               '<font class="TRL">'||links.sc_db_link_name||'</font></a></TD>');
            htp.p('<TD nowrap><font class="TRT">'||links.sc_username||'</font></TD>');
            htp.p('<TD nowrap><font class="TRT">'||links.sc_tns_alias||'</font></TD>');
            htp.p('</TR>');
         END LOOP;
         htp.p('</TABLE>');
         
      ELSIF rptd.r_type = 'R' AND
         p_db_link IS NOT NULL
      THEN
         glob_web_pkg.exec_sql(
            p_report => rptd.r_code
         ,  p_pag => 'YES'
         ,  p_heading => rptd.r_name||' ('||p_db_link||')'
         ,  p_rep_what => '&DB_LINK_NAME'
         ,  p_rep_with => p_db_link);  
      	
      ELSE
         glob_web_pkg.exec_sql(
            p_report => rptd.r_code
         ,  p_pag => 'YES'
         ,  p_heading => rptd.r_name);
      END IF;
      
   
   ELSE
      web_std_pkg.header('Monitoring System - Reports '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),l_loc);
      
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      
      FOR rtypes IN (SELECT DISTINCT r_type
                     ,   DECODE(r_type,
                            'R','Remote Database Reports',
                            'C','Collection Reports',
                            'E','Event Reports') typel
                     FROM reports
                     WHERE DECODE(p_r_type,NULL,'x',r_type) = NVL(p_r_type,'x')
                     AND   r_type != 'X'
                     ORDER BY 
                        DECODE(r_type,'E',1,'C',2,'R',3))
      LOOP
         htp.p('<TR>');
         htp.p('<TH ALIGN="Center" BGCOLOR="'||d_THC||'" colspan=2><font class="THT">'||rtypes.typel||'</font></TH>');
         htp.p('</TR>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Name</font></TH>');
         htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Description</font></TH>');

         FOR reps IN (SELECT r_code, r_name, r_desc
                      FROM reports 
                      WHERE r_type = rtypes.r_type)
         LOOP

            htp.p('<TR>');
            htp.p('<TD nowrap><a href='||web_std_pkg.encode_url('"glob_web_pkg.rpt?p_r_type='||p_r_type||'&p_r_code='||reps.r_code||'">')||
               '<font class="TRL">'||reps.r_name||'</font></a></TD>');
            htp.p('<TD nowrap><font class="TRT">'||reps.r_desc||'</font></TD>');
            htp.p('</TR>');

         -- reports cur
         END LOOP;
      
      -- types cur
      END LOOP;
      htp.p('</TABLE>');

   END IF;

   
   IF PRINT_FOOTER THEN
      web_std_pkg.footer;
   END IF;      
      
EXCEPTION
   WHEN invalid_report THEN
      web_std_pkg.header('Monitoring System - Invalid Report '||p_r_code||' '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'GLOB');
END rpt;
      

PROCEDURE trace_on IS
BEGIN
   dbms_session.set_sql_trace(TRUE);
END trace_on;

PROCEDURE trace_off IS
BEGIN
   dbms_session.set_sql_trace(FALSE);
END trace_off;


END glob_web_pkg;
/

show errors
