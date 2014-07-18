set scan off

CREATE OR REPLACE PACKAGE web_std_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : web_std_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : web_std_pkgs.sql
-- DATE CREATED  : 07/02/2002
-- APPLICATION   : GLOBAL WEB UTIL
-- VERSION       : 3.5.13
-- DESCRIPTION   : Various HTML util (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 07/02/02  vmogilev    created
--
-- 10/25/02  vmogilev    menu_events - acks links
--
-- 10/30/02  vmogilev    main_header_str - implemented css parse STL% 
--                          during header build
--
-- 10/31/02  vmogilev    print_styles - created
--
-- 11/01/02  vmogilev    ui - created
--
-- 02/19/03  vmogilev    (3.5.4)
--                       encode_url - modified per ASK TOM
--                       (3.5.5)
--                       encode_url - reverted back
--
-- 02/24/03  vmogilev    (3.5.6)
--                       nav - created (merged all header* procs)
--                          now using web_*menus tables
--                       header - added p_start as a flag to
--                          print navigator menu
--
-- 02/25/03  vmogilev    (3.5.7)
--                       nav - fixed missing footer on menu pages
--
-- 03/07/03  vmogilev    (3.5.8)
--                       encode_ustr - created used for dynamic reports
--                          when all special chars need to be escaped
--
-- 03/10/03  vmogilev    (3.5.9)
--                       header - removed p_start since menu build is
--                          now handled by web_nav_pkg it self
--                       nav - (PRIV) removed menu build routines
--
-- 03/11/03  vmogilev    (3.5.10)
--                       header, footer, nav - added p_menu to handle
--                          menu builds for all pages not only for
--                          initial page that used to be invoked thru
--                          web_nav_pkg
--                       bmenu - (PRIV) moved from web_nav_pkg to
--                          support above
--
-- 03/12/03  vmogilev    (3.5.11)
--                       bmenu - cosmetic changes to table layout
--
-- 03/25/03  vmogilev    (3.5.12)
--                       bmenu - added title to menu links
--                           added forgotten sort (wsm_sort) to subm
-- 05/30/03  vmogilev    (3.5.13)
--                       main_footer - "contact us" to http://kb.dbatoolz.com/tp/1458.evnt_support.html
--                       header_end - added EVNT banner
-- ---------------------------------------------------------------------
PROCEDURE ui(
   p_wb_code   IN VARCHAR2 DEFAULT NULL
,  p_wb_val    IN VARCHAR2 DEFAULT NULL
,  p_wb_desc   IN VARCHAR2 DEFAULT NULL
,  p_operation IN VARCHAR2 DEFAULT NULL);


PROCEDURE print_styles;

PROCEDURE header(
   p_message  IN VARCHAR2 DEFAULT NULL
,  p_location IN VARCHAR2 DEFAULT 'MAIN'
,  p_menu     IN BOOLEAN  DEFAULT TRUE);

PROCEDURE footer(
   p_location IN VARCHAR DEFAULT 'MAIN'
,  p_menu     IN BOOLEAN DEFAULT TRUE);

FUNCTION gattr(
   p_attr IN VARCHAR2) RETURN VARCHAR2;

FUNCTION encode_url(
   p_url IN VARCHAR2) RETURN VARCHAR2;

FUNCTION encode_ustr(
   p_ustr IN VARCHAR2) RETURN VARCHAR2;

--pragma restrict_references(encode_ustr,wnds);
--pragma restrict_references(web_std_pkg,wnps,rnps);
  

END web_std_pkg;
/
