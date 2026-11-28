-- ROLLBACK-ONLY REVIEW. Retain completed history while releasing active
-- custody. Commercial planning remains storage-aware even after release.
BEGIN;
CREATE TABLE airlinerra_game.storage_crew_custody_release_policy_v1(world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false);
INSERT INTO airlinerra_game.storage_crew_custody_release_policy_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.storage_crew_custody_releases_v1(
 request_id uuid NOT NULL,employee_id uuid NOT NULL,airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 departure_event_id text NOT NULL REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 arrival_event_id text NOT NULL REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 released_at timestamptz NOT NULL,last_airport text NOT NULL,history_snapshot jsonb NOT NULL,
 PRIMARY KEY(request_id,employee_id),FOREIGN KEY(request_id,employee_id) REFERENCES airlinerra_game.aircraft_storage_crew_reservations_v1(request_id,employee_id)
);
ALTER TABLE airlinerra_game.storage_crew_custody_release_policy_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.storage_crew_custody_releases_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_crew_custody_release_policy_v1,airlinerra_game.storage_crew_custody_releases_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER storage_crew_custody_release_immutable BEFORE UPDATE OR DELETE ON airlinerra_game.storage_crew_custody_releases_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1();
ALTER TABLE airlinerra_game.aircraft_storage_crew_reservations_v1 DROP CONSTRAINT aircraft_storage_crew_reservations_v1_status_check;
ALTER TABLE airlinerra_game.aircraft_storage_crew_reservations_v1 ADD CONSTRAINT aircraft_storage_crew_reservations_v1_status_check CHECK(status IN('reserved','cancelled','awaiting_history_handoff','history_released'));
DROP INDEX airlinerra_game.storage_crew_exclusive_custody_v1;
CREATE UNIQUE INDEX storage_crew_exclusive_custody_v1 ON airlinerra_game.aircraft_storage_crew_reservations_v1(airline_id,employee_id) WHERE status IN('reserved','awaiting_history_handoff');
CREATE TRIGGER storage_crew_reservation_no_delete_v1 BEFORE DELETE ON airlinerra_game.aircraft_storage_crew_reservations_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1();
CREATE FUNCTION airlinerra_game.storage_crew_custody_release_enabled_v1()
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
BEGIN
 RETURN current_user='postgres'
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_custody_release_policy_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_combined_booking_history_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoff_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_binding_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_departure_validation_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_crew_custody_release_enabled_v1() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.guard_storage_crew_reservation_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;now_utc timestamptz;
BEGIN
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id FOR UPDATE;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=NEW.request_id AND airline_id=NEW.airline_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_CREW_REQUEST_MISMATCH';END IF;
 IF TG_OP='UPDATE' AND NEW.status='history_released' THEN
  IF OLD.status<>'awaiting_history_handoff' OR (to_jsonb(NEW)-'status') IS DISTINCT FROM (to_jsonb(OLD)-'status') OR r.status<>'completed'
  OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_custody_releases_v1 e JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d ON d.request_id=e.request_id AND d.employee_id=e.employee_id AND d.airline_id=e.airline_id
   WHERE e.request_id=OLD.request_id AND e.employee_id=OLD.employee_id AND e.airline_id=OLD.airline_id AND e.departure_event_id=d.departure_engine_event_id AND e.arrival_event_id=d.arrival_engine_event_id AND e.released_at>=d.rest_complete_utc AND e.released_at=airlinerra_game.section9_verified_world_instant_v1())
  OR NOT airlinerra_game.storage_crew_custody_release_enabled_v1() THEN RAISE EXCEPTION 'STORAGE_CREW_RELEASE_EVIDENCE_INVALID';END IF;
  RETURN NEW;
 END IF;
 IF TG_OP='INSERT' THEN
  now_utc:=airlinerra_game.section9_verified_world_instant_v1();
  IF now_utc IS NULL OR NEW.status<>'reserved' OR NEW.reserved_at<>now_utc OR NEW.duty_start_utc<now_utc
   OR r.status NOT IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review') OR NEW.origin_airport_key<>r.origin_airport_key OR NEW.destination_airport_key<>r.destination_airport_key
   OR NEW.duty_start_utc>r.departure_utc OR NEW.duty_end_utc<r.arrival_utc
   OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='departed')
   OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=NEW.airline_id AND pd.employee_id=NEW.employee_id AND pd.duty_end_utc>now_utc)
  THEN RAISE EXCEPTION 'STORAGE_CREW_RESERVATION_CONFLICT';END IF;
 ELSE
  IF (to_jsonb(NEW)-'status') IS DISTINCT FROM (to_jsonb(OLD)-'status') OR OLD.status<>'reserved' THEN RAISE EXCEPTION 'STORAGE_CREW_RESERVATION_IMMUTABLE';END IF;
  IF NEW.status='cancelled' THEN
   IF r.status<>'cancelled' OR airlinerra_game.section9_verified_world_instant_v1() IS NULL OR airlinerra_game.section9_verified_world_instant_v1()>=OLD.duty_start_utc OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='departed') THEN RAISE EXCEPTION 'STORAGE_CREW_CANCELLATION_NOT_VERIFIED';END IF;
  ELSIF NEW.status='awaiting_history_handoff' THEN
   IF r.status<>'completed' AND r.status<>'cancelled' THEN RAISE EXCEPTION 'STORAGE_CREW_HANDOFF_NOT_READY';END IF;
  ELSE RAISE EXCEPTION 'STORAGE_CREW_STATUS_INVALID';END IF;
 END IF;
 RETURN NEW;
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.storage_signed_crew_departure_covered_v1(p_airline uuid,p_event text)
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE m record;r record;d record;a record;actual_seats jsonb;completed boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO m FROM airlinerra_game.storage_signed_crew_manifests_v1 WHERE departure_event_id=p_event AND airline_id=p_airline;
 IF NOT FOUND THEN RETURN false;END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=m.request_id AND airline_id=p_airline;
 IF NOT FOUND OR r.status NOT IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review','completed') OR (r.quote->>'configurationId')::bigint IS DISTINCT FROM m.configuration_id THEN RETURN false;END IF;
 SELECT * INTO d FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=p_event AND phase='departed' AND storage_request_id=r.id AND airline_id=p_airline AND aircraft_inventory_id=r.aircraft_inventory_id AND flight_occurrence_id=m.physical_flight_id AND origin_airport_key=r.origin_airport_key AND destination_airport_key=r.destination_airport_key AND actual_event_utc=r.departure_utc AND scheduled_departure_utc=r.departure_utc AND scheduled_arrival_utc=r.arrival_utc;
 IF NOT FOUND THEN RETURN false;END IF;
 completed:=r.status='completed';
 SELECT * INTO a FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='arrived' AND airline_id=p_airline AND aircraft_inventory_id=r.aircraft_inventory_id AND flight_occurrence_id=m.physical_flight_id AND origin_airport_key=r.origin_airport_key AND destination_airport_key=r.destination_airport_key AND actual_event_utc=r.arrival_utc AND scheduled_departure_utc=r.departure_utc AND scheduled_arrival_utc=r.arrival_utc;
 IF completed AND NOT FOUND THEN RETURN false;END IF;
 IF NOT completed AND EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='arrived') THEN RETURN false;END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('employeeId',s.employee_id,'role',s.seat_role,'reportUtc',s.duty_start_utc,'endUtc',s.duty_end_utc) ORDER BY s.employee_id),'[]'::jsonb) INTO actual_seats
 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s
 JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 c ON c.request_id=s.request_id AND c.employee_id=s.employee_id AND c.airline_id=s.airline_id
 WHERE s.request_id=r.id AND s.airline_id=p_airline AND s.qualification_group=m.qualification_group
 AND (CASE WHEN completed THEN s.status='awaiting_history_handoff' OR (s.status='history_released' AND EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_custody_releases_v1 e WHERE e.request_id=s.request_id AND e.employee_id=s.employee_id AND e.airline_id=s.airline_id AND e.departure_event_id=c.departure_engine_event_id AND e.arrival_event_id=c.arrival_engine_event_id AND e.released_at>=c.rest_complete_utc)) ELSE s.status='reserved' END)
 AND s.origin_airport_key=r.origin_airport_key AND s.destination_airport_key=r.destination_airport_key
 AND c.departure_engine_event_id=p_event AND c.actual_departure_utc=d.actual_event_utc AND c.reported_duty_start_utc=s.duty_start_utc
 AND c.origin_airport_key=s.origin_airport_key AND c.destination_airport_key=s.destination_airport_key
 AND (CASE WHEN completed THEN c.arrival_engine_event_id=a.engine_event_id AND c.actual_arrival_utc=a.actual_event_utc AND c.completed_duty_end_utc=a.actual_event_utc+make_interval(mins=>m.postflight_minutes) AND c.completed_duty_end_utc=s.duty_end_utc AND c.rest_complete_utc=c.completed_duty_end_utc+make_interval(mins=>m.rest_minutes)
 ELSE c.arrival_engine_event_id IS NULL AND c.actual_arrival_utc IS NULL AND c.completed_duty_end_utc IS NULL AND c.rest_complete_utc IS NULL END);
 RETURN actual_seats=m.seats AND jsonb_array_length(actual_seats)=(SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id)
 AND jsonb_array_length(actual_seats)=(SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=r.id);
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.owned_storage_crew_history_input_review_v1(p_player uuid,p_airline uuid,p_at timestamptz,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE base jsonb;legacy jsonb;coverage jsonb;member jsonb;h jsonb;pilots jsonb:='[]';cabin jsonb:='[]';excluded jsonb:='[]';now_utc timestamptz;kind text;eid uuid;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR NOT isfinite(now_utc) OR p_at IS DISTINCT FROM now_utc THEN RETURN jsonb_build_object('status','storage_history_clock_invalid','historyIntegrated',false);END IF;
 IF p_request IS NOT NULL AND NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r WHERE r.id=p_request AND r.airline_id=p_airline AND r.owner_player_id=p_player AND r.status IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review') AND now_utc>=r.departure_utc AND now_utc<r.departure_utc+interval '10 minutes' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.storage_request_id=r.id)) THEN RETURN jsonb_build_object('status','storage_history_request_exemption_invalid','historyIntegrated',false);END IF;
 coverage:=airlinerra_game.storage_rolling_crew_coverage_v1(p_airline,now_utc);
 legacy:=airlinerra_game.section9_owned_rolling_crew_input_v1(p_player,p_airline,now_utc);
 base:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,now_utc);
 IF coverage->>'coverageVerified' IS DISTINCT FROM 'true' OR legacy->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR legacy->>'alreadyReportedFutureFlights' IS DISTINCT FROM '0'
 OR legacy->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR base->>'status' IS DISTINCT FROM 'weekly_crew_bootstrap_input_preview' OR base->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR base->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true'
 OR jsonb_typeof(base->'pilots') IS DISTINCT FROM 'array' OR jsonb_typeof(base->'cabinMembers') IS DISTINCT FROM 'array'
 THEN RETURN jsonb_build_object('status','storage_history_input_unverified','historyIntegrated',false,'coverage',coverage);END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements((base->'pilots')||(base->'cabinMembers')) a(v) GROUP BY v->>'id' HAVING count(*)<>1 OR v->>'id' IS NULL) THEN RETURN jsonb_build_object('status','storage_history_duplicate_employee','historyIntegrated',false);END IF;
 FOREACH kind IN ARRAY ARRAY['pilots','cabinMembers'] LOOP
  FOR member IN SELECT value FROM jsonb_array_elements(base->kind) LOOP
   eid:=(member->>'id')::uuid;
   -- Departure checks only the exact reserved employees. Candidate
   -- selection (null request) excludes all active custody, including rested
   -- awaiting-handoff employees until a separate release is approved.
   IF p_request IS NOT NULL AND NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=p_request AND airline_id=p_airline AND employee_id=eid AND status='reserved') THEN CONTINUE;END IF;
   IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 c WHERE c.airline_id=p_airline AND c.employee_id=eid AND c.status IN('reserved','awaiting_history_handoff') AND (p_request IS NULL OR c.request_id<>p_request)) THEN excluded:=excluded||jsonb_build_array(jsonb_build_object('employeeId',eid,'status','storage_crew_custody_retained'));CONTINUE;END IF;
   h:=airlinerra_game.storage_crew_history_for_booking_review_v1(p_airline,eid,now_utc,member->>'initialAirport',(member->>'locationEffectiveUtc')::timestamptz,p_request);
   IF h->>'status' IS DISTINCT FROM 'combined_crew_history_preview' OR h->>'eligibleByHistory' IS DISTINCT FROM 'true' THEN excluded:=excluded||jsonb_build_array(jsonb_build_object('employeeId',eid,'status',h->>'status'));CONTINUE;END IF;
   member:=jsonb_set(member,'{history}',h->'history');
   IF kind='pilots' THEN pilots:=pilots||jsonb_build_array(member);ELSE cabin:=cabin||jsonb_build_array(member);END IF;
  END LOOP;
 END LOOP;
 RETURN base||jsonb_build_object('status','storage_crew_history_input_review','pilots',pilots,'cabinMembers',cabin,'excludedEmployees',excluded,'planningCutoffUtc',now_utc,'unboundDeparturesLast7Days',coverage->'unboundDeparturesLast7Days','unresolvedCaptureIssues',coverage->'unresolvedCaptureIssues','alreadyReportedFutureFlights',0,'historyIncluded',true,'crewReleased',false,'dispatchAuthorized',false);
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR invalid_parameter_value THEN RETURN jsonb_build_object('status','storage_history_input_invalid','historyIntegrated',false);
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.confirm_crew_bound_storage_booking_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz,p_expected_cost numeric,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE q jsonb;j jsonb;old record;r record;rid uuid;crew_count int;expected_count int;now_utc timestamptz;stage text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE a.id=p_airline AND a.world_id=1 AND a.owner_player_id=p_player FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO old FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE airline_id=p_airline AND request_key=p_request_key FOR UPDATE;
 IF FOUND THEN
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=old.id AND airline_id=p_airline) THEN RETURN jsonb_build_object('status','storage_crew_booking_not_confirmed','booked',false);END IF;
  RETURN airlinerra_game.confirm_owned_aircraft_storage_booking_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure,p_expected_cost,p_request_key);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_booking_release_v1 WHERE world_id=1 AND enabled) THEN RETURN jsonb_build_object('status','storage_crew_booking_not_released','booked',false);END IF;
 q:=airlinerra_game.owned_aircraft_storage_crew_candidates_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
 IF q->>'status' IS DISTINCT FROM 'storage_crew_candidates_found' THEN RETURN jsonb_build_object('status',coalesce(q->>'status','storage_crew_unavailable'),'booked',false);END IF;
 IF jsonb_array_length(q->'candidateCaptains') IS DISTINCT FROM (q->>'captainsRequired')::int OR jsonb_array_length(q->'candidateFirstOfficers') IS DISTINCT FROM (q->>'firstOfficersRequired')::int OR jsonb_array_length(q->'candidateCabinCrew') IS DISTINCT FROM (q->>'minimumCabinCrew')::int THEN RETURN jsonb_build_object('status','storage_crew_count_mismatch','booked',false);END IF;
 expected_count:=(q->>'captainsRequired')::int+(q->>'firstOfficersRequired')::int+(q->>'minimumCabinCrew')::int;
 IF expected_count<2 OR expected_count IS NULL OR expected_count IS DISTINCT FROM (SELECT count(DISTINCT value)::int FROM jsonb_array_elements((q->'candidateCaptains')||(q->'candidateFirstOfficers')||(q->'candidateCabinCrew'))) THEN RETURN jsonb_build_object('status','storage_crew_count_mismatch','booked',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s WHERE s.airline_id=p_airline AND s.status IN('reserved','awaiting_history_handoff') AND s.employee_id::text IN(SELECT jsonb_array_elements_text((q->'candidateCaptains')||(q->'candidateFirstOfficers')||(q->'candidateCabinCrew')))) THEN RETURN jsonb_build_object('status','storage_crew_already_reserved','booked',false);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL THEN RETURN jsonb_build_object('status','storage_clock_unverified','booked',false);END IF;
 BEGIN
  j:=airlinerra_game.confirm_owned_aircraft_storage_booking_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure,p_expected_cost,p_request_key);
  IF j->>'booked' IS DISTINCT FROM 'true' THEN RETURN j;END IF;
  rid:=(j->>'requestId')::uuid;
  SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=rid AND airline_id=p_airline AND aircraft_inventory_id=p_aircraft;
  IF q#>>'{rotation,startingAirport}' IS DISTINCT FROM r.origin_airport_key OR q#>>'{rotation,endingAirport}' IS DISTINCT FROM r.destination_airport_key OR (q#>>'{rotation,dutyStartUtc}')::timestamptz>r.departure_utc OR (q#>>'{rotation,dutyEndUtc}')::timestamptz<r.arrival_utc THEN RAISE EXCEPTION USING ERRCODE='PZ002',MESSAGE='storage_crew_rotation_changed';END IF;
  INSERT INTO airlinerra_game.aircraft_storage_crew_reservations_v1(request_id,airline_id,employee_id,seat_role,qualification_group,duty_start_utc,duty_end_utc,origin_airport_key,destination_airport_key,reserved_at)
  SELECT rid,p_airline,employee::uuid,role,q->>'qualificationGroup',(q#>>'{rotation,dutyStartUtc}')::timestamptz,(q#>>'{rotation,dutyEndUtc}')::timestamptz,r.origin_airport_key,r.destination_airport_key,now_utc
  FROM (SELECT jsonb_array_elements_text(q->'candidateCaptains') employee,'captain' role UNION ALL SELECT jsonb_array_elements_text(q->'candidateFirstOfficers'),'first_officer' UNION ALL SELECT jsonb_array_elements_text(q->'candidateCabinCrew'),'cabin') seats ORDER BY employee;
  GET DIAGNOSTICS crew_count=ROW_COUNT;
  IF crew_count<>expected_count THEN RAISE EXCEPTION USING ERRCODE='PZ002',MESSAGE='storage_crew_count_mismatch';END IF;
  RETURN j||jsonb_build_object('crewReserved',true,'crewCount',crew_count);
 EXCEPTION WHEN SQLSTATE 'PZ002' OR unique_violation OR check_violation THEN
  RETURN jsonb_build_object('status','storage_crew_reservation_failed','booked',false,'crewReserved',false);
 END;
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.storage_crew_departure_check_v1(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE r record;c record;model record;pol record;inp jsonb;member jsonb;rot jsonb;now_utc timestamptz;ds timestamptz;de timestamptz;expected int;nc int;nf int;na int;matched int;cfg bigint;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request;
 IF NOT FOUND OR r.status NOT IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review') THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_request_invalid');END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR now_utc<r.departure_utc OR now_utc>=r.departure_utc+interval '10 minutes' THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_departure_window_invalid');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=r.airline_id AND a.owner_player_id=r.owner_player_id AND a.world_id=1) THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_owner_invalid');END IF;
 SELECT configuration_id INTO cfg FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id AND ownership_type='owned';
 IF NOT FOUND OR cfg IS DISTINCT FROM (r.quote->>'configurationId')::bigint THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_configuration_changed');END IF;
 SELECT * INTO model FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=cfg;
 IF NOT FOUND OR model.minimum_cabin_crew IS NULL OR model.minimum_cabin_crew<0 OR nullif(btrim(model.qualification_group),'') IS NULL THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_model_invalid');END IF;
 SELECT * INTO pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF NOT FOUND OR pol.preflight_minutes IS NULL OR pol.preflight_minutes<0 OR pol.postflight_minutes IS NULL OR pol.postflight_minutes<0 OR pol.minimum_rest_minutes IS DISTINCT FROM 720 THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_policy_invalid');END IF;
 ds:=r.departure_utc-make_interval(mins=>pol.preflight_minutes);de:=r.arrival_utc+make_interval(mins=>pol.postflight_minutes);
 rot:=airlinerra_game.section9_crew_rotation_window_v2(jsonb_build_array(jsonb_build_object('originAirportKey',r.origin_airport_key,'destinationAirportKey',r.destination_airport_key,'departureUtc',to_char(r.departure_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'arrivalUtc',to_char(r.arrival_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))));
 IF rot->>'status' IS DISTINCT FROM 'rotation_preview' OR (rot->>'dutyStartUtc')::timestamptz IS DISTINCT FROM ds OR (rot->>'dutyEndUtc')::timestamptz IS DISTINCT FROM de THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_rotation_invalid');END IF;
 expected:=CASE WHEN r.arrival_utc-r.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 SELECT count(*) FILTER(WHERE seat_role='captain'),count(*) FILTER(WHERE seat_role='first_officer'),count(*) FILTER(WHERE seat_role='cabin') INTO nc,nf,na FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id;
 IF nc<>expected OR nf<>expected OR na<>model.minimum_cabin_crew THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_manifest_incomplete');END IF;
 inp:=airlinerra_game.storage_crew_selected_history_input_v1(r.owner_player_id,r.airline_id,now_utc,r.id);
 IF inp->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR inp->>'unboundDeparturesLast7Days' IS DISTINCT FROM '0' OR inp->>'unresolvedCaptureIssues' IS DISTINCT FROM '0' OR inp->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR inp->>'alreadyReportedFutureFlights' IS DISTINCT FROM '0' OR inp->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR jsonb_typeof(inp->'pilots') IS DISTINCT FROM 'array' OR jsonb_typeof(inp->'cabinMembers') IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_current_history_unverified');END IF;
 FOR c IN SELECT * FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id ORDER BY employee_id LOOP
  IF c.airline_id<>r.airline_id OR c.status<>'reserved' OR c.qualification_group<>model.qualification_group OR c.duty_start_utc<>ds OR c.duty_end_utc<>de OR c.origin_airport_key<>r.origin_airport_key OR c.destination_airport_key<>r.destination_airport_key THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_manifest_changed');END IF;
  -- Until both schedulers consume completed ferry history, do not accept
  -- an employee with any previous non-cancelled storage custody.
  IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s WHERE s.airline_id=r.airline_id AND s.employee_id=c.employee_id AND s.request_id<>r.id AND s.status IN('reserved','awaiting_history_handoff')) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=r.airline_id AND pd.employee_id=c.employee_id AND pd.duty_end_utc>ds) THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_conflicting_custody');END IF;
  SELECT count(*) INTO matched FROM jsonb_array_elements((inp->'pilots')||(inp->'cabinMembers')) a(v) WHERE v->>'id'=c.employee_id::text;
  IF matched<>1 THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_employment_changed');END IF;
  SELECT value INTO member FROM jsonb_array_elements(CASE WHEN c.seat_role='cabin' THEN inp->'cabinMembers' ELSE inp->'pilots' END) WHERE value->>'id'=c.employee_id::text;
  IF NOT FOUND OR airlinerra_game.aircraft_storage_crew_candidate_fit_v1(member,rot,c.qualification_group,c.seat_role) IS DISTINCT FROM true THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_duty_or_qualification_changed');END IF;
 END LOOP;
 RETURN jsonb_build_object('passed',true,'status','storage_crew_departure_revalidated','crewCount',nc+nf+na,'checkedAtUtc',now_utc,'dispatchAuthorized',false);
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.storage_crew_selected_history_input_v1(p_player uuid,p_airline uuid,p_at timestamptz,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE j jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_combined_booking_history_release_v1 WHERE world_id=1 AND enabled) THEN
  IF EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_custody_releases_v1 WHERE airline_id=p_airline) THEN RETURN jsonb_build_object('status','storage_combined_history_required','historyIncluded',false);END IF;
  RETURN airlinerra_game.section9_owned_rolling_crew_input_v1(p_player,p_airline,p_at);
 END IF;
 j:=airlinerra_game.owned_storage_crew_history_input_review_v1(p_player,p_airline,p_at,p_request);
 IF j->>'status' IS DISTINCT FROM 'storage_crew_history_input_review' OR j->>'historyIncluded' IS DISTINCT FROM 'true' OR j->>'crewReleased' IS DISTINCT FROM 'false' OR j->>'dispatchAuthorized' IS DISTINCT FROM 'false' OR j->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR j->>'unboundDeparturesLast7Days' IS DISTINCT FROM '0' OR j->>'unresolvedCaptureIssues' IS DISTINCT FROM '0' THEN
  RETURN jsonb_build_object('status','storage_combined_history_unverified','historyIncluded',false);
 END IF;
 RETURN j||jsonb_build_object('status','rolling_crew_input_preview');
