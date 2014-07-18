/*

   Clones ALL event assigments from one SID 
   to another

*/


VARIABLE sid_copy_from       VARCHAR2(100);
VARIABLE host_copy_to        VARCHAR2(100);
VARIABLE sid_copy_to         VARCHAR2(100);
VARIABLE sc_username_copy_to VARCHAR2(100);
VARIABLE pl_code_copy_to     VARCHAR2(100);

BEGIN
   :sid_copy_from       := '&1';
   :host_copy_to        := '&2';
   :sid_copy_to         := '&3';
   :sc_username_copy_to := '&4';
   :pl_code_copy_to     := '&5';
END;
/


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
,  s.h_id
,  s.s_id
,  sc.sc_id
,  pl.pl_id
,  SYSDATE
,  NULL
,  NULL
,  'CLONE'
,  ea_min_interval
,  ea_status
,  ea_start_time
,  NULL
,  NULL
,  NULL
,  EA_PURGE_FREQ
FROM event_assigments ea
,    hosts h
,    sids s
,    sids sf
,    sid_credentials sc
,    page_lists pl
--WHERE sf.s_name = UPPER(:sid_copy_from)
WHERE sf.s_name = :sid_copy_from
AND   sf.s_id = ea.s_id
AND   h.h_name = :host_copy_to
AND   h.h_id = s.h_id
--AND   s.s_name = UPPER(:sid_copy_to)
AND   s.s_name = :sid_copy_to
AND   s.s_id = sc.s_id
AND   UPPER(sc.sc_username) = UPPER(:sc_username_copy_to)
AND   pl.pl_code = UPPER(:pl_code_copy_to)
AND   (e_id, ep_id, s.h_id, s.s_id) NOT IN (select e_id, ep_id, h_id, s_id
                                            from event_assigments
                                            where h_id = s.h_id
                                            and s_id = s.s_id)
/

