set scan off

CREATE OR REPLACE PACKAGE BODY web_std_pkg AS

/* GLOBAL FORMATING */
  d_THC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('THC');  /* Table Header Color     */
  d_TRC  web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('TRC');  /* Table Row Color        */
  d_PHCM web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCM'); /* Page Header Main Color */
  d_PHCS web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHCS'); /* Page Header Sub Color  */
  d_PHMA web_attributes.wb_val%TYPE :=  web_std_pkg.gattr('PHMA'); /* Page Header Menu Color ACTIVE  */


PROCEDURE ui(
   p_wb_code   IN VARCHAR2 DEFAULT NULL
,  p_wb_val    IN VARCHAR2 DEFAULT NULL
,  p_wb_desc   IN VARCHAR2 DEFAULT NULL
,  p_operation IN VARCHAR2 DEFAULT NULL)
IS
   CURSOR all_attr_cur IS
      SELECT   
         wb_code
      ,  wb_val 
      ,  wb_desc
      FROM web_attributes
      ORDER BY wb_code;

   
   CURSOR one_attr_cur IS
      SELECT   
         wb_code
      ,  wb_val
      ,  wb_desc
      FROM web_attributes
      WHERE wb_code = p_wb_code;
   one_attr one_attr_cur%ROWTYPE;
   
   
   PRINT_REPORT BOOLEAN DEFAULT TRUE;
   PRINT_UPDATE BOOLEAN DEFAULT FALSE;
   PRINT_FOOTER BOOLEAN DEFAULT TRUE;

BEGIN
   IF p_operation = 'RESTORE' THEN
      restore_ui;
   END IF;
   
   IF p_operation = 'U' THEN
      UPDATE web_attributes
      SET wb_val = p_wb_val
      WHERE wb_code = p_wb_code;
   END IF;

   
   IF p_operation = 'EDIT' THEN
       PRINT_UPDATE := TRUE;
   END IF;
   
   
   web_std_pkg.header('UI - Attributes - '||TO_CHAR(SYSDATE,'RRRR-MON-DD HH24:MI:SS'),'UI');
      
   htp.p('<a href="web_std_pkg.ui?p_operation=RESTORE"><font class="TRL">Restore All Atributes To Default</font></a>');
   
   IF PRINT_UPDATE THEN
      OPEN one_attr_cur;
      FETCH one_attr_cur INTO one_attr;
      CLOSE one_attr_cur;
      
      htp.p('<table cellpadding="0" cellspacing="2" border="0">');
      htp.p('<form method="POST" action="web_std_pkg.ui">');
      
      -- WB_CODE
      htp.p('<tr>');
      htp.p('<td><font class="TRT">UI Code: </font></td>');
      htp.p('<td><font class="TRT">'||one_attr.wb_code||'</font></td>');
      htp.p('</tr>');

      -- WB_VAL
      htp.p('<tr>');
      htp.p('<td><font class="TRT">UI Value: </font></td>');
      htp.p('<td>');
      htp.p('<input type=text name=p_wb_val size=70 maxlength=512 value="'||one_attr.wb_val||'">');
      htp.p('</td>');
      htp.p('</tr>');

      -- WB_DESC
      htp.p('<tr>');
      htp.p('<td><font class="TRT">UI Desc: </font></td>');
      htp.p('<td><font class="TRT">'||one_attr.wb_desc||'</font></td>');
      htp.p('</tr>');

      -- CONTROLS
      htp.p('<tr>');
      htp.p('<td>');
      htp.p('<input type="SUBMIT" value="Update">');
      htp.p('</td>');
      htp.p('</tr>');

      -- HIDDEN
      htp.p('<input type="hidden" name="p_operation" value="U">');
      htp.p('<input type="hidden" name="p_wb_code" value="'||one_attr.wb_code||'">');
      
      htp.p('</form>');
      htp.p('</table>');
   END IF;


   IF PRINT_REPORT THEN
      -- PRINT ALL ATTRIBUTES
      --
      htp.p('<TABLE  border="2" cellspacing=0 cellpadding=2 BGCOLOR="'||d_TRC||'">');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">Control Links</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">UI Code</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">UI Value</font></TH>');
      htp.p('<TH ALIGN="Left" BGCOLOR="'||d_THC||'"><font class="THT">UI Description</font></TH>');
      
      FOR all_attr IN all_attr_cur LOOP
         htp.p('<TR BGCOLOR="'||d_TRC||'">');
         htp.p('<TD nowrap><a href="web_std_pkg.ui?p_wb_code='||all_attr.wb_code||
                                                       '&p_operation=EDIT"><font class="TRL">Edit</font></a></TD>');

         htp.p('<TD nowrap><font class="TRT">'||all_attr.wb_code||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||all_attr.wb_val||'</font></TD>');
         htp.p('<TD nowrap><font class="TRT">'||all_attr.wb_desc||'</font></TD>');

         htp.p('</TR>');
      END LOOP;

      htp.p('</TABLE>');
   END IF;
         
   IF PRINT_FOOTER THEN
      web_std_pkg.footer;
   END IF;
         
