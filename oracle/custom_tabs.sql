-- $header custom_tabs.sql v1.7 2013-Oct-21 VMOGILEVSKIY

CREATE GLOBAL TEMPORARY TABLE EVNT_UTIL_PKG_OUT (
  EUPO_ID        NUMBER (38)   NOT NULL,
  EUPO_DATE      DATE          NOT NULL,
  EUPO_REF_ID    NUMBER (38)   NOT NULL,
  EUPO_REF_TYPE  VARCHAR2 (50)  NOT NULL,
  EUPO_OUT       VARCHAR2 (4000))
ON COMMIT PRESERVE ROWS;

CREATE UNIQUE INDEX EVNT_UTIL_PKG_OUT_U01 ON
   EVNT_UTIL_PKG_OUT ( EUPO_ID ) ;

CREATE GLOBAL TEMPORARY TABLE GLOB_PEND_ASSIGNMENTS (
  GPA_SEQ   NUMBER (38)   NOT NULL,
  GPA_VAL   NUMBER (38)   NOT NULL)
ON COMMIT PRESERVE ROWS;

create table purge_et_id_tmp(
  et_id number(15) not null
, constraint peit_pk primary key(et_id)
)
organization index;


create table event_triggers_sum
(
    ea_id           NUMBER(15) not NULL
,   scnt            NUMBER(15) not NULL
,   et_phase_status VARCHAR2(1 CHAR) not NULL
);
