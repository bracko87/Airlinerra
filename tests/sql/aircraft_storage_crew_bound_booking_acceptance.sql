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
-- Composition tests isolate the screens; real booking, slots, holds and crew
-- reservation are exercised. Fuel mutation is deliberately rolled back.
CREATE OR REPLACE FUNCTION airlinerra_game.owned_aircraft_storage_operational_screen_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure)||jsonb_build_object('airportScreenPassed',current_setting('test.auto_airport')='clear','departureScreen',jsonb_build_object('passed',true),'arrivalScreen',jsonb_build_object('passed',true),'licenceScreen',jsonb_build_object('allowed',current_setting('test.auto_licence')='clear'),'crewScreen',jsonb_build_object('requirementsVerified',true))
$$;
CREATE OR REPLACE FUNCTION airlinerra_game.storage_reactivation_maintenance_window_v1(p_owner uuid,p_airline uuid,p_aircraft uuid,p_depart_utc timestamptz,p_arrive_utc timestamptz)
RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('gameMaintenanceClear',current_setting('test.auto_maintenance')='clear')$$;
CREATE TABLE airlinerra_game.test_auto_fuel_writes(physical text);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(p_physical_flight_id text)
RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO airlinerra_game.test_auto_fuel_writes VALUES(p_physical_flight_id);RETURN jsonb_build_object('status','game_only_auto_fuel_supply_recorded');END$$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id text)
RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('fuelVerifiedForGame',current_setting('test.auto_fuel')='clear')$$;
DO $auto$
DECLARE s record;owner_id uuid;dep timestamptz;j jsonb;rid uuid;k uuid:=gen_random_uuid();balance numeric;n bigint;approvals bigint;
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 dep:=date_trunc('second',s.storage_started_utc+interval '3 hours');
 SELECT cash_usd INTO balance FROM airlinerra_game.airlines WHERE id=s.airline_id;
 SELECT count(*) INTO n FROM airlinerra_game.aircraft_storage_relocation_requests_v1;
 SELECT count(*) INTO approvals FROM airlinerra_game.aircraft_storage_booking_approvals_v1;
 j:=airlinerra_game.confirm_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'automatic_storage_booking_not_released' THEN RAISE EXCEPTION 'automatic gate bypass: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_automatic_booking_release_v1 SET enabled=true;
 UPDATE airlinerra_game.storage_crew_departure_validation_release_v1 SET enabled=true;
 PERFORM set_config('test.auto_airport','blocked',true);
 PERFORM set_config('test.auto_licence','clear',true);
 PERFORM set_config('test.auto_maintenance','clear',true);
 PERFORM set_config('test.auto_fuel','clear',true);
 j:=airlinerra_game.confirm_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'automatic_storage_airport_blocked' THEN RAISE EXCEPTION 'airport gate bypass: %',j;END IF;
 PERFORM set_config('test.auto_airport','clear',true);
 PERFORM set_config('test.auto_licence','blocked',true);
 j:=airlinerra_game.confirm_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'automatic_storage_licence_blocked' THEN RAISE EXCEPTION 'licence gate bypass: %',j;END IF;
 PERFORM set_config('test.auto_licence','clear',true);
 PERFORM set_config('test.auto_maintenance','blocked',true);
 j:=airlinerra_game.confirm_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'automatic_storage_maintenance_blocked' THEN RAISE EXCEPTION 'maintenance gate bypass: %',j;END IF;
 PERFORM set_config('test.auto_maintenance','clear',true);
 PERFORM set_config('test.auto_fuel','blocked',true);
 j:=airlinerra_game.confirm_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'automatic_storage_fuel_blocked' THEN RAISE EXCEPTION 'fuel gate bypass: %',j;END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_relocation_requests_v1)<>n OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_booking_approvals_v1)<>approvals OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance OR EXISTS(SELECT 1 FROM airlinerra_game.test_auto_fuel_writes) THEN RAISE EXCEPTION 'automatic booking rollback incomplete';END IF;
 PERFORM set_config('test.auto_fuel','clear',true);
 j:=airlinerra_game.confirm_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'booked' IS DISTINCT FROM 'true' OR j->>'automaticClearanceGenerated' IS DISTINCT FROM 'true' OR j->>'dispatchAuthorized' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'automatic booking failed: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 WHERE request_id=rid AND fuel_screen->>'simulationRolledBack'='true') OR EXISTS(SELECT 1 FROM airlinerra_game.test_auto_fuel_writes) THEN RAISE EXCEPTION 'automatic evidence or simulation rollback failed';END IF;
 j:=airlinerra_game.confirm_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'automatic booking replay failed: %',j;END IF;
 j:=airlinerra_game.cancel_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,rid);
 IF j->>'cancelled' IS DISTINCT FROM 'true' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance THEN RAISE EXCEPTION 'automatic booking cancellation failed: %',j;END IF;
 RAISE NOTICE 'Automatic storage booking composition acceptance passed (synthetic screens and fuel writes)';
