-- Airlinerra Section 9: explicit GAME-ONLY starting airframe state.
-- Starter model policy is a fictional gameplay assumption, NOT a historical
-- aircraft record, inspected condition, completed maintenance, or flight release.
BEGIN;
CREATE TABLE airlinerra_game.section9_starter_game_airframe_policy_v1 (
 world_id smallint PRIMARY KEY CHECK (world_id=1),
 policy_version text NOT NULL CHECK (policy_version='starter_game_airframe_v1'),
 initial_game_age_years smallint NOT NULL CHECK (initial_game_age_years BETWEEN 0 AND 40),
 initial_game_condition_pct numeric(5,2) NOT NULL CHECK (initial_game_condition_pct BETWEEN 1 AND 100),
 check_schedule_source text NOT NULL CHECK (check_schedule_source='assumed_current_at_game_allocation_not_completed'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
INSERT INTO airlinerra_game.section9_starter_game_airframe_policy_v1
 (world_id,policy_version,initial_game_age_years,initial_game_condition_pct,check_schedule_source)
 VALUES (1,'starter_game_airframe_v1',8,92,'assumed_current_at_game_allocation_not_completed');
COMMENT ON TABLE airlinerra_game.section9_starter_game_airframe_policy_v1 IS
 'Design constants: 8 game-years and 92% game condition for starters, NOT measured aircraft age/airworthiness.';
ALTER TABLE airlinerra_game.section9_starter_game_airframe_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_starter_game_airframe_policy_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE airlinerra_game.section9_starter_game_airframe_baselines_v1 (
 aircraft_inventory_id uuid PRIMARY KEY REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 request_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_starter_commissioning_requests_v1(request_id),
 world_id smallint NOT NULL CHECK (world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 owner_player_id uuid NOT NULL,
 source_fixture_id uuid NOT NULL,
 game_baseline_date date NOT NULL,
 game_age_years smallint NOT NULL CHECK(game_age_years BETWEEN 0 AND 40),
 game_condition_pct numeric(5,2) NOT NULL CHECK(game_condition_pct BETWEEN 1 AND 100),
 source_policy_version text NOT NULL CHECK(source_policy_version='starter_game_airframe_v1'),
 source_kind text NOT NULL CHECK(source_kind='game_design_assumption_not_physical_evidence'),
 check_schedule_source text NOT NULL CHECK(check_schedule_source='assumed_current_at_game_allocation_not_completed'),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
COMMENT ON TABLE airlinerra_game.section9_starter_game_airframe_baselines_v1 IS
 'Game-only initial age/condition and game-service schedule anchor. Does not overwrite manufacture_year or condition_pct.';
ALTER TABLE airlinerra_game.section9_starter_game_airframe_baselines_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_starter_game_airframe_baselines_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.section9_owned_starter_game_airframe_initialize_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $body$
DECLARE
 req record;
 starter record;
 state record;
 clock record;
 config record;
 baseline record;
 checks integer;
 added integer:=0;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL OR
    p_action IS NULL OR p_action NOT IN ('status','initialize')
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_GAME_AIRFRAME_REQUEST';END IF;
 SELECT r.* INTO req FROM airlinerra_game.section9_starter_commissioning_requests_v1 r
 JOIN airlinerra_game.airlines a
 ON a.id=r.airline_id AND a.owner_player_id=r.owner_player_id AND a.world_id=1
 JOIN airlinerra_game.world_memberships w
 ON w.world_id=1 AND w.player_id=r.owner_player_id AND w.state='active'
 WHERE r.airline_id=p_airline AND r.owner_player_id=p_player
 AND r.aircraft_inventory_id=p_aircraft AND r.world_id=1
 FOR UPDATE OF r;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_GAME_AIRFRAME_NOT_OWNED'; END IF;
 SELECT b.* INTO baseline FROM airlinerra_game.section9_starter_game_airframe_baselines_v1 b
 WHERE b.request_id=req.request_id AND b.aircraft_inventory_id=p_aircraft
  AND b.airline_id=p_airline AND b.owner_player_id=p_player;
 IF FOUND THEN
  RETURN jsonb_build_object('status','game_baseline_initialized',
   'created',false,'gameAgeYears',baseline.game_age_years,
   'gameConditionPct',baseline.game_condition_pct,
   'gameBaselineDate',baseline.game_baseline_date,
   'basis','explicit_game_design_assumption_not_aircraft_history',
   'physicalConditionVerified',false,'realManufactureYearVerified',false,
   'checkHistoryCompleted',false,'dispatchApproved',false,
   'flightActivated',false,'ledgerPosted',false);
 END IF;
 IF p_action='status' THEN RETURN jsonb_build_object('status','not_initialized',
  'created',false,'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false,
  'physicalConditionVerified',false,'realManufactureYearVerified',false);END IF;
 IF req.request_status<>'in_review' THEN
 RETURN jsonb_build_object('status','blocked_game_data_review_not_complete',
 'created',false,'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false);END IF;

 SELECT count(DISTINCT c.check_code)::integer INTO checks
 FROM airlinerra_game.section9_starter_commissioning_game_checks_v1 c
 WHERE c.request_id=req.request_id AND c.check_result='passed';
 IF checks<>6 THEN RETURN jsonb_build_object('status','blocked_missing_six_game_data_checks',
 'created',false,'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT c.confirmed_game_date,c.clock_source,c.last_verified_at,w.state AS world_state
 INTO clock FROM airlinerra_game.holding_world_clock_v1 c
 JOIN public.airlinerra_game_worlds w ON w.id=c.world_id WHERE c.world_id=1;
 IF NOT FOUND OR clock.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR clock.last_verified_at IS NULL OR clock.world_state<>'active'
 OR clock.confirmed_game_date<req.requested_game_date
 THEN RETURN jsonb_build_object('status','blocked_world_game_clock',
 'created',false,'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false);END IF;

 SELECT s.*,f.fleet_status,f.ownership_type
 INTO starter FROM airlinerra_game.initial_aircraft_allocations_v1 s
 JOIN airlinerra_game.airline_aircraft_inventory f
 ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 AND f.registration=s.registration AND f.configuration_id=s.configuration_id
 WHERE s.aircraft_inventory_id=p_aircraft AND s.airline_id=p_airline
 AND s.owner_player_id=p_player AND s.world_id=1
 AND s.source_kind='original_airline_starter_allocation'
 AND s.source_fixture_id=req.original_fixture_id
 AND f.fleet_status='in_service' AND f.ownership_type='owned';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','blocked_original_starter_missing',
 'created',false,'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false);END IF;

 SELECT * INTO state FROM airlinerra_game.aircraft_maintenance_state_v1 m
 WHERE m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline FOR UPDATE;
 IF NOT FOUND OR state.verified_tracking_started_utc IS DISTINCT FROM starter.assigned_at
 OR state.tracked_flight_hours IS DISTINCT FROM 0
 OR state.tracked_flight_cycles IS DISTINCT FROM 0 OR
 state.condition_pct IS NOT NULL OR state.manufacture_year IS NOT NULL
 THEN RETURN jsonb_build_object('status','blocked_airframe_data_changed',
 'created',false,'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE world_id=1 AND airline_id=p_airline AND aircraft_inventory_id=p_aircraft)
 THEN RETURN jsonb_build_object('status','blocked_prior_aircraft_movements',
 'created',false,'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT * INTO config FROM airlinerra_game.section9_starter_game_airframe_policy_v1
 WHERE world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23514',
 MESSAGE='SECTION9_GAME_BASELINE_POLICY_MISSING';END IF;
 INSERT INTO airlinerra_game.section9_starter_game_airframe_baselines_v1
 (aircraft_inventory_id,request_id,world_id,airline_id,owner_player_id,
 source_fixture_id,game_baseline_date,game_age_years,game_condition_pct,
 source_policy_version,source_kind,check_schedule_source)
 VALUES(p_aircraft,req.request_id,1,p_airline,p_player,
 req.original_fixture_id,clock.confirmed_game_date,config.initial_game_age_years,
 config.initial_game_condition_pct,config.policy_version,
 'game_design_assumption_not_physical_evidence',config.check_schedule_source)
 ON CONFLICT(aircraft_inventory_id) DO NOTHING;
 GET DIAGNOSTICS added=ROW_COUNT;
 SELECT * INTO baseline FROM airlinerra_game.section9_starter_game_airframe_baselines_v1
 WHERE aircraft_inventory_id=p_aircraft AND request_id=req.request_id
 AND owner_player_id=p_player AND airline_id=p_airline;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_GAME_AIRFRAME_BASELINE_CONFLICT';END IF;
 RETURN jsonb_build_object('status','game_baseline_initialized',
  'created',added=1,'gameAgeYears',baseline.game_age_years,
  'gameConditionPct',baseline.game_condition_pct,
  'gameBaselineDate',baseline.game_baseline_date,
  'basis','explicit_game_design_assumption_not_aircraft_history',
  'physicalConditionVerified',false,'realManufactureYearVerified',false,
  'checkHistoryCompleted',false,'dispatchApproved',false,
  'flightActivated',false,'ledgerPosted',false);
END $body$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_starter_game_airframe_initialize_v1(
 uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;