END $fn$;

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
   AND (s.status NOT IN('awaiting_history_handoff','history_released') OR d.rest_complete_utc IS NULL OR d.rest_complete_utc>NEW.duty_start_utc OR d.rest_complete_utc>airlinerra_game.section9_verified_world_instant_v1()))
  THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='CREW_RESERVED_FOR_STORAGE_OR_HISTORY_HANDOFF';END IF;
 END IF;
 RETURN NEW;
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.storage_commercial_crew_departure_readiness_v1(p_airline uuid,p_physical text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE f record;r record;seat record;model record;owner_id uuid;now_utc timestamptz;roster jsonb;member jsonb;h jsonb;rot jsonb;assignment jsonb;coverage jsonb;n int;nc int;nf int;na int;expected int;review_seats jsonb;actual_seats jsonb;prefix jsonb;duty_leg jsonb;history_at timestamptz;multileg boolean:=false;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT a.owner_player_id INTO owner_id FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.world_id=1;
 IF NOT FOUND THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_owner_invalid');END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT pf.* INTO STRICT f FROM airlinerra_game.section9_planned_flight_crews_v1 pf
 JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview'
 JOIN airlinerra_game.storage_crew_plan_handoffs_v1 h ON h.plan_id=pf.plan_id AND h.airline_id=pf.airline_id
 WHERE pf.airline_id=p_airline AND pf.physical_flight_id=p_physical;
 IF now_utc IS NULL OR NOT isfinite(now_utc) OR now_utc<f.departure_utc OR now_utc>=f.departure_utc+interval '10 minutes' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_departure_window_invalid');END IF;
 SELECT * INTO STRICT r FROM airlinerra_game.storage_aware_crew_plan_reviews_v1 WHERE plan_id=f.plan_id AND airline_id=p_airline;
 SELECT pol.* INTO STRICT model FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version AND s.status='active'
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=s.configuration_id AND pol.qualification_group=f.qualification_group
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=o.aircraft_inventory_id AND i.airline_id=o.airline_id AND i.configuration_id=s.configuration_id AND i.fleet_status='in_service'
 WHERE o.id=f.occurrence_id AND o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled'
 AND o.schedule_version=f.schedule_version AND o.aircraft_inventory_id=f.aircraft_inventory_id AND o.departure_utc=f.departure_utc AND o.arrival_utc=f.arrival_utc
 AND o.origin_airport_key=f.origin_airport_key AND o.destination_airport_key=f.destination_airport_key
 AND o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text=p_physical
 AND f.cabin_count=CASE WHEN pol.seat_basis='cargo_zero' OR o.verified_passenger_seats<=19 THEN 0 ELSE (o.verified_passenger_seats+49)/50 END;
 SELECT value INTO STRICT assignment FROM jsonb_array_elements(r.assignments) WHERE value->>'flightId'=f.occurrence_id::text;
 IF assignment->>'aircraftId' IS DISTINCT FROM f.aircraft_inventory_id::text OR (assignment->>'departureUtc')::timestamptz IS DISTINCT FROM f.departure_utc OR (assignment->>'arrivalUtc')::timestamptz IS DISTINCT FROM f.arrival_utc THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_assignment_changed');END IF;
 rot:=airlinerra_game.section9_crew_rotation_window_v2(jsonb_build_array(jsonb_build_object('originAirportKey',f.origin_airport_key,'destinationAirportKey',f.destination_airport_key,'departureUtc',to_char(f.departure_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'arrivalUtc',to_char(f.arrival_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))));
 IF rot->>'status' IS DISTINCT FROM 'rotation_preview' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_rotation_invalid');END IF;
 expected:=CASE WHEN f.arrival_utc-f.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 SELECT count(*),count(*) FILTER(WHERE seat_role='captain'),count(*) FILTER(WHERE seat_role='first_officer'),count(*) FILTER(WHERE seat_role='cabin'),
 coalesce(jsonb_agg(jsonb_build_object('employeeId',employee_id::text,'role',seat_role) ORDER BY employee_id::text),'[]'::jsonb)
 INTO n,nc,nf,na,actual_seats FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=f.plan_id AND airline_id=p_airline AND occurrence_id=f.occurrence_id;
 SELECT coalesce(jsonb_agg(jsonb_build_object('employeeId',id,'role',role) ORDER BY id),'[]'::jsonb) INTO review_seats FROM
 (SELECT jsonb_array_elements_text(assignment->'captains') id,'captain' role UNION ALL SELECT jsonb_array_elements_text(assignment->'firstOfficers'),'first_officer' UNION ALL SELECT jsonb_array_elements_text(assignment->'cabinCrew'),'cabin') seats;
 IF nc<>expected OR nf<>expected OR nc<>f.captain_count OR nf<>f.first_officer_count OR na<>f.cabin_count OR n<>nc+nf+na OR actual_seats IS DISTINCT FROM review_seats
 OR n<>(SELECT count(DISTINCT v->>'employeeId') FROM jsonb_array_elements(actual_seats) a(v))
 THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_manifest_changed');END IF;
 coverage:=airlinerra_game.storage_rolling_crew_coverage_v1(p_airline,now_utc);
 IF coverage->>'coverageVerified' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_history_coverage_blocked');END IF;
 roster:=airlinerra_game.section9_owned_weekly_crew_input_v1(owner_id,p_airline,now_utc);
 IF roster->>'status' IS DISTINCT FROM 'weekly_crew_bootstrap_input_preview' OR roster->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR roster->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR jsonb_typeof(roster->'pilots') IS DISTINCT FROM 'array' OR jsonb_typeof(roster->'cabinMembers') IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_roster_unverified');END IF;
 FOR seat IN SELECT s.employee_id,s.seat_role,s.duty_id,d.duty_start_utc,d.duty_end_utc,d.starting_airport,d.ending_airport FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id WHERE s.plan_id=f.plan_id AND s.occurrence_id=f.occurrence_id AND s.airline_id=p_airline LOOP
  prefix:=airlinerra_game.storage_commercial_rotation_prefix_v1(p_airline,f.plan_id,seat.duty_id,seat.employee_id,f.occurrence_id);
  IF prefix->>'passed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status',prefix->>'status');END IF;
  rot:=prefix->'rotation';
  multileg:=multileg OR (prefix->>'legCount')::int>1;
  history_at:=CASE WHEN (prefix->>'priorLegCount')::int>0 THEN seat.duty_start_utc ELSE now_utc END;
  IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=p_airline AND pd.employee_id=seat.employee_id AND pd.duty_id<>seat.duty_id AND pd.duty_start_utc<seat.duty_end_utc+interval '12 hours' AND pd.duty_end_utc>seat.duty_start_utc-interval '12 hours') THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_conflicting_duty');END IF;
  SELECT count(*) INTO n FROM jsonb_array_elements((roster->'pilots')||(roster->'cabinMembers')) a(v) WHERE v->>'id'=seat.employee_id::text;
  IF n<>1 THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_employee_changed');END IF;
  SELECT value INTO STRICT member FROM jsonb_array_elements(CASE WHEN seat.seat_role='cabin' THEN roster->'cabinMembers' ELSE roster->'pilots' END) WHERE value->>'id'=seat.employee_id::text;
  IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 c LEFT JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d ON d.request_id=c.request_id AND d.employee_id=c.employee_id AND d.airline_id=c.airline_id WHERE c.airline_id=p_airline AND c.employee_id=seat.employee_id AND c.status<>'cancelled' AND (c.status NOT IN('awaiting_history_handoff','history_released') OR d.rest_complete_utc IS NULL OR d.rest_complete_utc>seat.duty_start_utc OR airlinerra_game.storage_signed_crew_departure_covered_v1(p_airline,d.departure_engine_event_id) IS DISTINCT FROM true)) THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_storage_custody_unverified');END IF;
  h:=airlinerra_game.storage_crew_combined_history_preview_v1(p_airline,seat.employee_id,history_at,member->>'initialAirport',(member->>'locationEffectiveUtc')::timestamptz);
  IF h->>'status' IS DISTINCT FROM 'combined_crew_history_preview' OR h->>'eligibleByHistory' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_current_duty_fit_failed');END IF;
  -- The signed prefix is part of this rotation, not a second completed duty.
  -- Recheck the full duty against history at original report for continuation.
  FOR duty_leg IN SELECT value FROM jsonb_array_elements(prefix->'legs') LOOP
   IF airlinerra_game.aircraft_storage_crew_candidate_fit_v1(jsonb_set(member,'{history}',h->'history'),rot,duty_leg->>'qualificationGroup',duty_leg->>'seatRole') IS DISTINCT FROM true THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_current_duty_fit_failed');END IF;
  END LOOP;
 END LOOP;
 IF (SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id WHERE s.plan_id=f.plan_id AND s.occurrence_id=f.occurrence_id AND s.airline_id=p_airline)<>nc+nf+na THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_duty_missing');END IF;
 RETURN jsonb_build_object('passed',true,'status',CASE WHEN multileg THEN 'commercial_handoff_multileg_revalidated' ELSE 'commercial_handoff_single_leg_revalidated' END,'crewCount',nc+nf+na,'dispatchAuthorized',false,'crewReleased',false);
