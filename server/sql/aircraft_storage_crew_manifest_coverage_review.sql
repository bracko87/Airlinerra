-- ROLLBACK-ONLY REVIEW. Freeze the exact storage crew manifest at signed
-- departure and reconcile it with the rolling commercial history coverage.
-- No legacy departure is grandfathered, no custody is released.
BEGIN;
CREATE TABLE airlinerra_game.storage_signed_crew_manifests_v1(
 request_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 departure_event_id text UNIQUE NOT NULL REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),physical_flight_id text UNIQUE NOT NULL,
 configuration_id bigint NOT NULL,qualification_group text NOT NULL,
 captain_count int NOT NULL CHECK(captain_count IN(1,2)),
 first_officer_count int NOT NULL CHECK(first_officer_count=captain_count),
 cabin_count int NOT NULL CHECK(cabin_count>=0),
 postflight_minutes int NOT NULL CHECK(postflight_minutes>=0),rest_minutes int NOT NULL CHECK(rest_minutes>=720),
 seats jsonb NOT NULL CHECK(jsonb_typeof(seats)='array' AND jsonb_array_length(seats)=captain_count+first_officer_count+cabin_count)
);
ALTER TABLE airlinerra_game.storage_signed_crew_manifests_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_signed_crew_manifests_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER storage_signed_crew_manifest_immutable BEFORE UPDATE OR DELETE ON airlinerra_game.storage_signed_crew_manifests_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1();

-- Run after capture_storage_crew_departure_v1, whose receipt insert validates
-- crew role counts, qualification, endpoints and exact duty windows.
CREATE FUNCTION airlinerra_game.freeze_storage_signed_crew_manifest_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;model record;pol record;seats jsonb;nc int;nf int;na int;expected int;
BEGIN
 IF NEW.storage_request_id IS NULL OR NEW.phase<>'departed' THEN RETURN NEW;END IF;
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=NEW.storage_request_id AND airline_id=NEW.airline_id AND aircraft_inventory_id=NEW.aircraft_inventory_id;
 SELECT * INTO STRICT model FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=(r.quote->>'configurationId')::bigint;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 expected:=CASE WHEN r.arrival_utc-r.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 SELECT coalesce(jsonb_agg(jsonb_build_object('employeeId',s.employee_id,'role',s.seat_role,'reportUtc',s.duty_start_utc,'endUtc',s.duty_end_utc) ORDER BY s.employee_id),'[]'::jsonb),
 count(*) FILTER(WHERE s.seat_role='captain'),count(*) FILTER(WHERE s.seat_role='first_officer'),count(*) FILTER(WHERE s.seat_role='cabin')
 INTO seats,nc,nf,na
 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s
 JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d ON d.request_id=s.request_id AND d.employee_id=s.employee_id AND d.airline_id=s.airline_id
 WHERE s.request_id=r.id AND s.airline_id=r.airline_id AND s.status='reserved'
 AND s.qualification_group=model.qualification_group AND s.origin_airport_key=r.origin_airport_key AND s.destination_airport_key=r.destination_airport_key
 AND d.departure_engine_event_id=NEW.engine_event_id AND d.actual_departure_utc=NEW.actual_event_utc AND d.reported_duty_start_utc=s.duty_start_utc
 AND d.origin_airport_key=s.origin_airport_key AND d.destination_airport_key=s.destination_airport_key AND d.arrival_engine_event_id IS NULL;
 IF nc<>expected OR nf<>expected OR na IS DISTINCT FROM model.minimum_cabin_crew
 OR jsonb_array_length(seats)<>(SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id)
 OR jsonb_array_length(seats)<>(SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=r.id)
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_SIGNED_CREW_MANIFEST_INCOMPLETE';END IF;
 INSERT INTO airlinerra_game.storage_signed_crew_manifests_v1 VALUES(r.id,NEW.engine_event_id,r.airline_id,NEW.flight_occurrence_id,model.configuration_id,model.qualification_group,nc,nf,na,pol.postflight_minutes,pol.minimum_rest_minutes,seats);
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.freeze_storage_signed_crew_manifest_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER zz_freeze_storage_signed_crew_manifest_v1 AFTER INSERT ON airlinerra_game.section9_operated_flight_movements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.freeze_storage_signed_crew_manifest_v1();

