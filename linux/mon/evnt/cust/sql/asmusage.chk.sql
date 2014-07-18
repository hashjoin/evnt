select distinct name
||','||round(100 - (least(free_mb, usable_file_mb)*100/decode(total_mb,0,1,total_mb)),0)
from gv$asm_diskgroup
where round(100 - (least(free_mb, usable_file_mb)*100/decode(total_mb,0,1,total_mb)),0) > &&1
order by 1;
