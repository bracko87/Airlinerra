-- Airlinerra Phase 1 aircraft position authority.
-- Original starter allocation is a valid game INITIAL location only while no
-- signed operated movements/current position exist. Never backfill a fake
-- arrival, an acquisition inspection, or a payment/flight event.
BEGIN;
CREATE OR REPLACE FUNCTION
 airlinerra_game.section9_owned_aircraft_operational_position_v1(
  p_player uuid,p_airline uuid,p_aircraft uuid,p_game_date date)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE
 f record; clk record; pos record; m record; starter jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL OR
    p_game_date IS NULL OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_AIRCRAFT_POSITION_REQUEST';
 END IF;
 SELECT f.id,f.fleet_status,f.registration,f.configuration_id,
        a.home_airport_key
 INTO f
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id
  AND a.world_id=1 AND a.owner_player_id=p_player
 WHERE f.id=p_aircraft AND f.airline_id=p_airline;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_POSITION_AIRCRAFT_NOT_OWNED';
 END IF;
 SELECT c.confirmed_game_date,c.clock_source,c.engine_proof_ref,
        w.state AS world_state
 INTO clk
 FROM airlinerra_game.holding_world_clock_v1 c
 JOIN public.airlinerra_game_worlds w ON w.id=c.world_id
 WHERE c.world_id=1;
 IF NOT FOUND OR clk.world_state IS DISTINCT FROM 'active'
  OR clk.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR clk.confirmed_game_date IS DISTINCT FROM p_game_date
  OR length(coalesce(clk.engine_proof_ref,''))<12
 THEN RETURN jsonb_build_object(
  'status','game_clock_not_current','verified',false,
  'atGroundAirport',false,'initialOnly',false,'readOnly',true,
  'movementRecorded',false,'flightActivated',false);
 END IF;
 IF f.fleet_status IS DISTINCT FROM 'in_service'
 THEN RETURN jsonb_build_object(
  'status','aircraft_not_in_service','verified',false,
  'atGroundAirport',false,'initialOnly',false,'readOnly',true,
  'movementRecorded',false,'flightActivated',false);
 END IF;

 SELECT * INTO pos
 FROM airlinerra_game.section9_aircraft_current_position_v1
 WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline
  AND world_id=1;
 IF FOUND THEN
  SELECT * INTO m
  FROM airlinerra_game.section9_operated_flight_movements_v1
  WHERE engine_event_id=pos.last_engine_event_id
   AND aircraft_inventory_id=p_aircraft
   AND airline_id=p_airline AND world_id=1;
  IF FOUND AND m.actual_event_utc=pos.last_event_utc
   AND (
    (pos.location_status='grounded' AND m.phase='arrived'
     AND pos.airport_key=m.destination_airport_key
     AND pos.current_flight_occurrence_id IS NULL)
    OR
    (pos.location_status='in_flight' AND m.phase='departed'
     AND pos.airport_key IS NULL
     AND pos.current_flight_occurrence_id=m.flight_occurrence_id)
   )
   AND NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 later
    WHERE later.aircraft_inventory_id=p_aircraft
     AND later.airline_id=p_airline AND later.world_id=1
     AND (later.actual_event_utc>m.actual_event_utc OR
      (later.actual_event_utc=m.actual_event_utc
       AND later.engine_event_id<>m.engine_event_id)))
  THEN RETURN jsonb_build_object(
    'status','verified_operated_aircraft_position',
    'verified',true,'atGroundAirport',pos.location_status='grounded',
    'airportKey',pos.airport_key,
    'initialOnly',false,'sourceKind','verified_signed_operated_movement',
    'positionEventUtc',pos.last_event_utc,
    'readOnly',true,'movementRecorded',false,'flightActivated',false);
  END IF;
  RETURN jsonb_build_object(
   'status','current_position_movement_evidence_mismatch',
   'verified',false,'atGroundAirport',false,'initialOnly',false,
   'readOnly',true,'movementRecorded',false,'flightActivated',false);
 END IF;

 -- Never rewind an aircraft to its original starter airport if any
 -- operated movement exists, including when its current-position row
 -- is missing or under repair.
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1
  WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft
   AND world_id=1)
 THEN RETURN jsonb_build_object(
  'status','operated_position_record_missing',
  'verified',false,'atGroundAirport',false,'initialOnly',false,
  'readOnly',true,'movementRecorded',false,'flightActivated',false);
 END IF;

 starter:=airlinerra_game.section9_starter_origin_evidence_v1(
  p_airline,p_aircraft,p_game_date);
 IF starter->>'verified'='true'
  AND starter->>'initialPositionVerified'='true'
  AND starter->>'airportKey'=f.home_airport_key
  AND starter->>'aircraftInventoryId'=p_aircraft::text
  AND starter->>'sourceKind'='original_airline_starter_allocation'
  AND EXISTS (
   SELECT 1 FROM airlinerra_game.approved_game_airports airport
   WHERE airport.world_id=1
    AND airport.airport_key=starter->>'airportKey')
 THEN RETURN jsonb_build_object(
  'status','verified_original_game_starter_position',
  'verified',true,'atGroundAirport',true,
  'airportKey',starter->>'airportKey',
  'initialOnly',true,'sourceKind','original_airline_starter_allocation',
  'assignedGameDate',starter->>'assignedGameDate',
  'readOnly',true,'movementRecorded',false,'flightActivated',false);
 END IF;
 RETURN jsonb_build_object(
  'status','aircraft_starting_position_not_verified','verified',false,
  'atGroundAirport',false,'initialOnly',false,'readOnly',true,
  'movementRecorded',false,'flightActivated',false);
END $function$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_owned_aircraft_operational_position_v1(
  uuid,uuid,uuid,date)
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION
 airlinerra_game.section9_owned_aircraft_operational_position_v1(
  uuid,uuid,uuid,date)
 IS 'Owner-fenced, read-only initial game allocation/current signed movement resolver. Does not activate flights or invent aircraft movement.';
COMMIT;
