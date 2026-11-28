-- ROLLBACK-ONLY REVIEW. Restricted promotion to the real commercial plan schema.
-- Do not enable until commercial departure-time validation is storage-aware.
BEGIN;
CREATE TABLE airlinerra_game.storage_crew_plan_handoff_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.storage_crew_plan_handoff_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.storage_crew_plan_handoffs_v1(
 plan_id uuid PRIMARY KEY REFERENCES airlinerra_game.storage_aware_crew_plan_reviews_v1(plan_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),promoted_at timestamptz NOT NULL
);
ALTER TABLE airlinerra_game.storage_crew_plan_handoff_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.storage_crew_plan_handoffs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_crew_plan_handoff_release_v1,airlinerra_game.storage_crew_plan_handoffs_v1 FROM PUBLIC,anon,authenticated,service_role;

-- Exact reviewed duty only, never blanket release of an employee.
CREATE OR REPLACE FUNCTION airlinerra_game.guard_commercial_duty_against_storage_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s WHERE s.airline_id=NEW.airline_id AND s.employee_id=NEW.employee_id AND s.status<>'cancelled') THEN
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoff_release_v1 WHERE world_id=1 AND enabled)
  OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoffs_v1 h JOIN airlinerra_game.storage_aware_crew_plan_reviews_v1 r ON r.plan_id=h.plan_id AND r.airline_id=h.airline_id
   CROSS JOIN LATERAL jsonb_array_elements(r.verified_duties) d(v)
   WHERE h.plan_id=NEW.plan_id AND h.airline_id=NEW.airline_id AND v->>'employeeId'=NEW.employee_id::text
    AND (v->>'dutyStartUtc')::timestamptz=NEW.duty_start_utc AND (v->>'dutyEndUtc')::timestamptz=NEW.duty_end_utc
    AND v->>'startingAirport'=NEW.starting_airport AND v->>'endingAirport'=NEW.ending_airport)
  OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s
   LEFT JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d ON d.request_id=s.request_id AND d.employee_id=s.employee_id AND d.airline_id=s.airline_id
   WHERE s.airline_id=NEW.airline_id AND s.employee_id=NEW.employee_id AND s.status<>'cancelled'
   AND (s.status<>'awaiting_history_handoff' OR d.rest_complete_utc IS NULL OR d.rest_complete_utc>NEW.duty_start_utc OR d.rest_complete_utc>airlinerra_game.section9_verified_world_instant_v1()))
  THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='CREW_RESERVED_FOR_STORAGE_OR_HISTORY_HANDOFF';END IF;
 END IF;
 RETURN NEW;
END $fn$;

-- The legacy planner may not silently replace a history-aware plan.
CREATE FUNCTION airlinerra_game.guard_storage_handoff_plan_replacement_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF OLD.status='validated_preview' AND NEW.status IS DISTINCT FROM OLD.status AND EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoffs_v1 WHERE plan_id=OLD.plan_id AND airline_id=OLD.airline_id)
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_AWARE_REPLAN_REQUIRED';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_handoff_plan_replacement_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_storage_handoff_plan_replacement_v1 BEFORE UPDATE OF status ON airlinerra_game.section9_crew_plan_batches_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_handoff_plan_replacement_v1();

