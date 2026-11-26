-- Isolated atomic crew booking test. Candidate selection is separately
-- exercised with real duty fit; here it is a deterministic server-side double.
CREATE OR REPLACE FUNCTION airlinerra_game.owned_aircraft_storage_crew_candidates_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT current_setting('test.crew_bound_candidates')::jsonb$$;
CREATE FUNCTION airlinerra_game.test_storage_crew_insert_failure_v1() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF current_setting('test.crew_bound_fail',true)='yes' AND NEW.seat_role='first_officer' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='synthetic crew insert failure';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER test_storage_crew_insert_failure_v1 BEFORE INSERT ON airlinerra_game.aircraft_storage_crew_reservations_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.test_storage_crew_insert_failure_v1();
DO $test$
DECLARE s record;owner_id uuid;dep timestamptz;q jsonb;crew jsonb;j jsonb;rid uuid;k uuid:=gen_random_uuid();approval_id uuid;balance numeric;n bigint;
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 dep:=date_trunc('second',s.storage_started_utc+interval '3 hours');
 SELECT cash_usd INTO balance FROM airlinerra_game.airlines WHERE id=s.airline_id;
 SELECT count(*) INTO n FROM airlinerra_game.aircraft_storage_relocation_requests_v1;
 j:=airlinerra_game.confirm_crew_bound_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'storage_crew_booking_not_released' THEN RAISE EXCEPTION 'crew release bypass: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_crew_booking_release_v1 SET enabled=true;
 UPDATE airlinerra_game.aircraft_storage_booking_release_v1 SET enabled=true;
 UPDATE airlinerra_game.aircraft_storage_execution_release_v1 SET execution_enabled=true,fuel_adapter_enabled=true;
 UPDATE airlinerra_game.aircraft_storage_signed_movement_release_v1 SET enabled=true;
 UPDATE airlinerra_game.aircraft_storage_reactivation_release_v1 SET enabled=true;
 q:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 INSERT INTO airlinerra_game.aircraft_storage_booking_approvals_v1(airline_id,aircraft_inventory_id,purpose,configuration_id,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,relocation_usd,runway_review_reference,airport_restriction_review_reference,ferry_licence_review_reference,crew_review_reference,approved_at)
 VALUES(s.airline_id,s.aircraft_inventory_id,'storage_reactivation',1,s.airport_key,'OURAIRPORTS:999',dep,(q->>'arrivalUtc')::timestamptz,2688.13,'fixture','fixture','fixture','fixture',s.storage_started_utc) RETURNING id INTO approval_id;
 crew:=jsonb_build_object('status','storage_crew_candidates_found','captainsRequired',1,'firstOfficersRequired',1,'minimumCabinCrew',0,'qualificationGroup','fixture','candidateCaptains',jsonb_build_array(gen_random_uuid()),'candidateFirstOfficers',jsonb_build_array(gen_random_uuid()),'candidateCabinCrew','[]'::jsonb,'rotation',jsonb_build_object('startingAirport',s.airport_key,'endingAirport','OURAIRPORTS:999','dutyStartUtc',dep-interval '2 hours','dutyEndUtc',(q->>'arrivalUtc')::timestamptz+interval '30 minutes'));
 PERFORM set_config('test.crew_bound_candidates',crew::text,true);
 PERFORM set_config('test.crew_bound_fail','yes',true);
 j:=airlinerra_game.confirm_crew_bound_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'storage_crew_reservation_failed' OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_relocation_requests_v1)<>n OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1) OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_approvals_v1 WHERE id=approval_id AND consumed_request_id IS NOT NULL) THEN RAISE EXCEPTION 'crew reservation rollback failed: %',j;END IF;
 PERFORM set_config('test.crew_bound_fail','no',true);
 j:=airlinerra_game.confirm_crew_bound_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'booked' IS DISTINCT FROM 'true' OR j->>'crewReserved' IS DISTINCT FROM 'true' OR j->>'crewCount' IS DISTINCT FROM '2' THEN RAISE EXCEPTION 'crew-bound booking failed: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='reserved')<>2 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=rid)<>2 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance-2688.13 THEN RAISE EXCEPTION 'crew-bound booking evidence incomplete';END IF;
 j:=airlinerra_game.confirm_crew_bound_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'replayed' IS DISTINCT FROM 'true' OR j->>'requestId' IS DISTINCT FROM rid::text OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid)<>2 THEN RAISE EXCEPTION 'crew booking replay failed';END IF;
 j:=airlinerra_game.cancel_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,rid);
 IF j->>'cancelled' IS DISTINCT FROM 'true' OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='cancelled')<>2 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance THEN RAISE EXCEPTION 'crew booking cancellation failed';END IF;
 RAISE NOTICE 'Atomic crew-bound storage booking acceptance passed (synthetic candidate input)';
END $test$;
ROLLBACK TO SAVEPOINT storage_crew_guard;
