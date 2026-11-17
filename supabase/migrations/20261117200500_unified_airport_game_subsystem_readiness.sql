-- Airport subsystem game-readiness report independent of future licence/flight release.
-- This report does not authorize a commercial flight or misrepresent real-world evidence.
create or replace view airlinerra_game.airport_unified_game_readiness_v1
with (security_invoker=true) as
select c.world_id,c.airport_key,c.source_group,c.airport_name,
 c.game_data_status,
 (c.game_runway_length_m>0 and c.timezone_iana is not null
    and c.latitude_deg is not null and c.longitude_deg is not null
    and c.game_lookup_code is not null) as identity_and_runway_model_ready,
 (s.airport_key is not null) as section6_slot_capacity_ready,
 (p.airport_key is not null) as section5_operating_policy_ready,
 (n.airport_key is not null) as section5_simplified_restriction_ready,
 (c.source_group='GROUP_1'
   or coalesce(g.simulation_candidate_only,false)) as game_airport_candidate,
 (c.source_group='GROUP_1'
   or coalesce(g.documented_commercial_prohibition,false)) as historical_approval_or_prohibition_flag,
 (c.game_runway_length_m>0 and c.timezone_iana is not null
   and c.latitude_deg is not null and c.longitude_deg is not null
   and c.game_lookup_code is not null and s.airport_key is not null
   and p.airport_key is not null and n.airport_key is not null
   and (c.source_group='GROUP_1' or coalesce(g.simulation_candidate_only,false)))
  as airport_game_subsystem_ready,
 c.dispatch_eligible_by_airport_admission as flight_admission_released,
 c.admission_status as real_world_evidence_or_admission_status,
 'GAME_MODEL_READY_DOES_NOT_MEAN_FLIGHT_AUTHORIZED'::text as distinction
from airlinerra_game.airport_unified_operations_v1 c
left join airlinerra_game.section6_airport_slot_capacity_v1 s using(world_id,airport_key)
left join airlinerra_game.section5_airport_operating_policy_v1 p using(world_id,airport_key)
left join airlinerra_game.section5_airport_simplified_game_rules_v1 n using(world_id,airport_key)
left join airlinerra_game.airport_group2_simulation_admission_candidates_v1 g using(world_id,airport_key);
revoke all on airlinerra_game.airport_unified_game_readiness_v1 from public,anon,authenticated;
comment on view airlinerra_game.airport_unified_game_readiness_v1 is
 'Unified airport GAME-model readiness reporting. 1116 simulation candidates may be ready for game airport planning while flight admission remains separately blocked. Two documented prohibitions are excluded.';