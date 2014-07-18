LOAD DATA
REPLACE
INTO TABLE UTIL_TARGET_INT TRUNCATE
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
 (
      UTI_HOST                           char (50)
,     UTI_HOST_DESC                      char (512)
,     UTI_SID                            char (50)
,     UTI_SID_DESC                       char (512)
,     UTI_SC_USERNAME                    char (50)
,     UTI_SC_PASSWORD                    char (50)
,     UTI_SC_TNS_ALIAS                   char (50)
)

