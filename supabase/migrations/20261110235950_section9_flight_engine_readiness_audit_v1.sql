-- Read-only World 1 Section 9 flight release audit. This is NOT an
-- activation, scheduler, clock tick, signed movement, fuel mutation or charge.
-- It gives operators a durable single place to inspect the release blockers.
create or replace view airlinerra_game.section9_flight_engine_readiness_audit_v1
with (security_invoker = true) as
select
  1::smallint as world_id,
  w.state as world_state,
  w.opens_at as world_opens_at,
  c.confirmed_game_date,
  c.clock_source,
  (c.clock_source='authoritative_game_engine'
   and c.confirmed_game_date is not null) as authoritative_clock_connected,
  (producer.world_id is not null) as clock_producer_configured,
  coalesce(producer.producer_status='enabled',false) as clock_producer_enabled,
  (select count(*) from airlinerra_game.airline_flight_schedule_drafts_v1)::bigint
    as saved_flight_schedules,
  (select count(*) from airlinerra_game.airline_flight_schedule_drafts_v1 s
   where s.status='active')::bigint as active_flight_schedules,
  (select count(*) from airlinerra_game.section9_schedule_operational_certifications_v1)::bigint
    as operational_certification_records,
  (select count(*) from airlinerra_game.section9_aircraft_day_operations_jobs_v1)::bigint
    as aircraft_operation_jobs,
  (select count(*) from airlinerra_game.section9_operated_flight_movements_v1)::bigint
    as verified_movement_records,
  (select count(*) from airlinerra_game.section9_route_posted_flight_financials_v1)::bigint
    as settled_flight_records,
  (select count(*) from airlinerra_game.aircraft_fuel_planning_profiles_v1
   where full_kg_per_100km>0)::bigint as aircraft_fuel_planning_profiles,
  (select count(*) from airlinerra_game.aircraft_game_fuel_family_v1
   where fuel_family='TURBINE_KEROSENE_ASSUMED')::bigint as game_kerosene_aircraft_profiles,
  'NOT_ACTIVATED'::text as trusted_flight_execution_release,
  'NOT_ACTIVATED'::text as fuel_transaction_release,
  false::boolean as automatic_flight_and_fuel_settlement_enabled
from public.airlinerra_game_worlds w
left join airlinerra_game.holding_world_clock_v1 c on c.world_id=w.id
left join airlinerra_game.section9_clock_producer_schedule_v1 producer
 on producer.world_id=w.id
where w.id=1;

revoke all on airlinerra_game.section9_flight_engine_readiness_audit_v1
from public, anon, authenticated;

comment on view airlinerra_game.section9_flight_engine_readiness_audit_v1 is
'Private, read-only World 1 flight-engine operational readiness diagnostic; never proof of flying, dispatch release or fuel accounting. Status fields must be updated in a future independently certified release.';
