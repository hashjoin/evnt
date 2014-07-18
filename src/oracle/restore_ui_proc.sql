CREATE OR REPLACE PROCEDURE restore_ui IS
-- =====================================================================
--      Copyright (c) 2009 HASHJOIN Corporation All rights reserved.
-- =====================================================================
-- PROGRAM NAME  : restore_ui
-- AUTHOR        : vmogilev (www.dbatoolz.com)
-- SOURCE NAME   : restore_ui_proc.sql
-- DATE CREATED  : 11/01/2002
-- APPLICATION   : GLOBAL WEB UTIL
-- VERSION       : 3.5.4
-- DESCRIPTION   : Restores UI attributes back to default
-- EXAMPLE       :
-- =====================================================================
-- MODIFICATION HISTORY
-- =====================================================================
-- DATE      NAME          DESCRIPTION
-- ---------------------------------------------------------------------
-- 11/01/02  vmogilev    3.5.1 created
-- 05/12/03  vmogilev    3.5.2 changed styles
-- 05/13/03  vmogilev    3.5.3 fixed ACTIVE/INACTIVE assignments colors
-- 07/21/03  vmogilev    3.5.4 added active link over style
--
   PROCEDURE save(
      p_code IN VARCHAR2
   ,  p_val  IN VARCHAR2
   ,  p_desc IN VARCHAR2)
   IS
   BEGIN
      INSERT INTO web_attributes VALUES (p_code,p_val,p_desc);
   END save;
BEGIN
   EXECUTE IMMEDIATE 'TRUNCATE table web_attributes';
   
   --save('THC','#CCCCCC','Table Header Color');
   save('THC','#00659C','Table Header Color');
   --save('TRC','#E0E0D0','Table Row Color');
   save('TRC','#DEDEDE','Table Row Color');
   save('TRSC','#FFFFCC','Table SubRow Color');
   --save('PHCM','#020744','Page Header Main Color');
   save('PHCM','#003063','Page Header Main Color');
   --save('PHCS','#CCCCCC','Page Header Sub Color');
   save('PHCS','#B7B7B7','Page Header Sub Color');
   
   --save('PHMA','#E0E0D0','Page Header Menu Color ACTIVE');
   save('PHMA','#CECFCE','Page Header Menu Color ACTIVE');
   
   save('TRC_P','#FF0000','Trigger Row Color PENDING STATUS');
   save('TRC_C','#66CC00','Trigger Row Color CLEARED STATUS');
   save('TRC_O','#FFFF00','Trigger Row Color OLD STATUS');
   
   --save('ARC_A','#E0E0D0','Assigment Row Color ACTIVE');
   save('ARC_A','#DEDEDE','Assigment Row Color ACTIVE');
   
   --save('ARC_I','#CCCCCC','Assigment Row Color INACTIVE');
   save('ARC_I','#B7B7B7','Assigment Row Color INACTIVE');
   
   save('ARC_B','#FF0000','Assigment Row Color BROKEN');
   save('ARC_R','#66FFFF','Assigment Row Color RUNNING');
   
   save('BRC_A','#66FFFF','Blackout Row Color ACTIVE');
   
   save('LRC_A','#66FFFF','Page List Email Row Color ACTIVE');
   save('LRC_I','#CCCCCC','Page List Email Row Color INACTIVE');
/*   
   save('STL1','.HLSml { COLOR: black;font-weight: bold;FONT-FAMILY: Arial, Helvetica;FONT-SIZE: 9pt;TEXT-DECORATION: none }','Header Link Small');
   save('STL2','.HLMed { COLOR: black;font-weight: bold;FONT-FAMILY: Arial, Helvetica;FONT-SIZE: 10pt;TEXT-DECORATION: none }','Header Link Medium');
   save('STL3','.HTSml { COLOR: black;FONT-FAMILY: Arial, Helvetica;FONT-SIZE: 8pt;TEXT-DECORATION: none }','Header Text Small');
   
   save('STL4','.THT { COLOR: black;FONT-FAMILY: Verdana, Helvetica;FONT-SIZE: 8pt }','Table Header Text');
   save('STL5','.TRT { COLOR: black;FONT-FAMILY: Verdana, Helvetica;FONT-SIZE: 8pt }','Table Row Text');
   save('STL6','.TRL { FONT-FAMILY: Verdana, Helvetica;FONT-SIZE: 8pt }','Text Row Link');
*/
   save('STL1','.HLSml { COLOR: black;font-weight: bold;FONT-FAMILY: Arial, Helvetica;FONT-SIZE: 12px;TEXT-DECORATION: none }','Header Link Small');
   save('STL2','.HLMed { COLOR: black;font-weight: bold;FONT-FAMILY: Arial, Helvetica;FONT-SIZE: 14px;TEXT-DECORATION: none }','Header Link Medium');
   save('STL3','.HTSml { COLOR: black;FONT-FAMILY: Arial, Helvetica;FONT-SIZE: 12px;TEXT-DECORATION: none }','Header Text Small');
   
   --save('STL4','.THT { COLOR: black;FONT-FAMILY: Verdana, Helvetica;FONT-SIZE: 12px }','Table Header Text');
   save('STL4','.THT { COLOR: white;FONT-FAMILY: Verdana, Helvetica;FONT-SIZE: 12px }','Table Header Text');
   save('STL5','.TRT { COLOR: black;FONT-FAMILY: Verdana, Helvetica;FONT-SIZE: 12px }','Table Row Text');
   save('STL6','.TRL { FONT-FAMILY: Verdana, Helvetica;FONT-SIZE: 12px }','Text Row Link');
   
   save('STL7','a:hover {  color: #FF0033; border: #0000FF none; background-color: #FFFF00}','Active Link Over');

END restore_ui;
/
show errors
