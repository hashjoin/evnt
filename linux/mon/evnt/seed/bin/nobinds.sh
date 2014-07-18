#!/bin/ksh
#
# File:
#       nobinds.sh
# EVNT_REG:     NO_BINDS SEEDMON 1.3
# <EVNT_NAME>Bad Sql (no bind vars)</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (vit100gain@earthlink.net)
#
# Usage:
# <EVNT_DESC>
# This event reports sql statements that do not use bind variables
# thus fragmenting SGA.
# EXAMPLE OF STMNT without BIND variables
#    UPDATE table SET col=1, col2='x'
#    UPDATE table SET col=2, col2='z'
#
# EXAMPLE OF SAME STMNT with BIND variables
#    UPDATE table SET col=:bv1, col2=:bv2
#
#
# REPORT ATTRIBUTES:
# -----------------------------
# first 80 chars of sql stmnt (commas are stripped)
#
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  --------
# SQL_CNT         report sql statements that appear to be 
#                 same and are found <SQL_CNT> number of 
#                 times in v$sqlarea                      100
#                 DEFAULT=50
#
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        17-FEB-2003      (1.1) Created
#       VMOGILEV        14-SEP-2004      (1.2) converted to GLOBAL TMP TABLE
#					       to reduce REDO usage
#       VMOGILEV        21-COT-2013      (1.3) Added alter session set recyclebin=off;
#

chkfile=$1
outfile=$2
clrfile=$3

if [ ! "$PARAM__SQL_CNT" ]; then
        SQL_CNT=50
fi


## get trigger attributes
##
sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
alter session set recyclebin=off;

DROP TABLE sql_area_tmp;

WHENEVER SQLERROR EXIT FAILURE

CREATE OR REPLACE FUNCTION strip_const(
   p_query IN VARCHAR2)
RETURN VARCHAR2
AS 
   l_query long; 
   l_char varchar2(1); 
   l_in_quotes BOOLEAN default FALSE; 
BEGIN 
   FOR i IN 1 .. LENGTH(p_query) LOOP 
      l_char := substr(p_query,i,1); 
      
      IF ( l_char = '''' and l_in_quotes ) THEN 
         l_in_quotes := FALSE; 
      
      ELSIF ( l_char = '''' and NOT l_in_quotes ) THEN 
         l_in_quotes := TRUE; 
         l_query := l_query || '''#'; 
      END IF; 
      
      IF ( NOT l_in_quotes ) THEN 
         l_query := l_query || l_char; 
      END IF; 
   END LOOP; 
   
   l_query := TRANSLATE(l_query, '0123456789', '@@@@@@@@@@' ); 
   
   FOR i in 0 .. 8 LOOP 
      l_query := REPLACE(l_query, LPAD('@',10-i,'@'), '@' ); 
      l_query := REPLACE(l_query, LPAD(' ',10-i,' '), ' ' ); 
   END LOOP; 
   
   RETURN UPPER(l_query); 
END; 
/ 

CREATE GLOBAL TEMPORARY TABLE sql_area_tmp
on commit preserve rows
--CREATE TABLE sql_area_tmp
--STORAGE(
--   INITIAL 5M
--   NEXT 5M
--   PCTINCREASE 0
--)
AS 
SELECT
   sql_text
,  sql_text sql_text_wo_constants 
,  module
,  action
FROM v\$sqlarea 
WHERE 1=0 
/ 

ALTER TABLE sql_area_tmp
MODIFY (
   SQL_TEXT_WO_CONSTANTS VARCHAR2(2000)
)
/

INSERT INTO sql_area_tmp (sql_text,module,action) 
SELECT sql_text,module,action FROM v\$sqlarea 
/ 

COMMIT
/

UPDATE sql_area_tmp 
SET sql_text_wo_constants = strip_const(sql_text) 
/ 

COMMIT
/

set lines 2000
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $chkfile
SELECT DISTINCT
   REPLACE(SUBSTR(sql_text_wo_constants,1,80),CHR(44),' ')
FROM(
SELECT 
   sql_text_wo_constants
,  COUNT(*) cnt
FROM sql_area_tmp 
GROUP BY sql_text_wo_constants 
HAVING COUNT(*) > ${SQL_CNT})
ORDER BY 1
/
spool off


-- get output right here since it's a TEMPORARY TABLE
-- which is only active for this session
-- (see note# 68098.1)
--
spool $outfile
set pages 60
set lines 80
set trims on
set head on
set feed on

col sql_text_wo_constants format a80 word_wrapped heading "SQL needs rewrite to use bind variables"

SELECT
   sql_text_wo_constants
,  COUNT(*) cnt
FROM sql_area_tmp
GROUP BY sql_text_wo_constants
HAVING COUNT(*) > ${SQL_CNT}
ORDER BY 2 DESC
/

spool off

exit
CHK

## check for errors
##
if [ $? -gt 0 ]; then
        cat $chkfile.err
        rm $chkfile.err
        exit 1;
fi


## if I got here remove error chk file
##
rm $chkfile.err