END ui;



PROCEDURE print_styles
IS
   CURSOR style_cur IS
      SELECT wb_val value
      FROM web_attributes
      WHERE wb_code LIKE 'STL%';
BEGIN
   htp.p('<style>');
   FOR style IN style_cur LOOP
      htp.p(style.value);
   END LOOP;
   htp.p('</style>');
END print_styles;

  
FUNCTION gattr(p_attr IN VARCHAR2) RETURN VARCHAR2
IS
   CURSOR attributes_cur IS
      SELECT wb_val
      FROM   web_attributes
      WHERE  wb_code = p_attr;
   attributes attributes_cur%ROWTYPE;
   invalid_attribute EXCEPTION;
   l_return_value VARCHAR2(50);
BEGIN
   OPEN attributes_cur;
   FETCH attributes_cur INTO attributes;
   IF attributes_cur%FOUND THEN
      CLOSE attributes_cur;
      l_return_value := attributes.wb_val;
   ELSE
      CLOSE attributes_cur;
      RAISE invalid_attribute;
   END IF;
   
   RETURN l_return_value;
   
EXCEPTION 
   WHEN invalid_attribute THEN
      RAISE_APPLICATION_ERROR(-20001,'Invalid UI attribute '||p_attr);
END gattr;


PROCEDURE header_str(
   p_message IN VARCHAR2) IS
BEGIN
   htp.p('<HTML>');
   htp.p('<HEAD>');
   htp.p('<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=ISO-8859-1">');
   htp.p('<META HTTP-EQUIV="Pragma" CONTENT="no-cache">');
   htp.p('<META HTTP-EQUIV="Expires" CONTENT="-1">');
   htp.p('<META NAME="description" CONTENT="">');
   htp.p('<META NAME="keywords" CONTENT="">');
   htp.p('<TITLE>'||p_message||'</TITLE>');
   
   web_std_pkg.print_styles;
   
   htp.p('</HEAD>');
   htp.p('<BODY link="#0000FF" vlink="#9400D3" bgcolor="#FFFFFF" LEFTMARGIN="0" TOPMARGIN="0">');
   htp.p('<TABLE  bgcolor='||d_PHCM||' cellpadding=0 cellspacing=0 border=0 width="100%">');
   htp.p('<TR>');
   htp.p('<TD ALIGN="left" height=35><font color="#FFFFFF" size="4" face="Arial"><b>&nbsp;'||p_message||'</font></TD>');
   htp.p('</TR>');
END header_str;


PROCEDURE header_end IS
BEGIN
   htp.p('<TR>');
   htp.p('<TD ALIGN="left" bgcolor='||d_PHMA||' height=15><font class="HTSml">&nbsp;EVNT (Version 3.5)&nbsp;&nbsp;['||USER||']&nbsp;<a href="logmeoff">log off</a></font></TD>');
   htp.p('</TR>');

   htp.p('</TABLE>');
END header_end;


PROCEDURE main_footer
IS
BEGIN
   htp.p('<br><p>');
   htp.p('<table width="100%" border=0 cellspacing=0 cellpadding=0>');
   htp.p('<tr>');
   htp.p('<td align=center class=smtxt>');
   htp.p('<a href="http://www.hashjoin.com/" target="_top"><font face="Arial" size="1">HASHJOIN</font></a> | <a href="http://kb.dbatoolz.com/"><font face="Arial" size="1">Contact Us</font></a>');
   htp.p('</td>');
   htp.p('</tr>');
   htp.p('<tr>');
   htp.p('<td align=center class=smtxt>');
   htp.p('<font face="Arial" size="1">Copyright&copy; 2009 HASHJOIN Corporation All Rights Reserved. </font>');
   htp.p('</td>');
   htp.p('</tr>');
   htp.p('</table>');
   htp.p('</BODY></HTML>');
END main_footer;


PROCEDURE bmenu(
   p_location IN VARCHAR2)
