select que||' is delaying for '||lag||' minutes.'
from
(
select 't1gnrck' as que, round((sysdate-cast(max(CREATED_AT) as date))*1440) as lag
from SINGLES_OWNER.PAYMENTS a
where CREATED_AT > systimestamp-2
and userid=51639968
union
select 't2gnrck' as que, round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.EHPHOTOGRAPH e
where SHAREPLEX_SOURCE_TIME > systimestamp-2
and userid=51639968
union
select 't2gnrck1' as que,round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440)  as lag
from SINGLES_OWNER.EHNUDGEUSERHISTORY n
where SHAREPLEX_SOURCE_TIME > systimestamp-2
and userid=51639968
union
select 't3gnrck' as que,round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.EHTRANSACTION t
where SHAREPLEX_SOURCE_TIME > systimestamp-2
and userid=51639968
union
select 't2mtchs' as que,round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.EHMATCHES eh
where  SHAREPLEX_SOURCE_TIME > systimestamp-2
and CANDIDATEUSERID =51639968
union
/*
select 't4mtchs' as que, round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.EHMATCHES_RS ehr
where SHAREPLEX_SOURCE_TIME  > systimestamp-2
and CANDIDATEUSERID  =51639968
union
*/
select 't2prngsstats' as que, round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.EHPAIRINGSTATISTICS s
where SHAREPLEX_SOURCE_TIME > systimestamp-2
and USERID =51639968
union
select 't2mtchsum' as que, round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.MATCH_SUMMARIESI mi
where SHAREPLEX_SOURCE_TIME > systimestamp-2
and  USER_ID =51639968
union
select 't1trkgff' as que, round((sysdate-max(to_date(decode(length(asset_id), 9,'0'||asset_id,asset_id),'mmddhh24miss')))*1440) as lag
from SINGLES_OWNER.TRACKING_USER_AFFILIATE tuf
where to_date(decode(substr(decode(length(asset_id), 9,'0'||asset_id,asset_id),1,1),'1',null,'0')||ASSET_ID,'mmddhh24miss') > systimestamp-2
and USER_ID=51639968 and id=191750271
and CREATED_AT=to_timestamp('18-APR-13 11.00.26.770602 AM')
union
--VM select 't2msg' as que, round((sysdate-cast(max(MESSAGEDATESTAMP) as date))*1440) as lag
select 't2msg' as que, round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.EHMESSAGE_INC ms
--VM where  MESSAGEDATESTAMP > systimestamp-2
where  SHAREPLEX_SOURCE_TIME > systimestamp-2
and AUTHORUSERID =51639968
union
select 't2prngs' as que, round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.EHPAIRINGS
where SHAREPLEX_SOURCE_TIME > systimestamp-2
and MALEID = 51639968
union
select 't2gnrck2' as que, round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from singles_owner.EHUSERMHCS e
where SHAREPLEX_SOURCE_TIME > systimestamp-2
and userid=51639968
union
select 't2gnrck3' as que,round((sysdate-cast(max(SHAREPLEX_SOURCE_TIME) as date))*1440) as lag
from SINGLES_OWNER.EHCOMMUNICATION
where  SHAREPLEX_SOURCE_TIME > systimestamp-2
and matchid =5058961387
union
select 't1usrs' as que, round((sysdate-cast(max(userlastlogin) as date))*1440) as lag
from singles_owner.ehuser a
where  userid=51639968
)
where lag >=   (select
                   case
                      when ts between 2001 and 2330 then 80 
                      when ts between 100 and 2000 then 400 
                      else 20
                   end
                from (select to_number(to_char(sysdate,'HH24MI'),9999) ts from dual)
);

