#!/bin/ksh
#
# File:
#       tabsppct.sh
# EVNT_REG:	TABSP_USAGE SEEDMON 1.5
# <EVNT_NAME>Tablespace Usage</EVNT_NAME>
#
# Author:
#       Vitaliy Mogilevskiy (hashjoin.com)
#
# Usage:
# <EVNT_DESC>
# Reports tablespace usage
# 
# REPORT ATTRIBUTES:
# -----------------------------
# tablespace_name
# pct_used [based on max unallocated possible size vs currently used]
# mbytes_alloc
# mbytes_free
# max_size [max possible unallocated]
# 
# PARAMETER       DESCRIPTION                             EXAMPLE
# --------------  --------------------------------------  -----------------------
# PCT_USED_TRES   used percent ratio                      90
# EXCLUDE_LIST    dba_data_files.tablespace_name          'AR', 'ARINDX', 'ASOD'
#                                                         (can be NULL)
# </EVNT_DESC>
#
#
# History:
#       VMOGILEV        06/06/2002      1.0 Created
#       VMOGILEV        02/20/2003	1.1 added total_kbytes free_kbytes
#       VMOGILEV        03/28/2003	1.2 added NVL on kbytes_free
#       VMOGILEV        10/22/2013	1.3 switched to unallocated for pct% checks
#       VMOGILEV        11/04/2013	1.4 added drilldowns to find fast extending segments
#       VMOGILEV        11/22/2013	1.5 excluded UNDOTBS% and adjusted diff check to filter out subset
#


chkfile=$1
outfile=$2
clrfile=$3
prevfile=$4

if [ ! "$PARAM__EXCLUDE_LIST" ]; then
	PARAM__EXCLUDE_LIST="'x'"
fi

sqlplus -s $MON__CONNECT_STRING <<CHK >$chkfile.err
WHENEVER SQLERROR EXIT FAILURE
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $chkfile
select nvl(c.tablespace_name,nvl(a.tablespace_name,'UNKNOWN'))
||','||ROUND(((mbytes_alloc-nvl(mbytes_free,0))/c.max_size)*100,1)
||','||ROUND(mbytes_alloc,0)
||','||ROUND(NVL(mbytes_free,0),0)
||','||ROUND(c.max_size,0)
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
                    ,       sys.ts\$         tn
                    ,       sys.filext\$     fex
                    ,       sys.file\$       ft
                    where   ddf.file_id = ft.file#
                    and     ddf.file_id = fex.file#(+)
                    and     tn.ts# = ft.ts#
                )
            group by tabsp_name ) c
where   a.tablespace_name(+) = c.tablespace_name
and     ROUND(((mbytes_alloc-nvl(mbytes_free,0))/c.max_size)*100,2) > $PARAM__PCT_USED_TRES
and     c.tablespace_name NOT IN ($PARAM__EXCLUDE_LIST)
and     c.tablespace_name NOT LIKE 'UNDOTBS%'
order by c.tablespace_name;
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


sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
spool $outfile
@$EVNT_TOP/seed/sql/s_tabsp.sql
spool off
exit
CHK

## check for errors
##
if [ $? -gt 0 ]; then
        cat $outfile.err
        rm $outfile.err
        exit 1;
fi

## if I got here remove error chk file
##
rm $outfile.err


drildown() {
# get drilldown for fast extending segments in these tablespaces
#
$SEEDMON/drilspace.sh $chkfile $outfile.tmp.drilspace
if [ $? -gt 0 ]; then
        cat $outfile.tmp.drilspace >> $outfile
        exit 1;
fi
cat $outfile.tmp.drilspace >> $outfile
rm -f $outfile.tmp.drilspace
}


## only drill down when we have a trigger and it's different from previous
## and it has new values not just a subset of old values
## this is done because drill down will exec dbms_workload_repository.create_snapshot
##
##     oracle@mondb1~ diff o n | grep ">"
##     > 5
##     oracle@mondb1~
##     oracle@mondb1~
##     oracle@mondb1~
##     oracle@mondb1~
##     oracle@mondb1~ cat o
##     1
##     2
##     3
##     oracle@mondb1~ cat n
##     2
##     5
##     oracle@mondb1~
##
if [ `cat $chkfile | wc -l` -gt 0 ]; then
        ##if [ `diff $prevfile $chkfile | wc -l` -gt 0 ]; then
	if [ `diff $prevfile $chkfile | grep ">" | wc -l` -gt 0 ]; then
		##VM: 6-2-2014
		## per Nav shut it down -- we experienced heavy waits on [ row cache lock ]
		##  drildown;
		echo "drill is removed"
        fi
fi



if [ ! "$clrfile" ]; then
	exit 0;
fi

sqlplus -s $MON__CONNECT_STRING <<CHK >$outfile.err
WHENEVER SQLERROR EXIT FAILURE
set verify off
set pages 0
set trims on
set head off
set feed off
set echo off
spool $clrfile
select nvl(c.tablespace_name,nvl(a.tablespace_name,'UNKNOWN'))
||','||ROUND(((mbytes_alloc-nvl(mbytes_free,0))/c.max_size)*100,1)
||','||ROUND(mbytes_alloc,0)
||','||ROUND(NVL(mbytes_free,0),0)
||','||ROUND(c.max_size,0)
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
                    ,       sys.ts\$         tn
                    ,       sys.filext\$     fex
                    ,       sys.file\$       ft
                    where   ddf.file_id = ft.file#
                    and     ddf.file_id = fex.file#(+)
                    and     tn.ts# = ft.ts#
                )
            group by tabsp_name ) c
where   a.tablespace_name(+) = c.tablespace_name
order by c.tablespace_name;
spool off
exit
CHK

## check for errors
##
if [ $? -gt 0 ]; then
        cat $outfile.err
        rm $outfile.err
        exit 1;
fi

## if I got here remove error chk file
##
rm $outfile.err

