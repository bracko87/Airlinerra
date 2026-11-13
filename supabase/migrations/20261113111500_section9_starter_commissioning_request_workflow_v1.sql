-- World 1 starter-aircraft commissioning REQUEST workflow.
-- Explicit owner-authenticated request, not a completed inspection or approval.
-- This inserts NO condition, manufacture year, maintenance check, flight or charge.
BEGIN;

CREATE TABLE airlinerra_game.section9_starter_commissioning_requests_v1 (
  request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
  owner_player_id uuid NOT NULL,
  airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
  aircraft_inventory_id uuid NOT NULL UNIQUE
    REFERENCES airlinerra_game.airline_aircraft_inventory(id),
  original_fixture_id uuid NOT NULL,
  requested_game_date date NOT NULL,
  request_status text NOT NULL DEFAULT 'requested'
    CHECK(request_status IN ('requested','in_review','reviewed','declined')),
  requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  reviewed_at timestamptz,
  independent_review_reference text,
  CHECK (
    (request_status IN ('requested','in_review') AND reviewed_at IS NULL
      AND independent_review_reference IS NULL)
    OR (request_status IN ('reviewed','declined') AND reviewed_at IS NOT NULL
      AND length(independent_review_reference)>=12)
  )
);
CREATE INDEX section9_starter_commissioning_owner_lookup_v1
 ON airlinerra_game.section9_starter_commissioning_requests_v1
 (owner_player_id,airline_id);
ALTER TABLE airlinerra_game.section9_starter_commissioning_requests_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_starter_commissioning_requests_v1
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON TABLE airlinerra_game.section9_starter_commissioning_requests_v1 IS
 'Owner-initiated game starter commissioning requests; records no invented condition, real-world age, inspection or maintenance completion. Status requested is not approval.';

CREATE FUNCTION airlinerra_game.section9_owned_starter_commissioning_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_action text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
 starter record;
 state record;
 clock record;
 existing record;
 inserted_count integer:=0;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
  OR p_action NOT IN ('request','status') OR p_action IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_STARTER_COMMISSIONING_REQUEST'; END IF;

 SELECT s.source_fixture_id,s.registration,s.assigned_at,
  f.fleet_status,f.ownership_type,f.configuration_id
 INTO starter
 FROM airlinerra_game.initial_aircraft_allocations_v1 s
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
   AND f.registration=s.registration AND f.configuration_id=s.configuration_id
 JOIN airlinerra_game.airlines a
  ON a.id=s.airline_id AND a.owner_player_id=s.owner_player_id AND a.world_id=1
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=1 AND w.player_id=a.owner_player_id AND w.state='active'
 WHERE s.world_id=1 AND s.source_kind='original_airline_starter_allocation'
  AND s.owner_player_id=p_player AND s.airline_id=p_airline
  AND s.aircraft_inventory_id=p_aircraft
  AND s.source_fixture_id IS NOT NULL AND s.assigned_at IS NOT NULL
  AND s.assigned_at<=clock_timestamp();
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_STARTER_COMMISSIONING_NOT_OWNED_OR_NOT_ELIGIBLE';
 END IF;

 SELECT confirmed_game_date,clock_source,last_verified_at INTO clock
 FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 IF clock.confirmed_game_date IS NULL
  OR clock.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR clock.last_verified_at IS NULL
  OR NOT EXISTS (SELECT 1 FROM public.airlinerra_game_worlds w
                  WHERE w.id=1 AND w.state='active')
 THEN RETURN jsonb_build_object('status','blocked_game_clock',
   'created',false,'inspectionCompleted',false,
   'flightActivated',false,'ledgerPosted',false);END IF;

 SELECT * INTO existing
 FROM airlinerra_game.section9_starter_commissioning_requests_v1 req
 WHERE req.aircraft_inventory_id=p_aircraft AND req.airline_id=p_airline
  AND req.owner_player_id=p_player AND req.original_fixture_id=starter.source_fixture_id;
 IF FOUND THEN
  RETURN jsonb_build_object(
   'status',existing.request_status,'requestId',existing.request_id,
   'aircraftRegistration',starter.registration,'gameDate',existing.requested_game_date,
   'created',false,'reviewed',existing.request_status='reviewed',
   'conditionVerified',false,'manufactureYearVerified',false,
   'inspectionCompleted',false,'maintenanceCompleted',false,
   'flightActivated',false,'ledgerPosted',false,
   'note','This request records no inspection result or operational clearance.');
 END IF;
 IF p_action='status' THEN
  RETURN jsonb_build_object('status','not_requested',
   'created',false,'aircraftRegistration',starter.registration,
   'inspectionCompleted',false,'flightActivated',false,'ledgerPosted',false);
 END IF;

 IF starter.fleet_status IS DISTINCT FROM 'in_service'
  OR starter.ownership_type NOT IN ('owned','leased')
 THEN RETURN jsonb_build_object('status','blocked_aircraft_not_in_service',
  'created',false,'inspectionCompleted',false,'flightActivated',false);END IF;

 SELECT * INTO state
 FROM airlinerra_game.aircraft_maintenance_state_v1
 WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline;
 IF NOT FOUND OR state.verified_tracking_started_utc IS NULL
  OR state.tracked_flight_hours IS NULL OR state.tracked_flight_cycles IS NULL
  OR state.tracking_source IS DISTINCT FROM
    'verified_original_starter_allocation_since_assignment'
 THEN RETURN jsonb_build_object('status','blocked_usage_baseline_missing',
  'created',false,'inspectionCompleted',false,'flightActivated',false);END IF;

 IF EXISTS (SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
            WHERE m.world_id=1 AND m.airline_id=p_airline
              AND m.aircraft_inventory_id=p_aircraft)
 THEN RETURN jsonb_build_object('status','blocked_aircraft_already_operated',
  'created',false,'inspectionCompleted',false,'flightActivated',false);END IF;

 -- A review is a separate trusted game action; no guessed condition or age.
 INSERT INTO airlinerra_game.section9_starter_commissioning_requests_v1(
  owner_player_id,airline_id,aircraft_inventory_id,original_fixture_id,
  requested_game_date)
 VALUES (p_player,p_airline,p_aircraft,starter.source_fixture_id,
         clock.confirmed_game_date)
 ON CONFLICT (aircraft_inventory_id) DO NOTHING;
 GET DIAGNOSTICS inserted_count=ROW_COUNT;

 SELECT * INTO existing
 FROM airlinerra_game.section9_starter_commissioning_requests_v1 req
 WHERE req.aircraft_inventory_id=p_aircraft AND req.airline_id=p_airline
  AND req.owner_player_id=p_player AND req.original_fixture_id=starter.source_fixture_id;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_STARTER_COMMISSIONING_CONFLICT'; END IF;
 RETURN jsonb_build_object(
  'status',existing.request_status,'requestId',existing.request_id,
  'aircraftRegistration',starter.registration,'gameDate',existing.requested_game_date,
  'created',inserted_count=1,'reviewed',false,
  'conditionVerified',false,'manufactureYearVerified',false,
  'inspectionCompleted',false,'maintenanceCompleted',false,
  'flightActivated',false,'ledgerPosted',false,
  'note','Commissioning requested. Requires independent game inspection and review.');
END $fn$;

REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_starter_commissioning_v1(
 uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION airlinerra_game.section9_owned_starter_commissioning_v1(
 uuid,uuid,uuid,text) IS
 'Owner verified, idempotent private commissioning request/status. Does NOT approve an aircraft or release flights; request is not an inspection.';
COMMIT;
