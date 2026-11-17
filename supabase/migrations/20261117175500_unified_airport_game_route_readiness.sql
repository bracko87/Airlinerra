-- Unified read-only route game compatibility preflight, never a release.
CREATE OR REPLACE FUNCTION airlinerra_game.unified_airport_route_game_readiness_v1(p_origin_key text, p_destination_key text, p_stand_type text DEFAULT 'terminal'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
declare orig record; dest record; all_inputs boolean; traffic_ok boolean; capacity_ok boolean;
begin
 if p_origin_key is null or p_destination_key is null or p_origin_key=p_destination_key
    or p_stand_type not in ('terminal','remote','cargo')
 then return jsonb_build_object('decision','INVALID_ROUTE_INPUT','canActivateFlights',false); end if;
 select c.*,g.game_traffic_type into orig
 from airlinerra_game.airport_unified_operations_v1 c
 left join airlinerra_game.airport_group2_game_profiles_v1 g
 on c.source_group='GROUP_2' and g.airport_key=c.airport_key
 where c.world_id=1 and c.airport_key=p_origin_key;
 select c.*,g.game_traffic_type into dest
 from airlinerra_game.airport_unified_operations_v1 c
 left join airlinerra_game.airport_group2_game_profiles_v1 g
 on c.source_group='GROUP_2' and g.airport_key=c.airport_key
 where c.world_id=1 and c.airport_key=p_destination_key;
 if orig.airport_key is null or dest.airport_key is null
 then return jsonb_build_object('decision','AIRPORT_NOT_FOUND',
    'originFound',orig.airport_key is not null,'destinationFound',dest.airport_key is not null,
    'canActivateFlights',false); end if;
 all_inputs:=orig.game_runway_length_m>0 and dest.game_runway_length_m>0
  and orig.game_terminal_slot_per_10m is not null and dest.game_terminal_slot_per_10m is not null
  and orig.game_nighttime_ban is not null and dest.game_nighttime_ban is not null;
 traffic_ok:=case when p_stand_type='cargo' then
  coalesce(orig.game_traffic_type in ('Cargo','Both'),true)
  and coalesce(dest.game_traffic_type in ('Cargo','Both'),true)
 else coalesce(orig.game_traffic_type in ('Passenger','Both'),true)
  and coalesce(dest.game_traffic_type in ('Passenger','Both'),true) end;
 capacity_ok:=case p_stand_type
 when 'cargo' then orig.game_cargo_stands>0 and dest.game_cargo_stands>0
   and orig.game_cargo_slot_per_10m>0 and dest.game_cargo_slot_per_10m>0
 when 'remote' then orig.game_remote_stands>0 and dest.game_remote_stands>0
   and orig.game_remote_slot_per_10m>0 and dest.game_remote_slot_per_10m>0
 else orig.game_terminal_stands>0 and dest.game_terminal_stands>0
   and orig.game_terminal_slot_per_10m>0 and dest.game_terminal_slot_per_10m>0 end;
 return jsonb_build_object(
  'decision',case when not all_inputs then 'GAME_MODEL_MISSING_INPUTS'
    when not traffic_ok then 'GAME_TRAFFIC_TYPE_INCOMPATIBLE'
    when not capacity_ok then 'GAME_STAND_OR_SLOT_CAPACITY_UNAVAILABLE'
    when not (orig.dispatch_eligible_by_airport_admission and dest.dispatch_eligible_by_airport_admission)
      then 'GAME_INPUTS_PREPARED_ADMISSION_BLOCKED'
    else 'AIRPORT_ADMISSION_PASSED_ADDITIONAL_FLIGHT_CHECKS_REQUIRED' end,
  'gameModelInputsPresent',all_inputs,
  'gameTrafficTypeCompatible',traffic_ok,
  'gameStandCapacityAvailable',capacity_ok,
  'airportAdmissionPassed',orig.dispatch_eligible_by_airport_admission and dest.dispatch_eligible_by_airport_admission,
  'canActivateFlights',false,
  'origin',jsonb_build_object('key',orig.airport_key,'sourceGroup',orig.source_group,
    'admissionStatus',orig.admission_status,'trafficType',orig.game_traffic_type),
  'destination',jsonb_build_object('key',dest.airport_key,'sourceGroup',dest.source_group,
    'admissionStatus',dest.admission_status,'trafficType',dest.game_traffic_type),
  'provenance','estimated_game_inputs_not_real_world_clearance',
  'nextCheck','Owner aircraft/runway compatibility, precise restrictions, slots, rights, live flight certification'
 );
end $function$
;
revoke all on function airlinerra_game.unified_airport_route_game_readiness_v1(text,text,text) from public,anon,authenticated;
