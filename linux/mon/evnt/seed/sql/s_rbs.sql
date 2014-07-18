REM
REM DBAToolZ NOTE:
REM	This script was obtained from DBAToolZ.com
REM	It's configured to work with SQL Directory (SQLDIR).
REM	SQLDIR is a utility that allows easy organization and
REM	execution of SQL*Plus scripts using user-friendly menu.
REM	Visit DBAToolZ.com for more details and free SQL scripts.
REM
REM 
REM File:
REM 	s_rbs.sql
REM
REM <SQLDIR_GRP>RBS</SQLDIR_GRP>
REM 
REM Author:
REM 	Vitaliy Mogilevskiy 
REM	VMOGILEV
REM	(vit100gain@earthlink.net)
REM 
REM Purpose:
REM	<SQLDIR_TXT>
REM	Reports RBS statistics
REM	</SQLDIR_TXT>
REM	
REM Usage:
REM	s_rbs.sql
REM 
REM Example:
REM	s_rbs.sql
REM
REM
REM History:
REM	08-01-1998	VMOGILEV	Created
REM
REM

clear breaks
clear col
col name              format a15     heading "Rbs|Name"
col cur_size          format 9999.99 heading "Cur|Size Mb"
col opt_size          format 9999.99 heading "Opt|Size Mb"
col segment_name      format a15     heading "Rbs|Name"
col owner             format a7      heading "Owner"   
col tablespace_name   format a7      heading "TabSP"   
col initial_extent    format 99999999 heading "Init|Ext Kb"
col next_extent       format 99999999 heading "Next|Ext Kb"
col min_extents       format 9999    heading "Min Ext" 
col max_extents       format 9999999 heading "Max Ext" 
col pct_increase      format 9999.99 heading "%|Inc"   
col status            format a8      heading "Status"  
set lines 132
set feedback on
set term on
set pages 100
set head on
ttitle off


prompt +--------------------------+
prompt | Initial settings summary |
prompt +--------------------------+

select segment_name 
,owner              
,tablespace_name    
,initial_extent/1024  initial_extent     
,next_extent/1024     next_extent        
,min_extents        
,max_extents
,pct_increase       
,status             
from dba_rollback_segs
/

prompt
prompt
prompt +-----------------------+
prompt | Current state summary |
prompt +-----------------------+

select vrn.name                    name
,vrs.extents
,round(vrs.rssize/1024/1024,2)     cur_size
,round(vrs.optsize/1024/1024,2)    opt_size
,vrs.writes
,vrs.gets
,vrs.waits
,vrs.shrinks
,vrs.wraps
,vrs.status
from v$rollname vrn
,v$rollstat vrs
where vrs.usn = vrn.usn
/


rem select a.usn, b.name, a.gets, a.waits
rem from v$rollstat a
rem ,    v$rollname b
rem where a.usn=b.usn
rem /


prompt
prompt
prompt +--------+
prompt | Ratios |
prompt +--------+
prompt
prompt +---------------------------------------------------------------------+
prompt Ratio of Any Undo Waits To total number
prompt of requests should be < 1% (for each %undo% type)
prompt if not add more RBS
prompt +---------------------------------------------------------------------+

col     class   format a25              heading "Wait Class|(v$waitstat)"
col     count   format 999999999999     heading "Count Of Waits|For This Class"
col     w_to_r  format 999999999.99     heading "Waits To|Requests|Ratio"
col     tot_r   format 999999999999     heading "Total Requests|(v$sysstat)"

select   w.class
,        w.count
,        w.count * 100 / s.sum_val   w_to_r
,        s.sum_val                   tot_r
from     v$waitstat                         w
,        (select sum(value) sum_val
          from   v$sysstat
          where  name  = 'consistent gets') s
where    w.class like '%undo%'
/

prompt
prompt +---------------------------------------------------------------------+
prompt RBS Header Contention "Ratio" value should be < 5%, IF NOT add more RBS
prompt +---------------------------------------------------------------------+

select sum(waits) * 100 / sum(gets) "Ratio"
,      sum(waits)                   "Waits"
,      sum(gets)                    "Gets"
from   v$rollstat
/

prompt
prompt +---------------------------------------------------------------------+
prompt Here are all current waits for ROLLBACK segments
prompt IT's good when query does not return any rows
prompt selecting from v$system_event
prompt +---------------------------------------------------------------------+

set lines 80
desc v$system_event



select  *   from  v$system_event
where   event = 'undo segment tx slot'
/