EXCEPTION WHEN no_data_found OR too_many_rows OR invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR invalid_parameter_value THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_evidence_invalid');
END $fn$;

CREATE FUNCTION airlinerra_game.release_completed_storage_crew_custody_v1(p_player uuid,p_airline uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;c record;v_now timestamptz;roster jsonb;coverage jsonb;member jsonb;h jsonb;proof jsonb:='[]';n int;changed int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request AND airline_id=p_airline AND owner_player_id=p_player FOR UPDATE;
 IF NOT FOUND OR r.status<>'completed' THEN RETURN jsonb_build_object('status','storage_custody_completion_required','released',false);END IF;
 SELECT count(*) INTO n FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=p_request;
 IF n>0 AND n=(SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=p_request AND status='history_released') AND n=(SELECT count(*) FROM airlinerra_game.storage_crew_custody_releases_v1 WHERE request_id=p_request AND airline_id=p_airline) THEN RETURN jsonb_build_object('status','storage_custody_released','released',true,'replayed',true,'crewCount',n);END IF;
 IF NOT airlinerra_game.storage_crew_custody_release_enabled_v1() THEN RETURN jsonb_build_object('status','storage_custody_release_disabled','released',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR NOT isfinite(v_now) OR n=0 OR n<>(SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=p_request AND status='awaiting_history_handoff') THEN RETURN jsonb_build_object('status','storage_custody_state_invalid','released',false);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_signed_crew_manifests_v1 m WHERE m.request_id=p_request AND m.airline_id=p_airline AND airlinerra_game.storage_signed_crew_departure_covered_v1(p_airline,m.departure_event_id)) THEN RETURN jsonb_build_object('status','storage_custody_manifest_unverified','released',false);END IF;
 coverage:=airlinerra_game.storage_rolling_crew_coverage_v1(p_airline,v_now);
 IF coverage->>'coverageVerified' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','storage_custody_history_unverified','released',false);END IF;
 roster:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,v_now);
 IF roster->>'status' IS DISTINCT FROM 'weekly_crew_bootstrap_input_preview' OR roster->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR roster->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR jsonb_typeof(roster->'pilots') IS DISTINCT FROM 'array' OR jsonb_typeof(roster->'cabinMembers') IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('status','storage_custody_roster_unverified','released',false);END IF;
 FOR c IN SELECT s.*,d.departure_engine_event_id,d.arrival_engine_event_id,d.rest_complete_utc FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d ON d.request_id=s.request_id AND d.employee_id=s.employee_id AND d.airline_id=s.airline_id WHERE s.request_id=p_request AND s.airline_id=p_airline ORDER BY s.employee_id LOOP
  IF c.rest_complete_utc IS NULL OR c.rest_complete_utc>v_now OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=p_airline AND pd.employee_id=c.employee_id AND pd.duty_end_utc+interval '12 hours'>v_now) THEN RETURN jsonb_build_object('status','storage_custody_rest_or_duty_pending','released',false);END IF;
  SELECT value INTO STRICT member FROM jsonb_array_elements((roster->'pilots')||(roster->'cabinMembers')) WHERE value->>'id'=c.employee_id::text;
  h:=airlinerra_game.storage_crew_history_for_booking_review_v1(p_airline,c.employee_id,v_now,member->>'initialAirport',(member->>'locationEffectiveUtc')::timestamptz,NULL);
  IF h->>'status' IS DISTINCT FROM 'combined_crew_history_preview' OR h->>'eligibleByHistory' IS DISTINCT FROM 'true' OR nullif(h->>'lastAirport','') IS NULL THEN RETURN jsonb_build_object('status','storage_custody_employee_history_unverified','released',false);END IF;
  proof:=proof||jsonb_build_array(jsonb_build_object('employeeId',c.employee_id,'dep',c.departure_engine_event_id,'arr',c.arrival_engine_event_id,'history',h));
 END LOOP;
 IF jsonb_array_length(proof)<>n THEN RETURN jsonb_build_object('status','storage_custody_manifest_unverified','released',false);END IF;
 INSERT INTO airlinerra_game.storage_crew_custody_releases_v1 SELECT p_request,(v->>'employeeId')::uuid,p_airline,v->>'dep',v->>'arr',v_now,v#>>'{history,lastAirport}',v->'history' FROM jsonb_array_elements(proof) a(v);
 UPDATE airlinerra_game.aircraft_storage_crew_reservations_v1 SET status='history_released' WHERE request_id=p_request AND airline_id=p_airline AND status='awaiting_history_handoff';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>n OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_signed_crew_manifests_v1 m WHERE m.request_id=p_request AND airlinerra_game.storage_signed_crew_departure_covered_v1(p_airline,m.departure_event_id)) THEN RAISE EXCEPTION 'STORAGE_CUSTODY_RELEASE_ATOMICITY_FAILED';END IF;
 RETURN jsonb_build_object('status','storage_custody_released','released',true,'replayed',false,'crewCount',n,'historyPreserved',true,'dispatchAuthorized',false);