CREATE FUNCTION airlinerra_game.storage_signed_crew_departure_covered_v1(p_airline uuid,p_event text)
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
 IF completed THEN
  SELECT * INTO a FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='arrived' AND airline_id=p_airline AND aircraft_inventory_id=r.aircraft_inventory_id AND flight_occurrence_id=m.physical_flight_id AND origin_airport_key=r.origin_airport_key AND destination_airport_key=r.destination_airport_key AND actual_event_utc=r.arrival_utc AND scheduled_departure_utc=r.departure_utc AND scheduled_arrival_utc=r.arrival_utc;
  IF NOT FOUND THEN RETURN false;END IF;
 ELSE
  IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='arrived') THEN RETURN false;END IF;
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('employeeId',s.employee_id,'role',s.seat_role,'reportUtc',s.duty_start_utc,'endUtc',s.duty_end_utc) ORDER BY s.employee_id),'[]'::jsonb) INTO actual_seats
 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s
 JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 c ON c.request_id=s.request_id AND c.employee_id=s.employee_id AND c.airline_id=s.airline_id
 WHERE s.request_id=r.id AND s.airline_id=p_airline AND s.qualification_group=m.qualification_group
 AND s.status=CASE WHEN completed THEN 'awaiting_history_handoff' ELSE 'reserved' END
 AND s.origin_airport_key=r.origin_airport_key AND s.destination_airport_key=r.destination_airport_key
 AND c.departure_engine_event_id=p_event AND c.actual_departure_utc=d.actual_event_utc AND c.reported_duty_start_utc=s.duty_start_utc
 AND c.origin_airport_key=s.origin_airport_key AND c.destination_airport_key=s.destination_airport_key
 AND (CASE WHEN completed THEN c.arrival_engine_event_id=a.engine_event_id AND c.actual_arrival_utc=a.actual_event_utc AND c.completed_duty_end_utc=a.actual_event_utc+make_interval(mins=>m.postflight_minutes) AND c.completed_duty_end_utc=s.duty_end_utc AND c.rest_complete_utc=c.completed_duty_end_utc+make_interval(mins=>m.rest_minutes)
 ELSE c.arrival_engine_event_id IS NULL AND c.actual_arrival_utc IS NULL AND c.completed_duty_end_utc IS NULL AND c.rest_complete_utc IS NULL END);
 RETURN actual_seats=m.seats AND jsonb_array_length(actual_seats)=(SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id)
 AND jsonb_array_length(actual_seats)=(SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=r.id);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_signed_crew_departure_covered_v1(uuid,text) FROM PUBLIC,anon,authenticated,service_role;

-- Preserve the original rolling check's seven-day scope. Only an exact
-- commercial binding or a complete signed storage manifest covers a departure.
CREATE FUNCTION airlinerra_game.storage_rolling_crew_coverage_v1(p_airline uuid,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE n_storage int;n_unbound int;n_issues int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_at IS NULL OR NOT isfinite(p_at) THEN RETURN jsonb_build_object('status','storage_rolling_coverage_invalid','coverageVerified',false);END IF;
 WITH checked AS MATERIALIZED(
 SELECT m.storage_request_id,CASE WHEN m.storage_request_id IS NOT NULL THEN airlinerra_game.storage_signed_crew_departure_covered_v1(p_airline,m.engine_event_id)
 ELSE EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b WHERE b.airline_id=m.airline_id AND b.physical_flight_id=m.flight_occurrence_id AND b.departure_event_id=m.engine_event_id) END AS covered
 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.phase='departed' AND m.actual_event_utc>=p_at-interval '7 days'
 )
 SELECT count(*) FILTER(WHERE storage_request_id IS NOT NULL AND covered IS TRUE),count(*) FILTER(WHERE covered IS DISTINCT FROM true) INTO n_storage,n_unbound FROM checked;
 -- Never suppress a commercial capture issue merely because a storage
 -- receipt exists. The legacy issue table remains a separate authority.
 SELECT count(*) INTO n_issues FROM airlinerra_game.section9_operated_crew_capture_issues_v1 x JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=x.engine_event_id
 WHERE x.airline_id=p_airline AND m.actual_event_utc>=p_at-interval '7 days' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b WHERE b.airline_id=x.airline_id AND b.physical_flight_id=x.physical_flight_id AND b.departure_event_id=x.engine_event_id);
 RETURN jsonb_build_object('status','storage_rolling_coverage_checked','coveredStorageDepartures',n_storage,'unboundDeparturesLast7Days',n_unbound,'unresolvedCaptureIssues',n_issues,'coverageVerified',n_unbound=0 AND n_issues=0,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_rolling_crew_coverage_v1(uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.owned_storage_aware_rolling_crew_input_v1(p_player uuid,p_airline uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE base jsonb;coverage jsonb;legacy jsonb;now_utc timestamptz;
BEGIN
 base:=airlinerra_game.owned_storage_aware_crew_input_preview_v1(p_player,p_airline,p_start);
 IF base->>'status' IS DISTINCT FROM 'storage_aware_crew_input_preview' THEN RETURN base;END IF;
 now_utc:=(base->>'planningCutoffUtc')::timestamptz;
 coverage:=airlinerra_game.storage_rolling_crew_coverage_v1(p_airline,now_utc);
 legacy:=airlinerra_game.section9_owned_rolling_crew_input_v1(p_player,p_airline,p_start);
 IF coverage->>'coverageVerified' IS DISTINCT FROM 'true' OR legacy->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR legacy->>'alreadyReportedFutureFlights' IS DISTINCT FROM '0' OR legacy->>'invalidOccurrenceCount' IS DISTINCT FROM '0'
 OR EXISTS(SELECT 1 FROM jsonb_array_elements((base->'pilots')||(base->'cabinMembers')) a(v) GROUP BY v->>'id' HAVING count(*)<>1 OR v->>'id' IS NULL)
 THEN RETURN jsonb_build_object('status','storage_aware_rolling_crew_history_blocked','coverage',coverage,'saveAllowed',false,'crewReleased',false,'dispatchAuthorized',false);END IF;
 RETURN base||jsonb_build_object('status','storage_aware_rolling_crew_input_preview','coverage',coverage,'preferredAssignments',coalesce(legacy->'preferredAssignments','[]'::jsonb),'alreadyReportedFutureFlights',0,'saveAllowed',false,'crewReleased',false,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_storage_aware_rolling_crew_input_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
