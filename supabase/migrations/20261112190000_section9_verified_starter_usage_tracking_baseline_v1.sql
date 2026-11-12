-- World 1 Phase 1: initialize hours/cycles counted ONLY since an
-- independent, owner-bound original GAME starter-aircraft allocation.
-- Never invent manufacture year, lifetime hours, condition, repair, movement
-- or an inspection. This must not activate flight dispatch or post cash.
BEGIN;
CREATE OR REPLACE FUNCTION
 airlinerra_game.section9_initialize_verified_starter_usage_v1(
  p_airline uuid,p_aircraft uuid,p_game_date date)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE
 source_row record; tracking_row record; clock_row record;
 origin jsonb; updated_count integer := 0;
BEGIN
 IF p_airline IS NULL OR p_aircraft IS NULL OR p_game_date IS NULL
  OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_STARTER_TRACKING_REQUEST';END IF;
 SELECT clock.confirmed_game_date,clock.clock_source,w.state
 INTO clock_row
 FROM airlinerra_game.holding_world_clock_v1 clock
 JOIN public.airlinerra_game_worlds w ON w.id=clock.world_id
 WHERE clock.world_id=1;
 IF NOT FOUND OR clock_row.state IS DISTINCT FROM 'active'
  OR clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR clock_row.confirmed_game_date IS DISTINCT FROM p_game_date
 THEN RETURN jsonb_build_object('status','game_clock_not_verified',
  'changed',false,'maintenanceCompleted',false,'flightActivated',false);
 END IF;
 -- Reuse the already deployed owner/fixture/registration/configuration/world
 -- verification; this yields initial game location only, not a real delivery.
 origin:=airlinerra_game.section9_starter_origin_evidence_v1(
  p_airline,p_aircraft,p_game_date);
 IF origin->>'verified' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','starter_allocation_not_verified',
  'changed',false,'maintenanceCompleted',false,'flightActivated',false);
 END IF;
 SELECT s.assigned_at,s.airline_id,s.aircraft_inventory_id,
   s.initial_home_airport_key
 INTO source_row
 FROM airlinerra_game.initial_aircraft_allocations_v1 s
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id
   AND a.owner_player_id=s.owner_player_id AND a.world_id=1
 WHERE s.airline_id=p_airline AND s.aircraft_inventory_id=p_aircraft
  AND s.world_id=1 AND s.source_kind='original_airline_starter_allocation'
  AND s.source_fixture_id IS NOT NULL
  AND s.assigned_at IS NOT NULL AND s.assigned_at<=clock_timestamp()
  AND s.initial_home_airport_key=origin->>'airportKey'
  AND s.registration=f.registration
  AND s.configuration_id=f.configuration_id
 LIMIT 1;
 IF NOT FOUND THEN RETURN jsonb_build_object(
  'status','starter_allocation_not_verified','changed',false,
  'maintenanceCompleted',false,'flightActivated',false);END IF;

 -- Lock usage state so a second initializer cannot reset this counter.
 SELECT m.* INTO tracking_row
 FROM airlinerra_game.aircraft_maintenance_state_v1 m
 WHERE m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline
 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object(
  'status','maintenance_state_missing','changed',false,
  'maintenanceCompleted',false,'flightActivated',false);END IF;
 IF tracking_row.verified_tracking_started_utc IS NOT NULL
  OR tracking_row.tracked_flight_hours IS NOT NULL
  OR tracking_row.tracked_flight_cycles IS NOT NULL
  OR tracking_row.tracking_source IS DISTINCT FROM 'not_started'
 THEN RETURN jsonb_build_object(
  'status','tracking_already_started_or_different_source',
  'changed',false,'maintenanceCompleted',false,'flightActivated',false);
 END IF;

 -- Never seed zero if a real movement has occurred or an active current
 -- aircraft state already exists; manually reconcile historical data.
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 event
  WHERE event.airline_id=p_airline AND event.aircraft_inventory_id=p_aircraft
    AND event.world_id=1)
 OR EXISTS(
  SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 location
  WHERE location.airline_id=p_airline AND location.aircraft_inventory_id=p_aircraft
    AND location.world_id=1)
 THEN RETURN jsonb_build_object(
  'status','movement_evidence_requires_reconciliation',
  'changed',false,'maintenanceCompleted',false,'flightActivated',false);
 END IF;

 UPDATE airlinerra_game.aircraft_maintenance_state_v1 m
 SET verified_tracking_started_utc=source_row.assigned_at,
     tracked_flight_hours=0,
     tracked_flight_cycles=0,
     tracking_source='verified_original_starter_allocation_since_assignment',
     updated_at=clock_timestamp()
 WHERE m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline
  AND m.verified_tracking_started_utc IS NULL
  AND m.tracked_flight_hours IS NULL AND m.tracked_flight_cycles IS NULL
  AND m.tracking_source='not_started';
 GET DIAGNOSTICS updated_count=ROW_COUNT;
 RETURN jsonb_build_object(
  'status',CASE WHEN updated_count=1
   THEN 'starter_usage_tracking_initialized'
   ELSE 'starter_tracking_not_changed' END,
  'changed',updated_count=1,
  'trackingStartedAt',CASE WHEN updated_count=1
    THEN source_row.assigned_at ELSE NULL END,
  'hoursSinceBaseline',CASE WHEN updated_count=1 THEN 0 ELSE NULL END,
  'cyclesSinceBaseline',CASE WHEN updated_count=1 THEN 0 ELSE NULL END,
  'lifetimeHoursVerified',false,
  'manufactureYearVerified',false,
  'aircraftConditionVerified',false,
  'maintenanceCompleted',false,'flightActivated',false,
  'movementRecorded',false,'ledgerPosted',false);
END $function$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_initialize_verified_starter_usage_v1(uuid,uuid,date)
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION
 airlinerra_game.section9_initialize_verified_starter_usage_v1(uuid,uuid,date)
 IS 'Private idempotent initialization of 0 flight hours/cycles SINCE signed original starter game allocation only; never invents aircraft condition, age, repairs or lifetime history.';
COMMIT;