EXCEPTION WHEN no_data_found OR too_many_rows OR invalid_text_representation OR invalid_datetime_format THEN RETURN jsonb_build_object('status','storage_custody_employee_history_unverified','released',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.release_completed_storage_crew_custody_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
-- Automatic custody queue; independent disabled gate, same advisory lock and verified clock.
ALTER TABLE airlinerra_game.storage_background_worker_release_v1 ADD COLUMN custody_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE airlinerra_game.storage_background_attempts_v1 DROP CONSTRAINT storage_background_attempts_v1_phase_check;
ALTER TABLE airlinerra_game.storage_background_attempts_v1 ADD CONSTRAINT storage_background_attempts_v1_phase_check CHECK(phase IN('departed','arrived','expiry','billing','custody'));
CREATE OR REPLACE FUNCTION airlinerra_game.run_storage_background_tick_v1(p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE gate record;c record;j jsonb;v_now timestamptz;day_key date;phase_key text;results jsonb:='[]'::jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_STORAGE_BACKGROUND_LIMIT';END IF;
 IF NOT pg_try_advisory_xact_lock(190927,1) THEN RETURN jsonb_build_object('status','storage_background_busy','results',results);END IF;
 SELECT * INTO gate FROM airlinerra_game.storage_background_worker_release_v1 WHERE world_id=1;
 IF NOT FOUND OR NOT(gate.movement_enabled OR gate.billing_enabled OR gate.expiry_enabled OR gate.custody_enabled) THEN RETURN jsonb_build_object('status','storage_background_not_released','results',results);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR NOT isfinite(v_now) THEN RETURN jsonb_build_object('status','game_clock_unverified','results',results);END IF;
 day_key:=(v_now AT TIME ZONE 'Europe/Berlin')::date;
 -- Separate bounded queues. Arrivals first; no failed airline can monopolize
 -- a queue indefinitely: least recently attempted records come first.
 FOREACH phase_key IN ARRAY ARRAY['arrived','custody','billing','departed','expiry'] LOOP
  IF (phase_key='custody' AND (NOT gate.custody_enabled OR NOT airlinerra_game.storage_crew_custody_release_enabled_v1())) OR (phase_key IN('arrived','departed') AND NOT gate.movement_enabled) OR (phase_key='billing' AND NOT gate.billing_enabled) OR (phase_key='expiry' AND NOT gate.expiry_enabled) THEN CONTINUE;END IF;
  FOR c IN
   WITH due AS (
    SELECT r.id AS request_id,r.airline_id,0 AS next_month,CASE WHEN phase_key='arrived' THEN r.arrival_utc ELSE r.departure_utc END AS due_at
    FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
    WHERE phase_key IN('arrived','departed','expiry') AND r.status IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review')
    AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.storage_request_id=r.id AND m.phase='arrived')
    AND (
     (phase_key='arrived' AND r.arrival_utc<=v_now AND EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.storage_request_id=r.id AND m.phase='departed'))
     OR (phase_key IN('departed','expiry') AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.storage_request_id=r.id AND m.phase='departed') AND
      ((phase_key='departed' AND r.departure_utc<=v_now AND r.departure_utc>v_now-interval '10 minutes') OR (phase_key='expiry' AND r.departure_utc<=v_now-interval '10 minutes'))))
    UNION ALL
    SELECT r.id,r.airline_id,0,max(d.rest_complete_utc)
    FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
    JOIN airlinerra_game.aircraft_storage_crew_reservations_v1 s ON s.request_id=r.id AND s.airline_id=r.airline_id
    LEFT JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d ON d.request_id=s.request_id AND d.employee_id=s.employee_id AND d.airline_id=s.airline_id
    WHERE phase_key='custody' AND r.status='completed'
    GROUP BY r.id,r.airline_id
    HAVING bool_and(s.status='awaiting_history_handoff') AND count(d.rest_complete_utc)=count(*) AND max(d.rest_complete_utc)<=v_now
    UNION ALL
    SELECT s.request_id,s.airline_id,n.paid+1,(airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n.paid)::timestamp AT TIME ZONE 'Europe/Berlin')
    FROM airlinerra_game.aircraft_storage_sessions_v1 s JOIN airlinerra_game.aircraft_storage_billing_terms_v1 t USING(request_id)
    CROSS JOIN LATERAL(SELECT count(*)::int AS paid FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 x WHERE x.request_id=s.request_id) n
    WHERE phase_key='billing' AND airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n.paid)<=day_key
    AND (s.storage_ended_utc IS NULL OR n.paid=0 OR airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n.paid)<(s.storage_ended_utc AT TIME ZONE 'Europe/Berlin')::date)
   )
   SELECT d.* FROM due d LEFT JOIN airlinerra_game.storage_background_attempts_v1 x ON x.request_id=d.request_id AND x.phase=phase_key
   WHERE x.last_attempt_utc IS NULL OR x.last_attempt_utc<v_now
   ORDER BY x.last_attempt_utc NULLS FIRST,d.due_at,d.request_id LIMIT p_limit
  LOOP
   BEGIN
    IF phase_key='custody' THEN
     j:=airlinerra_game.release_completed_storage_crew_custody_v1((SELECT owner_player_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=c.request_id),c.airline_id,c.request_id);
    ELSIF phase_key='billing' THEN j:=airlinerra_game.post_aircraft_storage_month_v1(c.airline_id,c.request_id,c.next_month);
    ELSIF phase_key='expiry' THEN j:=airlinerra_game.expire_missed_storage_departure_v1(c.request_id);
    ELSE j:=airlinerra_game.execute_aircraft_storage_leg_v1(c.request_id,phase_key);END IF;
   EXCEPTION WHEN OTHERS THEN j:=jsonb_build_object('status','storage_background_item_rolled_back','sqlstate',SQLSTATE);END;
   INSERT INTO airlinerra_game.storage_background_attempts_v1 VALUES(c.request_id,phase_key,v_now,coalesce(j->>'status','unknown'))
   ON CONFLICT(request_id,phase) DO UPDATE SET last_attempt_utc=excluded.last_attempt_utc,status=excluded.status;
   results:=results||jsonb_build_array(j||jsonb_build_object('requestId',c.request_id,'phase',phase_key));
  END LOOP;
 END LOOP;
 RETURN jsonb_build_object('status','storage_background_checked','checkedAtUtc',v_now,'results',results);
END $fn$;

ROLLBACK;
