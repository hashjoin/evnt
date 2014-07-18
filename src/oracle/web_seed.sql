-- $header web_seed.sql v1.0 2013-Oct-21 VMOGILEVSKIY 

CREATE TABLE web_menus(
   wm_code VARCHAR2(5) NOT NULL,
   wm_sort NUMBER(3) NOT NULL,
   wm_name VARCHAR2(50) NOT NULL,
   wm_url  VARCHAR2(256) NOT NULL,
   wm_desc VARCHAR2(256))
/
ALTER TABLE web_menus
 ADD (CONSTRAINT wm_UK UNIQUE 
  (wm_code))
/

CREATE TABLE web_sub_menus(
   wsm_code VARCHAR2(5) NOT NULL,
   wsm_sort  NUMBER(3) NOT NULL,
   wm_code VARCHAR2(5) NOT NULL,
   wsm_url  VARCHAR2(256) NOT NULL,
   wsm_name VARCHAR2(100) NOT NULL,
   wsm_desc VARCHAR2(512))
/
ALTER TABLE web_sub_menus
 ADD (CONSTRAINT wsm_UK UNIQUE 
  (wsm_code))
/
CREATE INDEX web_sub_menus_01
ON web_sub_menus(wm_code)
/
ALTER TABLE web_sub_menus ADD (CONSTRAINT
 wsm_wm_FK FOREIGN KEY 
  (wm_code) REFERENCES web_menus
  (wm_code))
/


INSERT INTO web_menus VALUES ('MAIN',1,'Event Module','web_nav_pkg.evnt','Event System Applications');
INSERT INTO web_menus VALUES ('COLL',2,'Collection Module','web_nav_pkg.coll','Collection System Applications');
INSERT INTO web_menus VALUES ('GLOB',3,'Admin Module','web_nav_pkg.glob','Global System Administration');

INSERT INTO web_sub_menus VALUES ('MCA' ,1,'COLL','coll_web_pkg.ca_form','Assigments','Add/Modify collection assignments by target (CONTROL PANEL)');
INSERT INTO web_sub_menus VALUES ('VCH' ,2,'COLL','coll_web_pkg.history','History','Collection snapshot history');
INSERT INTO web_sub_menus VALUES ('RPTC',3,'COLL','glob_web_pkg.rpt?p_r_type=C','Reports','Collection based reports');

INSERT INTO web_sub_menus VALUES ('DTGP',1 ,'MAIN','evnt_web_pkg.disp_triggers?p_phase=P','Pending Events','Pending event triggers');
INSERT INTO web_sub_menus VALUES ('DTT' ,2 ,'MAIN','evnt_web_pkg.today','Today''s Events','Event triggers that were generated today');
INSERT INTO web_sub_menus VALUES ('TAW' ,3 ,'MAIN','evnt_web_pkg.history','Weekly Trends','Weekly trend analysis by event/day');
INSERT INTO web_sub_menus VALUES ('MEA' ,4 ,'MAIN','evnt_web_pkg.ea_form','Assigments','Add/Modify event assignments by target (CONTROL PANEL)');
INSERT INTO web_sub_menus VALUES ('MET' ,5 ,'MAIN','evnt_web_pkg.ep_form','Thresholds','Add/Modify events and event thresholds');
INSERT INTO web_sub_menus VALUES ('ELP' ,6 ,'MAIN','evnt_web_pkg.get_trigger','Trigger Lookup','Lookup event trigger by trigger id');
INSERT INTO web_sub_menus VALUES ('MTAC',7 ,'MAIN','coll_web_pkg.trend_analyzer','Monthly Trends','Monthly trend analysis of cleared events (purged events are reported)');
INSERT INTO web_sub_menus VALUES ('DTAP',8 ,'MAIN','evnt_web_pkg.disp_triggers?p_ack_flag=P','Pending Ack','Pending event triggers that require acknowledgment');
INSERT INTO web_sub_menus VALUES ('DTAC',9 ,'MAIN','evnt_web_pkg.disp_triggers?p_ack_flag=C','Closed Ack','Pending/Closed event triggers that have been acknowledged');
INSERT INTO web_sub_menus VALUES ('RPTE',10,'MAIN','glob_web_pkg.rpt?p_r_type=E','Reports (Repository)','Run repository based reports');
INSERT INTO web_sub_menus VALUES ('RPTR',11,'MAIN','glob_web_pkg.rpt?p_r_type=R','Reports (DB Links)','Run target (remote) based reports via DB links');

INSERT INTO web_sub_menus VALUES ('MPG' ,1,'GLOB','glob_web_pkg.page_lists','Notifications','Add/Modify page lists, admins, admin emails/pagers, admin backups');
INSERT INTO web_sub_menus VALUES ('MSB' ,2,'GLOB','glob_web_pkg.blackouts','Blackouts','Add/Modify event system blackouts');
INSERT INTO web_sub_menus VALUES ('RPTA',3,'GLOB','glob_web_pkg.rpt','All Reports','Run all reports');

commit;

CREATE TABLE web_attributes (
   wb_code VARCHAR2(5) NOT NULL,
   wb_val  VARCHAR2(512) NOT NULL,
   wb_desc VARCHAR2(256) NULL)
/
CREATE UNIQUE INDEX web_attributes_u01
ON web_attributes(wb_code)
/

@@restore_ui_proc.sql

BEGIN
   restore_ui;
END;
/

COMMIT;
