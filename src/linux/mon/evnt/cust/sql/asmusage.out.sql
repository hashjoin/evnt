set lines 64
set trims on
set pages 90

ttit "ASM Diskgroup Usage"

select distinct name, total_mb, least(free_mb, usable_file_mb) free_mb,
       round(100 - (least(free_mb, usable_file_mb)*100/decode(total_mb,0,1,total_mb)),1) pct_used
  from gv$asm_diskgroup
  order by 4 desc;

set lines 132
select * from gv$asm_operation;
