-- Section 9 — authenticated game-data inspection for starter commissioning.
-- Digital verification of trusted stored records is NOT a physical inspection.
-- Owner-only backend function. No condition, manufacture year, maintenance completion,
-- engine clearance, financial journal or flight record is created.
BEGIN;
CREATE TABLE airlinerra_game.section9_starter_commissioning_game_checks_v1 (
  request_id uuid NOT NULL
    REFERENCES airlinerra_game.section9_starter_commissioning_requests_v1(request_id),
  check_code text NOT NULL CHECK(check_code IN
    ('original_allocation','owner_membership','authoritative_world_clock',
     'verified_initial_position','verified_usage_baseline','no_operated_flights')),
  check_result text NOT NULL CHECK(check_result='passed'),
  source_table text NOT NULL,
  source_reference text NOT NULL,
  checked_game_date date NOT NULL,
  checked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (request_id,check_code)
);
ALTER TABLE airlinerra_game.section9_starter_commissioning_game_checks_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_starter_commissioning_game_checks_v1
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON TABLE airlinerra_game.section9_starter_commissioning_game_checks_v1 IS
 'Six immutable game DATA provenance checks. Not a physical aircraft inspection; does not approve condition, age, maintenance, slots, bookings or flights.';

CREATE FUNCTION airlinerra_game.section9_owned_starter_game_data_inspection_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
 req record;
 world_clock record;
 starter record;
 maintenance record;
 origin jsonb;
 check_count integer := 0;
 blocked text[] := ARRAY[]::text[];
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
 OR p_action IS NULL OR p_action NOT IN ('run','status')
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_STARTER_DATA_INSPECTION_REQUEST'; END IF;

 -- A record exists only after an authenticated owner explicitly requested
 -- commissioning. The independent game inspector does not create requests.
 SELECT * INTO req
 FROM airlinerra_game.section9_starter_commissioning_requests_v1 r
 WHERE r.owner_player_id=p_player AND r.airline_id=p_airline
   AND r.aircraft_inventory_id=p_aircraft AND r.world_id=1
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_COMMISSIONING_REQUEST_NOT_OWNED_OR_NOT_FOUND';END IF;

 SELECT count(*)::integer INTO check_count
 FROM airlinerra_game.section9_starter_commissioning_game_checks_v1 c
 WHERE c.request_id=req.request_id;
 IF req.request_status<>'requested' OR p_action='status' THEN
  RETURN jsonb_build_object('status',req.request_status,
   'dataChecksPassed',check_count,'requiredDataChecks',6,
   'gameDataInspectionComplete',check_count=6,
   'conditionVerified',false,'manufactureYearVerified',false,
   'maintenanceInspectionCompleted',false,'maintenanceReady',false,
   'aircraftClearedForFlight',false,'flightActivated',false,
   'ledgerPosted',false,'changed',false,
   'sourceScope','trusted_game_data_only_not_physical_inspection');
 END IF;

 SELECT w.confirmed_game_date,w.clock_source,w.last_verified_at,
  state.state AS world_state
 INTO world_clock
 FROM airlinerra_game.holding_world_clock_v1 w
 JOIN public.airlinerra_game_worlds state ON state.id=w.world_id
 WHERE w.world_id=1;
 IF NOT FOUND OR world_clock.world_state IS DISTINCT FROM 'active'
  OR world_clock.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR world_clock.last_verified_at IS NULL
  OR world_clock.confirmed_game_date IS NULL
  OR world_clock.confirmed_game_date<req.requested_game_date
 THEN blocked:=array_append(blocked,'AUTHORITATIVE_GAME_CLOCK_MISSING');
 END IF;

 SELECT s.source_fixture_id,s.registration,s.configuration_id,
  s.assigned_at,s.initial_home_airport_key,
  f.fleet_status,f.ownership_type,
  a.owner_player_id
 INTO starter
 FROM airlinerra_game.initial_aircraft_allocations_v1 s
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
  AND f.registration=s.registration AND f.configuration_id=s.configuration_id
 JOIN airlinerra_game.airlines a
  ON a.id=s.airline_id AND a.world_id=1
  AND a.owner_player_id=s.owner_player_id
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=1 AND w.player_id=s.owner_player_id AND w.state='active'
 WHERE s.airline_id=p_airline AND s.aircraft_inventory_id=p_aircraft
  AND s.owner_player_id=p_player AND s.world_id=1
  AND s.source_kind='original_airline_starter_allocation'
  AND s.source_fixture_id=req.original_fixture_id
  AND s.assigned_at IS NOT NULL AND s.assigned_at<=clock_timestamp()
  AND f.fleet_status='in_service' AND f.ownership_type='owned';
 IF NOT FOUND THEN blocked:=array_append(blocked,'ORIGINAL_STARTER_ALLOCATION_NOT_VERIFIED');END IF;

 IF coalesce(array_length(blocked,1),0)=0 THEN
  origin:=airlinerra_game.section9_starter_origin_evidence_v1(
    p_airline,p_aircraft,world_clock.confirmed_game_date);
  IF origin->>'verified' IS DISTINCT FROM 'true'
    OR origin->>'airportKey' IS DISTINCT FROM starter.initial_home_airport_key
    OR origin->>'notAnAcquisitionInspection' IS DISTINCT FROM 'true'
  THEN blocked:=array_append(blocked,'STARTING_AIRPORT_SOURCE_NOT_VERIFIED');END IF;
 END IF;

 SELECT * INTO maintenance FROM airlinerra_game.aircraft_maintenance_state_v1 m
 WHERE m.airline_id=p_airline AND m.aircraft_inventory_id=p_aircraft;
 IF NOT FOUND OR maintenance.tracking_source IS DISTINCT FROM
  'verified_original_starter_allocation_since_assignment'
  OR maintenance.verified_tracking_started_utc IS DISTINCT FROM starter.assigned_at
  OR maintenance.tracked_flight_hours IS DISTINCT FROM 0
  OR maintenance.tracked_flight_cycles IS DISTINCT FROM 0
 THEN blocked:=array_append(blocked,'INITIAL_USAGE_COUNTERS_NOT_VERIFIED'); END IF;

 IF EXISTS (SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
   WHERE m.airline_id=p_airline AND m.aircraft_inventory_id=p_aircraft
    AND m.world_id=1)
 THEN blocked:=array_append(blocked,'OPERATED_MOVEMENT_EXISTS');END IF;

 IF coalesce(array_length(blocked,1),0)>0 THEN
  RETURN jsonb_build_object('status','game_data_inspection_blocked',
   'blockingRequirements',to_jsonb(blocked),
   'gameDataInspectionComplete',false,'conditionVerified',false,
   'manufactureYearVerified',false,'maintenanceInspectionCompleted',false,
   'maintenanceReady',false,'flightActivated',false,
   'ledgerPosted',false,'changed',false);
 END IF;

 -- All six checks are based on stored evidence. A single transaction and
 -- row lock guarantee no duplicate findings or dual review state changes.
 INSERT INTO airlinerra_game.section9_starter_commissioning_game_checks_v1
 (request_id,check_code,check_result,source_table,source_reference,checked_game_date)
 VALUES
 (req.request_id,'original_allocation','passed',
  'airlinerra_game.initial_aircraft_allocations_v1',
  starter.source_fixture_id::text,world_clock.confirmed_game_date),
 (req.request_id,'owner_membership','passed',
  'airlinerra_game.world_memberships',
  p_player::text,world_clock.confirmed_game_date),
 (req.request_id,'authoritative_world_clock','passed',
  'airlinerra_game.holding_world_clock_v1',
  world_clock.confirmed_game_date::text,world_clock.confirmed_game_date),
 (req.request_id,'verified_initial_position','passed',
  'airlinerra_game.section9_starter_origin_evidence_v1',
  starter.initial_home_airport_key,world_clock.confirmed_game_date),
 (req.request_id,'verified_usage_baseline','passed',
  'airlinerra_game.aircraft_maintenance_state_v1',
  maintenance.verified_tracking_started_utc::text,world_clock.confirmed_game_date),
 (req.request_id,'no_operated_flights','passed',
  'airlinerra_game.section9_operated_flight_movements_v1',
  p_aircraft::text,world_clock.confirmed_game_date)
 ON CONFLICT (request_id,check_code) DO NOTHING;

 SELECT count(*)::integer INTO check_count
 FROM airlinerra_game.section9_starter_commissioning_game_checks_v1 c
 WHERE c.request_id=req.request_id AND c.check_result='passed';
 IF check_count<>6 THEN RAISE EXCEPTION USING ERRCODE='23514',
  MESSAGE='SECTION9_STARTER_DATA_INSPECTION_INCOMPLETE'; END IF;

 UPDATE airlinerra_game.section9_starter_commissioning_requests_v1 r
 SET request_status='in_review'
 WHERE r.request_id=req.request_id AND r.request_status='requested';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_COMMISSIONING_REQUEST_STATE_CHANGED';END IF;

 RETURN jsonb_build_object('status','in_review',
  'dataChecksPassed',6,'requiredDataChecks',6,
  'gameDataInspectionComplete',true,'conditionVerified',false,
  'manufactureYearVerified',false,'maintenanceInspectionCompleted',false,
  'maintenanceReady',false,'aircraftClearedForFlight',false,
  'flightActivated',false,'ledgerPosted',false,'changed',true,
  'sourceScope','trusted_game_data_only_not_physical_inspection');
END $fn$;

REVOKE ALL ON FUNCTION
 airlinerra_game.section9_owned_starter_game_data_inspection_v1(uuid,uuid,uuid,text)
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION
 airlinerra_game.section9_owned_starter_game_data_inspection_v1(uuid,uuid,uuid,text) IS
 'Six owner-scoped trusted game-data checks; progresses requested to in_review without inventing aircraft condition, manufacture age or maintenance certification.';
COMMIT;