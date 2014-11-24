/*

$Id$

    1 = host copy from
    2 = host copy to
    3 = sid copy to

EXAMPLE:

    -- clone all assigments from prodmisc cluster to ltmoradb cluster
    -- if an assignment is to a host only (no sid) then clone it to ltmoradb*.qa.dc1 host
    --
    @evnt_clnsid.sql prodmiscdb1.dc1 ltmoradb1.qa.dc1 LTMORA1
    @evnt_clnsid.sql prodmiscdb2.dc1 ltmoradb2.qa.dc1 LTMORA2
    @evnt_clnsid.sql prodmiscdbscan.dc1 ltmoradbscan.qa.dc1 LTMORA

*/

INSERT INTO event_assigments(
   ea_id
,  e_id
,  ep_id
,  h_id
,  s_id
,  sc_id
,  pl_id
,  date_created
,  date_modified
,  modified_by
,  created_by
,  ea_min_interval
,  ea_status
,  ea_start_time
,  ea_started_time
,  ea_finished_time
,  ea_last_runtime_sec
,  EA_PURGE_FREQ)
SELECT
   event_assigments_s.NEXTVAL
,  e_id
,  ep_id
,  h.h_id
,  decode(ea.s_id,null,null,s.s_id)
,  decode(ea.sc_id,null,null,sc.sc_id)
,  pl_id
,  SYSDATE
,  NULL
,  NULL
,  'CLONE'
,  ea_min_interval
,  decode(ea_status,'I','I','A')
,  ea_start_time
,  NULL
,  NULL
,  NULL
,  EA_PURGE_FREQ
FROM event_assigments ea
,    hosts h
,    sids s
,    sid_credentials sc
WHERE ea.h_id = (select h_id from hosts where h_name = '&&1')
AND   h.h_name = '&&2'
AND   h.h_id = s.h_id
AND   s.s_name = '&&3'
AND   s.s_id = sc.s_id
AND   UPPER(sc.sc_username) = 'MON'
AND   (e_id, ep_id, s.h_id) NOT IN (select e_id, ep_id, h_id
                                            from event_assigments
                                            where h_id = s.h_id
                                            and s_id = s.s_id);