IS
BEGIN
   htp.p('<TABLE cellpadding=8 cellspacing=0>');
   htp.p('<TR>');

   htp.p('<TD width=115 valign=top nowrap BGCOLOR="'||d_PHMA||'">');
   htp.p('<hr noshade>');
   htp.p('<table>');
   
   FOR subm IN (SELECT
                   wsm_code
                ,  wm_code
                ,  wsm_url
                ,  wsm_name
                ,  wsm_desc
                FROM web_sub_menus
                WHERE wm_code = p_location
                ORDER BY wsm_sort)
   LOOP
      htp.p('<tr><td nowrap><a class="HTSml" href="'||subm.wsm_url||'" title="'||subm.wsm_desc||'">&nbsp;&nbsp;'||subm.wsm_name||'</a></td></tr>');
   END LOOP;

   htp.p('</table>');
   htp.p('<hr noshade>');
   htp.p('</TD>');
   htp.p('<TD valign=top nowrap bgcolor="#FFFFFF">');
END bmenu;


PROCEDURE nav(
   p_wm_code IN VARCHAR2
,  p_message IN VARCHAR2
,  p_menu    IN BOOLEAN)
IS
   CURSOR max_len_cur IS
      SELECT 
         MAX(LENGTH(wm_name)) val
      --,  MOD(MAX(LENGTH(wm_name)),LENGTH('&nbsp;'))
      FROM web_menus;
   max_len max_len_cur%ROWTYPE;
      
   CURSOR all_menu_cur(p_mlen IN NUMBER) IS
      SELECT 
         REPLACE(RPAD(wm_name,p_mlen,'#'),'#','&nbsp;') item
      ,  wm_url url
      ,  DECODE(wm_code,p_wm_code,d_PHMA,d_PHCS) mcolor
      FROM web_menus 
      ORDER BY wm_sort;
      
BEGIN
   OPEN max_len_cur;
   FETCH max_len_cur INTO max_len;
   CLOSE max_len_cur;
   
   header_str(p_message);

   -- build main header
   --
   htp.p('<tr>');
   htp.p('<td>');
   htp.p('<table  cellpadding=0 cellspacing=0 border=0 width="100%">');
   htp.p('<tr>');
   FOR all_menu IN all_menu_cur(max_len.val)
   LOOP
      htp.p('<td height=25 align=center nowrap bgcolor="'||all_menu.mcolor||'"><a class="HLMed" href="'||all_menu.url||'">'||all_menu.item||'</a></td>');
   END LOOP;
   htp.p('</tr>');
   htp.p('</table>');
   htp.p('</td>');
   htp.p('</tr>');
   
   header_end;
   
   IF p_menu THEN
      bmenu(p_wm_code);
   END IF;
END nav;

PROCEDURE header(
   p_message  IN VARCHAR2 DEFAULT NULL
,  p_location IN VARCHAR2 DEFAULT 'MAIN'
,  p_menu     IN BOOLEAN  DEFAULT TRUE)
IS
BEGIN
   nav(p_location,p_message,p_menu);
END header;


PROCEDURE footer(
   p_location IN VARCHAR DEFAULT 'MAIN'
,  p_menu     IN BOOLEAN DEFAULT TRUE)
IS
BEGIN
   IF p_menu THEN
      htp.p('</TD>');
      htp.p('</TR>');
      htp.p('</TABLE>');
   END IF;
   	
   IF p_location = 'MAIN' THEN
      main_footer;
   ELSE
      main_footer;
   END IF;
   
END footer;


FUNCTION encode_ustr(
   p_ustr IN VARCHAR2) RETURN VARCHAR2
IS
   l_tmp   VARCHAR2(12000);
   l_len   NUMBER DEFAULT LENGTH(p_ustr);
   l_bad   VARCHAR2(100) DEFAULT ' >%}\~];?@&<#{|^[`/:=$+''"'||chr(10);
   l_char  CHAR(1);
BEGIN
   if ( p_ustr is NULL ) then
           return NULL;
   end if;

   FOR i IN 1 .. l_len LOOP
      l_char :=  substr(p_ustr,i,1);
      
      IF ( INSTR( l_bad, l_char ) > 0 )
      THEN
         l_tmp := l_tmp || '%' || to_char(ascii(l_char), 'fm0X');
      
      ELSE
         l_tmp := l_tmp || l_char;
      END IF;
   
   END LOOP;

   RETURN l_tmp;
END encode_ustr;


FUNCTION encode_url(p_url IN VARCHAR2) RETURN VARCHAR2
IS
   l_return_value VARCHAR2(4000);
BEGIN
   l_return_value := REPLACE(p_url,' ','%20');
   RETURN l_return_value;
END encode_url;

END web_std_pkg;
/

show error