CREATE FUNCTION airlinerra_game.promote_storage_aware_crew_plan_review_v1(p_player uuid,p_airline uuid,p_plan uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; f record; snap jsonb; item jsonb; rot jsonb; emp jsonb; seat jsonb; v_now timestamptz; duty uuid; eid uuid; n int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.storage_aware_crew_plan_reviews_v1 WHERE plan_id=p_plan AND airline_id=p_airline FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_handoff_review_missing','promoted',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoffs_v1 WHERE plan_id=p_plan AND airline_id=p_airline) THEN
  RETURN jsonb_build_object('status','storage_handoff_already_promoted','promoted',true,'replayed',true,'crewReleased',false,'dispatchAuthorized',false);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoff_release_v1 WHERE world_id=1 AND enabled) THEN RETURN jsonb_build_object('status','storage_handoff_not_released','promoted',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 snap:=airlinerra_game.owned_storage_aware_crew_input_preview_v1(p_player,p_airline,r.window_start_utc);
 IF v_now IS NULL OR snap IS DISTINCT FROM r.source_snapshot OR snap->>'status' IS DISTINCT FROM 'storage_aware_crew_input_preview' THEN RETURN jsonb_build_object('status','storage_handoff_snapshot_changed','promoted',false);END IF;
 -- Replacing a current plan requires separate full coverage and in-progress duty reconciliation.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE airline_id=p_airline AND status='validated_preview') THEN RETURN jsonb_build_object('status','storage_handoff_existing_plan_requires_replan','promoted',false);END IF;
 INSERT INTO airlinerra_game.storage_crew_plan_handoffs_v1 VALUES(p_plan,p_airline,v_now);
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1(plan_id,airline_id,window_start_utc,window_end_utc,source_snapshot,proposed_assignments,status)
 VALUES(p_plan,p_airline,r.window_start_utc,r.window_start_utc+interval '168 hours',snap,r.assignments,'validated_preview');
 FOR item IN SELECT value FROM jsonb_array_elements(r.assignments) LOOP
  SELECT o.*,pol.qualification_group,pol.seat_basis INTO f
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version AND s.status='active'
  JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=s.configuration_id
  WHERE o.id=(item->>'flightId')::uuid AND o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled'
  AND o.aircraft_inventory_id=(item->>'aircraftId')::uuid AND o.departure_utc=(item->>'departureUtc')::timestamptz AND o.arrival_utc=(item->>'arrivalUtc')::timestamptz;
  IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(snap->'flights') a(v) WHERE v->>'id'=f.id::text AND v->>'origin'=f.origin_airport_key AND v->>'destination'=f.destination_airport_key AND v->>'group'=f.qualification_group)
  OR jsonb_array_length(item->'cabinCrew') IS DISTINCT FROM (CASE WHEN f.seat_basis='cargo_zero' OR f.verified_passenger_seats<=19 THEN 0 ELSE (f.verified_passenger_seats+49)/50 END)
  THEN RAISE EXCEPTION USING ERRCODE='PZ003',MESSAGE='storage_handoff_occurrence_changed';END IF;
  INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count)
  VALUES(p_plan,p_airline,f.id,f.schedule_version,f.aircraft_inventory_id,f.schedule_id||':'||f.flight_local_date||':'||f.weekly_entry,f.qualification_group,f.departure_utc,f.arrival_utc,f.origin_airport_key,f.destination_airport_key,jsonb_array_length(item->'captains'),jsonb_array_length(item->'firstOfficers'),jsonb_array_length(item->'cabinCrew'));
 END LOOP;
 FOR rot IN SELECT value FROM jsonb_array_elements(r.verified_duties) LOOP
  eid:=(rot->>'employeeId')::uuid;
  SELECT value INTO STRICT emp FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) WHERE value->>'id'=eid::text;
  IF (rot->>'dutyStartUtc')::timestamptz<v_now THEN RAISE EXCEPTION USING ERRCODE='PZ003',MESSAGE='storage_handoff_report_passed';END IF;
  INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(plan_id,airline_id,pilot_id,cabin_member_id,duty_start_utc,duty_end_utc,report_date,starting_airport,ending_airport)
  VALUES(p_plan,p_airline,CASE WHEN emp?'permissions' THEN eid END,CASE WHEN NOT emp?'permissions' THEN eid END,(rot->>'dutyStartUtc')::timestamptz,(rot->>'dutyEndUtc')::timestamptz,((rot->>'dutyStartUtc')::timestamptz AT TIME ZONE (emp->>'baseTimezone'))::date,rot->>'startingAirport',rot->>'endingAirport') RETURNING duty_id INTO duty;
  FOR item IN SELECT value FROM jsonb_array_elements(r.assignments) LOOP
   FOR seat IN SELECT value FROM jsonb_array_elements(item->'duties') WHERE value->>'employeeId'=eid::text AND (value->>'dutyStartUtc')::timestamptz=(rot->>'dutyStartUtc')::timestamptz LOOP
    INSERT INTO airlinerra_game.section9_planned_crew_seats_v1(plan_id,airline_id,occurrence_id,duty_id,employee_id,seat_role)
    VALUES(p_plan,p_airline,(item->>'flightId')::uuid,duty,eid,CASE seat->>'role' WHEN 'firstOfficer' THEN 'first_officer' ELSE seat->>'role' END);
   END LOOP;
  END LOOP;
 END LOOP;
 SELECT count(*) INTO n FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=p_plan;
 IF n IS DISTINCT FROM (SELECT sum(jsonb_array_length(v->'duties'))::int FROM jsonb_array_elements(r.assignments) a(v)) THEN RAISE EXCEPTION USING ERRCODE='PZ003',MESSAGE='storage_handoff_seat_mismatch';END IF;
 RETURN jsonb_build_object('status','storage_handoff_promoted','planId',p_plan,'promoted',true,'replayed',false,'crewReleased',false,'dispatchAuthorized',false,'seatCount',n);
EXCEPTION WHEN SQLSTATE 'PZ003' OR unique_violation OR check_violation OR foreign_key_violation THEN RETURN jsonb_build_object('status','storage_handoff_rolled_back','promoted',false,'crewReleased',false,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.promote_storage_aware_crew_plan_review_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
