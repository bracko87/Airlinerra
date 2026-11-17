-- Simulation-only classification for Group 2.
-- Never treats missing real-world evidence as verified, and never grants flight rights.
create or replace view airlinerra_game.airport_group2_simulation_admission_candidates_v1
with (security_invoker=true) as
select c.world_id,c.airport_key,c.airport_name,c.game_category,
  g.game_traffic_type,
  r.readiness_status as real_world_evidence_status,
  coalesce(r.documented_commercial_prohibition,false) as documented_commercial_prohibition,
  (c.game_runway_length_m>0 and c.game_terminal_slot_per_10m is not null
    and c.game_remote_slot_per_10m is not null and c.game_cargo_slot_per_10m is not null
    and c.game_nighttime_ban is not null and c.game_noise_restrictions is not null)
    as game_model_inputs_complete,
  (not coalesce(r.documented_commercial_prohibition,false)
    and c.game_runway_length_m>0
    and c.game_terminal_slot_per_10m is not null
    and c.game_remote_slot_per_10m is not null
    and c.game_cargo_slot_per_10m is not null
    and c.game_nighttime_ban is not null and c.game_noise_restrictions is not null)
    as simulation_candidate_only,
  c.dispatch_eligible_by_airport_admission as operationally_released,
  'GAME_ESTIMATES_ONLY_NOT_REAL_WORLD_VERIFICATION'::text as source_quality
from airlinerra_game.airport_unified_operations_v1 c
join airlinerra_game.airport_group2_game_profiles_v1 g using(airport_key)
left join airlinerra_game.airport_group2_admission_readiness_v1 r using(airport_key)
where c.source_group='GROUP_2';
revoke all on airlinerra_game.airport_group2_simulation_admission_candidates_v1 from public,anon,authenticated;
comment on view airlinerra_game.airport_group2_simulation_admission_candidates_v1 is
 'Game-only suitability candidates for future owner-approved simulation admission. Not real-world aviation verification and not operational flight permission.';