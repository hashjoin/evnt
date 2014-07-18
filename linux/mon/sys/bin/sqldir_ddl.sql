spool sqldir_ddl.log 
set echo on 
set term off 
drop sequence sqldir_groups_S;
create sequence sqldir_groups_S;
drop table sqldir_groups;
create table sqldir_groups(
   grp_id number not null,
   grp_name varchar2(25) not null,
   grp_desc varchar2(150));
drop sequence sqldir_scripts_S;
create sequence sqldir_scripts_S;
drop table sqldir_scripts;
create table sqldir_scripts(
   script_id number not null,
   script_name varchar2(150) not null,
   script_desc varchar2(2000) );
drop table sqldir_mapping;
create table sqldir_mapping(
   script_id number not null,
   grp_id number not null);
create unique index sqldir_mapping_u01
on sqldir_mapping(script_id,grp_id);
@sqldir_txt.sql 
@sqldir_grp.sql 
spool off 
exit; 
