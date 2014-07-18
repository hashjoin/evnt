INSERT INTO sqldir_groups VALUES ( -1, 'ALL', 'TOTAL Number Of Scripts:' );
INSERT INTO sqldir_groups VALUES ( sqldir_groups_S.NEXTVAL, UPPER('EVNT_MAINT'), 'Event Maintenance' );
INSERT INTO sqldir_groups VALUES ( sqldir_groups_S.NEXTVAL, UPPER('COLL_MAINT'), 'Collection Maintenance' );
INSERT INTO sqldir_groups VALUES ( sqldir_groups_S.NEXTVAL, UPPER('GLOB_MAINT'), 'Global Maintenance' );
-- START SCRIPT: ackevnt.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'ackevnt.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'ackevnt.sql' 
AND g.grp_name = UPPER('EVNT_MAINT'); 

-- END SCRIPT: ackevnt.sql
-- START SCRIPT: actcoll.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'actcoll.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'actcoll.sql' 
AND g.grp_name = UPPER('COLL_MAINT'); 

-- END SCRIPT: actcoll.sql
-- START SCRIPT: actevnt.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'actevnt.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'actevnt.sql' 
AND g.grp_name = UPPER('EVNT_MAINT'); 

-- END SCRIPT: actevnt.sql
-- START SCRIPT: addadmu.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'addadmu.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'addadmu.sql' 
AND g.grp_name = UPPER('GLOB_MAINT'); 

-- END SCRIPT: addadmu.sql
-- START SCRIPT: cldevnt.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'cldevnt.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'cldevnt.sql' 
AND g.grp_name = UPPER('EVNT_MAINT'); 

-- END SCRIPT: cldevnt.sql
-- START SCRIPT: cr8musra.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'cr8musra.sql'; 

-- END SCRIPT: cr8musra.sql
-- START SCRIPT: cr8musr.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'cr8musr.sql'; 

-- END SCRIPT: cr8musr.sql
-- START SCRIPT: eglance.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'eglance.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'eglance.sql' 
AND g.grp_name = UPPER('EVNT_MAINT'); 

-- END SCRIPT: eglance.sql
-- START SCRIPT: hstevnt.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'hstevnt.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'hstevnt.sql' 
AND g.grp_name = UPPER('EVNT_MAINT'); 

-- END SCRIPT: hstevnt.sql
-- START SCRIPT: outevnt.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'outevnt.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'outevnt.sql' 
AND g.grp_name = UPPER('EVNT_MAINT'); 

-- END SCRIPT: outevnt.sql
-- START SCRIPT: pndevnt.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'pndevnt.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'pndevnt.sql' 
AND g.grp_name = UPPER('EVNT_MAINT'); 

-- END SCRIPT: pndevnt.sql
-- START SCRIPT: sidcln.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'sidcln.sql'; 

-- END SCRIPT: sidcln.sql
-- START SCRIPT: u_prompt.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'u_prompt.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'u_prompt.sql' 
AND g.grp_name = UPPER('UTIL'); 

-- END SCRIPT: u_prompt.sql
-- START SCRIPT: x_banner.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'x_banner.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'x_banner.sql' 
AND g.grp_name = UPPER('DBATOOLZ'); 

-- END SCRIPT: x_banner.sql
-- START SCRIPT: x_dir.sql
INSERT INTO sqldir_mapping 
SELECT script_id, -1 
FROM sqldir_scripts 
WHERE script_name = 'x_dir.sql'; 

INSERT INTO sqldir_mapping 
SELECT s.script_id, g.grp_id 
FROM sqldir_scripts s 
,    sqldir_groups  g 
WHERE s.script_name = 'x_dir.sql' 
AND g.grp_name = UPPER('DBATOOLZ'); 

-- END SCRIPT: x_dir.sql
