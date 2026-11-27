-- ROLLBACK-ONLY REVIEW. Retire a fully completed handoff plan without
-- deleting its operated records. Storage custody itself remains retained.
BEGIN;
CREATE TABLE airlinerra_game.storage_commercial_plan_retirement_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.storage_commercial_plan_retirement_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.storage_commercial_plan_retirements_v1(
 plan_id uuid PRIMARY KEY REFERENCES airlinerra_game.storage_crew_plan_handoffs_v1(plan_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 retired_at timestamptz NOT NULL,flight_count int NOT NULL CHECK(flight_count>0),
 duty_count int NOT NULL CHECK(duty_count>0),evidence jsonb NOT NULL CHECK(jsonb_typeof(evidence)='array' AND jsonb_array_length(evidence)=flight_count)
);
ALTER TABLE airlinerra_game.storage_commercial_plan_retirement_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.storage_commercial_plan_retirements_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_commercial_plan_retirement_release_v1,airlinerra_game.storage_commercial_plan_retirements_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER storage_commercial_plan_retirement_immutable BEFORE UPDATE OR DELETE ON airlinerra_game.storage_commercial_plan_retirements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1();

-- Protect the exact rows that historical bindings read, including all seats
-- of a previously started rotation. BEFORE triggers use ordinary keys,
-- not the generated employee_id of a pending row.
CREATE FUNCTION airlinerra_game.guard_operated_storage_commercial_history_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE k jsonb;keys jsonb:='[]';pid uuid;oid uuid;did uuid;event_id text;physical text;
BEGIN
 IF TG_OP<>'INSERT' THEN keys:=keys||jsonb_build_array(to_jsonb(OLD));END IF;
 IF TG_OP<>'DELETE' THEN keys:=keys||jsonb_build_array(to_jsonb(NEW));END IF;
 FOR k IN SELECT value FROM jsonb_array_elements(keys) LOOP
  pid:=(k->>'plan_id')::uuid;oid:=(k->>'occurrence_id')::uuid;did:=(k->>'duty_id')::uuid;
  event_id:=k->>'departure_event_id';physical:=k->>'physical_flight_id';
  IF TG_TABLE_NAME IN('storage_aware_crew_plan_reviews_v1','storage_crew_plan_handoffs_v1','section9_crew_plan_batches_v1') THEN
   IF EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_departure_crew_evidence_v1 e WHERE e.plan_id=pid) THEN
    IF TG_TABLE_NAME='section9_crew_plan_batches_v1' AND TG_OP='UPDATE' AND (to_jsonb(NEW)-'status')=(to_jsonb(OLD)-'status')
    AND to_jsonb(OLD)->>'status'='validated_preview' AND to_jsonb(NEW)->>'status'='superseded' AND EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_plan_retirements_v1 t WHERE t.plan_id=pid AND t.airline_id=(to_jsonb(OLD)->>'airline_id')::uuid) THEN CONTINUE;END IF;
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_OPERATED_COMMERCIAL_HISTORY_IMMUTABLE';
   END IF;
  ELSIF TG_TABLE_NAME IN('section9_operated_crew_bindings_v1','section9_pilot_departure_manifests_v1') THEN
   -- The binding adapter must be able to insert the initial records.
   IF TG_OP<>'INSERT' AND EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_departure_crew_evidence_v1 e WHERE e.departure_event_id=event_id OR e.physical_flight_id=physical) THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_OPERATED_COMMERCIAL_HISTORY_IMMUTABLE';END IF;
  ELSIF EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_departure_crew_evidence_v1 e WHERE e.plan_id=pid AND
    (e.occurrence_id=oid OR (did IS NOT NULL AND EXISTS(SELECT 1 FROM jsonb_array_elements(e.normalized_duties) v WHERE v#>>'{duty,duty_id}'=did::text))))
  THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_OPERATED_COMMERCIAL_HISTORY_IMMUTABLE';
  END IF;
 END LOOP;
 IF TG_OP='DELETE' THEN RETURN OLD;END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_operated_storage_commercial_history_v1() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.guard_storage_handoff_plan_replacement_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF OLD.status='validated_preview' AND NEW.status IS DISTINCT FROM OLD.status AND EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoffs_v1 WHERE plan_id=OLD.plan_id AND airline_id=OLD.airline_id)
 AND NOT(NEW.status='superseded' AND EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_plan_retirements_v1 WHERE plan_id=OLD.plan_id AND airline_id=OLD.airline_id))
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_AWARE_REPLAN_REQUIRED';END IF;
 IF OLD.status='superseded' AND NEW.status IS DISTINCT FROM OLD.status AND EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_plan_retirements_v1 WHERE plan_id=OLD.plan_id AND airline_id=OLD.airline_id) THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_RETIRED_PLAN_CANNOT_REACTIVATE';END IF;
 RETURN NEW;
END $fn$;

