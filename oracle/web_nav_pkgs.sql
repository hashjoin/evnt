CREATE OR REPLACE PACKAGE web_nav_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : web_nav_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : web_nav_pkgs.sql
-- DATE CREATED  : 02/24/2003
-- APPLICATION   : GLOBAL WEB NAVIGATION
-- VERSION       : 3.5.9
-- DESCRIPTION   : Menu Navigator (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 02/24/03  vmogilev    created
--
-- 03/10/03  vmogilev    (3.5.6)
--                       nav - (PRIV) created (moved from web_std_pkg)
--                          for easier page builds, web_std_pkg will
--                          only build the header and footer all menu
--                          prints are handled from here now ...
--                       bmenu - created; allows menu build from anywhere
--                          in the application
--                       evnt,coll,glob - moded to call nav instead of
--                          web_std_pkg.header
--                       evnt - added "At A Glance" handlers
--
-- 03/11/03  vmogilev    (3.5.7)
--                       bmenu - moved to web_std_pkg allows for menu
--                          builds from other pages not only from here
--                       evnt - added "stale" to "At A Glance"
--
-- 03/12/03  vmogilev    (3.5.8)
--                       evnt - cosmetic changes to at-a-glance
--
-- 03/27/03  vmogilev    (3.5.9)
--                       evnt - added "l" and "r" statuses
-- ---------------------------------------------------------------------
PROCEDURE evnt;

PROCEDURE coll;

PROCEDURE glob;

END web_nav_pkg;
/

show errors

