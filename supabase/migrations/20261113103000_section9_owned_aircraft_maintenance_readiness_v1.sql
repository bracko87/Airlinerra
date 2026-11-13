-- Section 9 Phase 1: exact-source aircraft condition and maintenance readiness.
-- Read-only preview. No initial condition, aircraft age, completed inspections,
-- hours, cycles, charges, movements or operating approvals are fabricated.
BEGIN;
CREATE TABLE airlinerra_game.section9_aircraft_condition_assessments_v1 (
 assessment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK (world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 inspected_condition_pct numeric(5,2) NOT NULL
  CHECK (inspected_condition_pct>=0 AND inspected_condition_pct<=100),
 inspected_manufacture_year smallint
  CHECK (inspected_manufacture_year BETWEEN 1900 AND 2100),
 assessment_kind text NOT NULL CHECK(assessment_kind IN
  ('verified_game_starter_commissioning','verified_game_delivery_inspection',
   'verified_game_maintenance_inspection')),
 source_event_reference text NOT NULL UNIQUE
  CHECK(length(source_event_reference)>=12),
 verified_game_date date NOT NULL,
 source_review_status text NOT NULL DEFAULT 'pending'
  CHECK(source_review_status IN ('pending','verified')),
 reviewed_at timestamptz,
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((source_review_status='verified' AND reviewed_at IS NOT NULL)
       OR (source_review_status='pending' AND reviewed_at IS NULL))
);
CREATE INDEX section9_aircraft_condition_assessments_lookup
 ON airlinerra_game.section9_aircraft_condition_assessments_v1
 (aircraft_inventory_id,airline_id,verified_game_date DESC);
ALTER TABLE airlinerra_game.section9_aircraft_condition_assessments_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_aircraft_condition_assessments_v1
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON TABLE airlinerra_game.section9_aircraft_condition_assessments_v1 IS
 'Only reviewed real game-inspection evidence is acceptable for future condition proof. No fabricated inspection receipts; new records pending by default. Private table.';

CREATE FUNCTION airlinerra_game.section9_owned_aircraft_maintenance_readiness_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_game_day date)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
 fleet_row record;
 state_row record;
 clock_row record;
 approved_assessment record;
 blockers text[]:=ARRAY[]::text[];
 expected_checks integer:=0;
 verified_check_types integer:=0;
 completion_count integer:=0;
 refit_plan_count integer:=0;
 tracking_ready boolean:=false;
 condition_proof boolean:=false;
 manufacture_year_proof boolean:=false;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
 OR p_game_day IS NULL OR p_game_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_INVALID_MAINTENANCE_READINESS_REQUEST';END IF;

 SELECT f.id,f.airline_id,f.configuration_id,f.registration,f.fleet_status
 INTO fleet_row
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active'
 WHERE f.id=p_aircraft AND f.airline_id=p_airline AND a.owner_player_id=p_player
  AND a.world_id=1 AND f.ownership_type IN ('owned','leased');
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_MAINTENANCE_AIRCRAFT_NOT_OWNED';END IF;

 SELECT c.confirmed_game_date,c.clock_source,c.last_verified_at,
   w.state AS world_state
 INTO clock_row FROM airlinerra_game.holding_world_clock_v1 c
 JOIN public.airlinerra_game_worlds w ON w.id=c.world_id
 WHERE c.world_id=1;
 IF NOT FOUND OR clock_row.world_state IS DISTINCT FROM 'active'
 OR clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR clock_row.confirmed_game_date IS DISTINCT FROM p_game_day
 OR clock_row.last_verified_at IS NULL
 THEN RETURN jsonb_build_object(
  'status','verified_game_clock_missing','maintenanceReady',false,
  'readOnly',true,'flightActivated',false,'ledgerPosted',false,
  'blockers',jsonb_build_array('WORLD_CLOCK_NOT_VERIFIED_FOR_MAINTENANCE'));
 END IF;

 SELECT * INTO state_row FROM airlinerra_game.aircraft_maintenance_state_v1 m
 WHERE m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline;
 IF NOT FOUND THEN blockers:=array_append(blockers,'AIRCRAFT_MAINTENANCE_STATE_MISSING');
 ELSE
  tracking_ready:=state_row.verified_tracking_started_utc IS NOT NULL
   AND state_row.tracked_flight_hours IS NOT NULL
   AND state_row.tracked_flight_hours>=0
   AND state_row.tracked_flight_cycles IS NOT NULL
   AND state_row.tracked_flight_cycles>=0
   AND state_row.tracking_source<>'not_started';
  IF NOT tracking_ready
  THEN blockers:=array_append(blockers,'AIRCRAFT_USAGE_COUNTER_NOT_VERIFIED');
  END IF;
 END IF;

 -- This receipt table starts EMPTY. Only a future authenticated game
 -- inspection workflow may enter verified receipts. Neither original starter
 -- allocation nor recorded zero hours qualifies as an inspection.
 SELECT e.* INTO approved_assessment
 FROM airlinerra_game.section9_aircraft_condition_assessments_v1 e
 WHERE e.airline_id=p_airline AND e.aircraft_inventory_id=p_aircraft
  AND e.world_id=1 AND e.source_review_status='verified'
  AND e.verified_game_date<=p_game_day
 ORDER BY e.verified_game_date DESC,e.reviewed_at DESC,e.assessment_id DESC
 LIMIT 1;

 condition_proof:=FOUND AND state_row.condition_pct IS NOT NULL
  AND state_row.condition_pct=approved_assessment.inspected_condition_pct
  AND state_row.condition_basis='verified_game_inspection'
  AND approved_assessment.inspected_condition_pct>0;
 manufacture_year_proof:=FOUND AND state_row.manufacture_year IS NOT NULL
  AND approved_assessment.inspected_manufacture_year IS NOT NULL
  AND state_row.manufacture_year=approved_assessment.inspected_manufacture_year
  AND state_row.manufacture_year_basis='verified_game_inspection';

 IF NOT condition_proof
 THEN blockers:=array_append(blockers,'AIRCRAFT_CONDITION_INSPECTION_NOT_VERIFIED');
 END IF;
 IF NOT manufacture_year_proof
 THEN blockers:=array_append(blockers,'AIRCRAFT_MANUFACTURE_YEAR_NOT_VERIFIED');
 END IF;
 IF fleet_row.fleet_status<>'in_service'
 THEN blockers:=array_append(blockers,'AIRCRAFT_NOT_IN_SERVICE');
 END IF;

 SELECT count(*)::integer INTO expected_checks
 FROM airlinerra_game.maintenance_check_policy_v1;
 SELECT count(*)::integer,count(DISTINCT c.check_code)::integer
 INTO completion_count,verified_check_types
 FROM airlinerra_game.aircraft_maintenance_completions_v1 c
 JOIN airlinerra_game.maintenance_check_policy_v1 policy
  ON policy.check_code=c.check_code
 WHERE c.airline_id=p_airline AND c.aircraft_inventory_id=p_aircraft
   AND c.world_id=1
   AND c.source_kind IN
    ('verified_game_engine','verified_game_maintenance_record');
 IF expected_checks=0 OR verified_check_types<expected_checks
 THEN blockers:=array_append(blockers,'MAINTENANCE_CHECK_HISTORY_INCOMPLETE');
 END IF;
 SELECT count(*)::integer INTO refit_plan_count
 FROM airlinerra_game.aircraft_cabin_refit_plans_v1 r
 WHERE r.airline_id=p_airline AND r.aircraft_inventory_id=p_aircraft
  AND r.world_id=1;

 -- These final two Phase 1 capabilities cannot be inferred from a date-only
 -- verification receipt. Due/grounded status requires the signed game-time
 -- and maintenance-job execution/availability ledgers.
 blockers:=array_append(blockers,'MAINTENANCE_DUE_SCHEDULE_NOT_OPERATIONALLY_CONNECTED');
 blockers:=array_append(blockers,'MAINTENANCE_GROUNDING_AND_AVAILABILITY_NOT_CONNECTED');

 RETURN jsonb_build_object(
  'status','maintenance_verification_incomplete',
  'worldId',1,'gameDate',p_game_day,'aircraftRegistration',fleet_row.registration,
  'readOnly',true,'maintenanceReady',false,'dispatchApproved',false,
  'conditionEvidenceVerified',condition_proof,
  'manufactureYearVerified',manufacture_year_proof,
  'usageTrackingVerified',tracking_ready,
  'sinceAllocationHours',CASE WHEN tracking_ready
    THEN state_row.tracked_flight_hours ELSE NULL END,
  'sinceAllocationCycles',CASE WHEN tracking_ready
    THEN state_row.tracked_flight_cycles ELSE NULL END,
  'checkPolicies',expected_checks,'checkTypesWithVerifiedHistory',verified_check_types,
  'verifiedCheckRecords',completion_count,
  'unappliedRefitPlanCount',refit_plan_count,
  'checkDueEvaluationConnected',false,'groundingEvaluationConnected',false,
  'sourceKind','private_game_maintenance_records_not_player_claims',
  'blockers',to_jsonb(blockers),
  'aircraftConditionChanged',false,'maintenanceCompleted',false,
  'flightActivated',false,'movementRecorded',false,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_aircraft_maintenance_readiness_v1(
 uuid,uuid,uuid,date) FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION airlinerra_game.section9_owned_aircraft_maintenance_readiness_v1(
 uuid,uuid,uuid,date) IS
 'Authenticated owner-scoped read-only maintenance evidence gate; no invented condition/age/inspection; not a dispatch clearance.';
COMMIT;
