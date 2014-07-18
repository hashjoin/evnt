read EVNT_TNS?"Enter EVNT TNS Alias: "

TWO_TASK=$EVNT_TNS
export TWO_TASK

cd $SYS_TOP/bin; dirlist.sh
sqlplus evnt @sqldir_ddl.sql