CREATE FUNCTION airlinerra_game.retire_completed_storage_commercial_plan_v1(p_player uuid,p_airline uuid,p_plan uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE b record;f record;e record;dep record;arr record;now_utc timestamptz;coverage jsonb;proof jsonb:='[]'::jsonb;n int:=0;nd int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO b FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE plan_id=p_plan AND airline_id=p_airline FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoffs_v1 WHERE plan_id=p_plan AND airline_id=p_airline) THEN RETURN jsonb_build_object('status','storage_retirement_plan_missing','retired',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_plan_retirements_v1 WHERE plan_id=p_plan AND airline_id=p_airline) AND b.status='superseded' THEN RETURN jsonb_build_object('status','storage_commercial_plan_retired','retired',true,'replayed',true,'crewCustodyReleased',false);END IF;
 IF b.status<>'validated_preview' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_plan_retirement_release_v1 WHERE world_id=1 AND enabled) THEN RETURN jsonb_build_object('status','storage_retirement_not_released','retired',false);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR NOT isfinite(now_utc) THEN RETURN jsonb_build_object('status','storage_retirement_clock_unverified','retired',false);END IF;
 SELECT count(*) INTO nd FROM airlinerra_game.section9_planned_crew_duties_v1 WHERE plan_id=p_plan AND airline_id=p_airline;
 IF nd=0 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 d WHERE d.plan_id=p_plan AND d.airline_id=p_airline AND (d.duty_end_utc+interval '12 hours'>now_utc OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=d.plan_id AND s.airline_id=d.airline_id AND s.duty_id=d.duty_id))) THEN RETURN jsonb_build_object('status','storage_retirement_duty_not_rested','retired',false);END IF;
 FOR f IN SELECT * FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=p_plan AND airline_id=p_airline ORDER BY departure_utc,occurrence_id LOOP
  SELECT * INTO e FROM airlinerra_game.storage_commercial_departure_crew_evidence_v1 WHERE plan_id=p_plan AND airline_id=p_airline AND occurrence_id=f.occurrence_id AND physical_flight_id=f.physical_flight_id;
  IF NOT FOUND OR airlinerra_game.storage_commercial_departure_binding_exact_v1(e.departure_event_id) IS DISTINCT FROM true THEN RETURN jsonb_build_object('status','storage_retirement_binding_missing','retired',false);END IF;
  SELECT * INTO STRICT dep FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=e.departure_event_id;
  SELECT * INTO arr FROM airlinerra_game.section9_operated_flight_movements_v1 a WHERE a.airline_id=p_airline AND a.flight_occurrence_id=f.physical_flight_id AND a.phase='arrived' AND a.storage_request_id IS NULL AND a.world_id=dep.world_id AND a.aircraft_inventory_id=dep.aircraft_inventory_id AND a.schedule_id=dep.schedule_id AND a.schedule_version=dep.schedule_version AND a.weekly_entry=dep.weekly_entry AND a.flight_local_date=dep.flight_local_date AND a.origin_airport_key=dep.origin_airport_key AND a.destination_airport_key=dep.destination_airport_key;
  IF NOT FOUND OR arr.actual_event_utc<>f.arrival_utc OR arr.actual_event_utc+interval '12 hours 30 minutes'>now_utc
  OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 fuel WHERE fuel.physical_flight_id=f.physical_flight_id AND fuel.airline_id=p_airline AND fuel.aircraft_inventory_id=dep.aircraft_inventory_id AND fuel.arrival_engine_event_id=arr.engine_event_id)
  OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 u WHERE u.physical_flight_id=f.physical_flight_id AND u.airline_id=p_airline AND u.aircraft_inventory_id=dep.aircraft_inventory_id AND u.arrived_engine_event_id=arr.engine_event_id AND u.departed_engine_event_id=dep.engine_event_id)
  THEN RETURN jsonb_build_object('status','storage_retirement_arrival_or_rest_unverified','retired',false);END IF;
  proof:=proof||jsonb_build_array(jsonb_build_object('physicalFlightId',f.physical_flight_id,'departureEventId',dep.engine_event_id,'arrivalEventId',arr.engine_event_id));
  n:=n+1;
 END LOOP;
 IF n=0 OR n<>(SELECT jsonb_array_length(assignments) FROM airlinerra_game.storage_aware_crew_plan_reviews_v1 WHERE plan_id=p_plan AND airline_id=p_airline) THEN RETURN jsonb_build_object('status','storage_retirement_plan_incomplete','retired',false);END IF;
 coverage:=airlinerra_game.storage_rolling_crew_coverage_v1(p_airline,now_utc);
 IF coverage->>'coverageVerified' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','storage_retirement_history_unverified','retired',false);END IF;
 INSERT INTO airlinerra_game.storage_commercial_plan_retirements_v1 VALUES(p_plan,p_airline,now_utc,n,nd,proof);
 UPDATE airlinerra_game.section9_crew_plan_batches_v1 SET status='superseded' WHERE plan_id=p_plan AND airline_id=p_airline;
 RETURN jsonb_build_object('status','storage_commercial_plan_retired','retired',true,'replayed',false,'flightCount',n,'dutyCount',nd,'crewCustodyReleased',false,'historyPreserved',true);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.retire_completed_storage_commercial_plan_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
