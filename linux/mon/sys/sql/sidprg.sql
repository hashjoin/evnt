-- fast hack to purge SID's event assigments
-- note that SID is not purged nor collection assigments

create or replace procedure prg_ass(p_ea_id in number default null)
is
begin
      delete_commit('DELETE event_trigger_notif '||
                    'WHERE et_id IN (SELECT et_id '||
                                    'FROM event_triggers '||
                                    'WHERE ea_id = '||p_ea_id||')');

      delete_commit('DELETE event_trigger_notes '||
                    'WHERE et_id IN (SELECT et_id '||
                                    'FROM event_triggers '||
                                    'WHERE ea_id = '||p_ea_id||')');

      delete_commit('DELETE event_trigger_output '||
                    'WHERE et_id IN (SELECT et_id '||
                                    'FROM event_triggers '||
                                    'WHERE ea_id = '||p_ea_id||')');

      delete_commit('DELETE event_trigger_details '||
                    'WHERE et_id IN (SELECT et_id '||
                                    'FROM event_triggers '||
                                    'WHERE ea_id = '||p_ea_id||')');

      delete_commit('DELETE event_triggers '||
                    'WHERE ea_id = '||p_ea_id);


      delete_commit('DELETE event_holds '||
                    'WHERE  eh_set_by_type = ''E'' '||
                    'AND    eh_set_by_id = '||p_ea_id);

end;
/

begin
   for x in (
      select ea_id from event_assigments
      where s_id is not null
      and s_id = (select s_id from sids where s_name = 'XTST')
      )
   loop
      prg_ass(x.ea_id);

         evnt_api_pkg.ea(
            p_ea_id             => x.ea_id
         ,  p_e_id              => NULL
         ,  p_e_code            => NULL
         ,  p_ep_id             => NULL
         ,  p_ep_code           => NULL
         ,  p_h_id              => NULL
         ,  p_h_name            => NULL
         ,  p_s_id              => NULL
         ,  p_s_name            => NULL
         ,  p_sc_id             => NULL
         ,  p_sc_username       => NULL
         ,  p_pl_id             => NULL
         ,  p_pl_code           => NULL
         ,  p_date_modified     => NULL
         ,  p_modified_by       => NULL
         ,  p_created_by        => NULL
         ,  p_ea_min_interval   => NULL
         ,  p_ea_status         => NULL
         ,  p_ea_start_time     => NULL
         ,  p_ea_purge_freq     => NULL
         ,  p_operation         => 'D');

   end loop;
end;
/

commit;


