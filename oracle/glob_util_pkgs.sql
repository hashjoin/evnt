CREATE OR REPLACE PACKAGE glob_util_pkg AS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : glob_util_pkg
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : glob_util_pkgs.sql
-- DATE CREATED  : 05/17/2002
-- APPLICATION   : GLOBAL
-- VERSION       : 1.8
-- DESCRIPTION   : Various Utils (see module for the details)
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 05/17/02  vmogilev    created
--
-- 03/28/03  vmogilev    (1.1)
--                       set_pend - created (called from list files)
--                       (1.2)
--                       set_pend - added 5 min "check":
--                          now if an assignment has had a status of
--                          scheduled [S,l,r] for >= 5 min I reschedule it
--                          assuming something has gone wrong
--                       (1.3)
--                       set_pend - added 5 times "check" for events
--                          and 15 times "check" for collections to
--                          avoid stale events/collections on system
--                          failures
--                       (1.4)
--                       set_pend - got rid of "NULL to 1" decode on
--                          *_last_runtime_sec when doing "times check"
--                          to avoid first time runs being mistakenly
--                          considered as stale
--                       (1.5)
--                       set_pend - added + 5 min to "times checks"
--                          to avoid counting assignments that run
--                          really fast most of the time (<1sec) but
--                          every once in a while go over the "times ratio"
--                       (1.6)
--                       set_pend - changed UNION ALL to UNION to avoid
--                          hitting bugs when all 3 "check" satisfy
--                       (1.7)
--                       set_pend - removed 15+5 "check" IT WAS total 
--                          mess by creating forever running assignments
--                       (1.8)
--                       set_pend - completely removed "check" logic
--                          it's the wrong place for it - should be
--                          handled at the process level.
-- ---------------------------------------------------------------------
PROCEDURE set_pend(
   p_type     IN VARCHAR2
,  p_max_proc IN NUMBER
,  p_rhost    IN VARCHAR2 DEFAULT NULL);

FUNCTION active_blackout(
   p_bl_type IN VARCHAR2,
   p_bl_type_id IN NUMBER,
   p_bl_reason OUT VARCHAR2)
RETURN BOOLEAN;

PROCEDURE target_int;

END glob_util_pkg;
/
show error