END $auto$;

-- The player wrapper requires the release records from the final admission and
-- departure reviews. These two switches are test doubles in this savepoint.
CREATE TABLE airlinerra_game.storage_facility_admission_release_v1(world_id smallint PRIMARY KEY,enabled boolean NOT NULL);
INSERT INTO airlinerra_game.storage_facility_admission_release_v1 VALUES(1,true);
CREATE TABLE airlinerra_game.storage_operational_departure_release_v1(world_id smallint PRIMARY KEY,enabled boolean NOT NULL);
INSERT INTO airlinerra_game.storage_operational_departure_release_v1 VALUES(1,false);
DO $player$
DECLARE s record;owner_id uuid;dep timestamptz;j jsonb;rid uuid;k uuid:=gen_random_uuid();n bigint;bal numeric;
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 dep:=date_trunc('second',s.storage_started_utc+interval '3 hours');
 SELECT count(*) INTO n FROM airlinerra_game.aircraft_storage_relocation_requests_v1;
 SELECT cash_usd INTO bal FROM airlinerra_game.airlines WHERE id=s.airline_id;
 j:=airlinerra_game.owned_aircraft_storage_automatic_booking_preview_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 IF j->>'bookingEligible' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'disabled player preview: %',j;END IF;
 UPDATE airlinerra_game.storage_player_automatic_booking_release_v1 SET enabled=true;
 j:=airlinerra_game.confirm_player_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'storage_player_automatic_booking_not_released' THEN RAISE EXCEPTION 'departure gate bypass: %',j;END IF;
 UPDATE airlinerra_game.storage_operational_departure_release_v1 SET enabled=true;
 PERFORM set_config('test.auto_airport','blocked',true);
 j:=airlinerra_game.owned_aircraft_storage_automatic_booking_preview_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 IF j->>'bookingEligible' IS DISTINCT FROM 'false' OR j->>'bookingReadiness' IS DISTINCT FROM 'storage_airport_screen_blocked' THEN RAISE EXCEPTION 'blocked airport preview: %',j;END IF;
 PERFORM set_config('test.auto_airport','clear',true);
 j:=airlinerra_game.owned_aircraft_storage_automatic_booking_preview_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 IF j->>'bookingEligible' IS DISTINCT FROM 'true' OR j->>'bookingRequiresFinalChecks' IS DISTINCT FROM 'true' OR j ? 'candidateCaptains' OR j ? 'candidateFirstOfficers' OR j ? 'candidateCabinCrew' OR j->>'readOnly' IS DISTINCT FROM 'true' OR j->>'bookable' IS DISTINCT FROM 'false'
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_relocation_requests_v1)<>n OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>bal THEN RAISE EXCEPTION 'unsafe player preview: %',j;END IF;
 j:=airlinerra_game.confirm_player_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'booked' IS DISTINCT FROM 'true' OR j->>'crewReserved' IS DISTINCT FROM 'true' OR j->>'automaticClearanceGenerated' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'player automatic booking failed: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 UPDATE airlinerra_game.storage_player_automatic_booking_release_v1 SET enabled=false;
 j:=airlinerra_game.confirm_player_automatic_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'replayed' IS DISTINCT FROM 'true' OR j->>'requestId' IS DISTINCT FROM rid::text THEN RAISE EXCEPTION 'player automatic replay failed: %',j;END IF;
 j:=airlinerra_game.cancel_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,rid);
 IF j->>'cancelled' IS DISTINCT FROM 'true' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>bal THEN RAISE EXCEPTION 'player automatic cancellation failed: %',j;END IF;
 RAISE NOTICE 'Player automatic booking gateway acceptance passed (synthetic operational inputs and release switches)';
END $player$;

ROLLBACK TO SAVEPOINT storage_crew_guard;
