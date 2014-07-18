-- $header tabsp.sql v1.0 2013-Oct-22 VMOGILEVSKIY

set pages 60
set lines 132
set trims on
set tab off

column  pct_used        format 999.9            heading "%|Used"
column  pct_max_used    format 999.9            heading "%|Used"
column  ts_name         format a35              heading "Tablespace Name"
column  Mbytes          format 999,999,999  heading "MBytes"
column  used            format 999,999,999  heading "Used MB"
column  free            format 999,999,999  heading "Free MB"
column  largest         format 999,999,999  heading "Largest"
column  cur_size        format 999,999,999  heading "Curr MB"
column  max_size        format 999,999,999  heading "Max MB"
column  unallocated     format 999,999,999  heading "Unalloc MB"
break   on report
compute sum of mbytes on report
compute sum of free on report
compute sum of used on report


select  nvl(c.tablespace_name,nvl(a.tablespace_name,'UNKNOWN')) ts_name
,       mbytes_alloc                                            mbytes
,       mbytes_alloc-nvl(mbytes_free,0)                         used
,       nvl(mbytes_free,0)                                      free
,       ((mbytes_alloc-nvl(mbytes_free,0))/mbytes_alloc)*100    pct_used
--,     nvl(largest,0)                                          largest
,       c.max_size    max_size
,       c.unallocated unallocated
,       ((mbytes_alloc-nvl(mbytes_free,0))/c.max_size)*100      pct_max_used
from    (select sum(bytes)/1024/1024            Mbytes_free
        ,               max(bytes)/1024/1024    largest
        ,               tablespace_name
        from            dba_free_space
        group by        tablespace_name)                        a
,       (   select tabsp_name tablespace_name, sum(cur_size)/1024/1024 mbytes_alloc, sum(max_size)/1024/1024 max_size, sum(unallocated)/1024/1024 unallocated
            from (
                    select  /*+ ORDERED */
                            tn.name                tabsp_name
                    ,       ddf.file_name          file_name
                    ,       ddf.bytes              cur_size
                    ,       decode(fex.maxextend,
                                    NULL,ddf.bytes
                                        ,fex.maxextend*tn.blocksize) max_size
                    ,       ((nvl(fex.maxextend,0)*tn.blocksize) -
                            decode(fex.maxextend,NULL,0,ddf.bytes))   unallocated
                    ,       nvl(fex.inc,0)*tn.blocksize               inc_by
                    from    dba_data_files  ddf
                    ,       sys.ts$         tn
                    ,       sys.filext$     fex
                    ,       sys.file$       ft
                    where   ddf.file_id = ft.file#
                    and     ddf.file_id = fex.file#(+)
                    and     tn.ts# = ft.ts#
                )
            group by tabsp_name ) c
where   a.tablespace_name(+) = c.tablespace_name
order by pct_max_used;

