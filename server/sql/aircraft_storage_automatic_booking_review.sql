-- ROLLBACK-ONLY REVIEW. Automatic booking clearance, NOT permission to depart.
-- Never enable before current airport, licence, crew, fuel and maintenance data
-- are verified and departure-time enforcement is installed.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_automatic_booking_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.aircraft_storage_automatic_booking_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.aircraft_storage_automatic_booking_evidence_v1(
 approval_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_booking_approvals_v1(id),
 request_id uuid UNIQUE NOT NULL REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 checked_at timestamptz NOT NULL,operational_screen jsonb NOT NULL,maintenance_screen jsonb NOT NULL,fuel_screen jsonb NOT NULL
);
ALTER TABLE airlinerra_game.aircraft_storage_automatic_booking_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_automatic_booking_release_v1,airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.confirm_automatic_storage_booking_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz,p_expected_cost numeric,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE i record;old record;r record;q jsonb;j jsonb;maintenance jsonb;fuel jsonb;supply jsonb;aid uuid;rid uuid;v_now timestamptz;physical text;stage text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_purpose IS NULL OR p_purpose NOT IN('storage_inbound','storage_reactivation') OR p_destination IS NULL OR p_departure IS NULL OR NOT isfinite(p_departure) OR p_expected_cost IS NULL OR p_expected_cost<=0 OR p_expected_cost<>round(p_expected_cost,2) OR p_request_key IS NULL THEN RETURN jsonb_build_object('status','invalid_storage_booking','booked',false);END IF;
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO i FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO old FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE airline_id=p_airline AND request_key=p_request_key FOR UPDATE;
 IF FOUND THEN
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 WHERE request_id=old.id) THEN RETURN jsonb_build_object('status','automatic_storage_booking_not_confirmed','booked',false);END IF;
  RETURN airlinerra_game.confirm_crew_bound_storage_booking_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure,p_expected_cost,p_request_key);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_automatic_booking_release_v1 WHERE world_id=1 AND enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_departure_validation_release_v1 WHERE world_id=1 AND enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_booking_release_v1 WHERE world_id=1 AND enabled)
 THEN RETURN jsonb_build_object('status','automatic_storage_booking_not_released','booked',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL THEN RETURN jsonb_build_object('status','storage_clock_unverified','booked',false);END IF;
 q:=airlinerra_game.owned_aircraft_storage_operational_screen_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
 IF q->>'status' IS DISTINCT FROM 'storage_cost_preview_verified' THEN RETURN jsonb_build_object('status',coalesce(q->>'status','storage_quote_unverified'),'booked',false);END IF;
 IF (q->>'relocationUsd')::numeric IS DISTINCT FROM p_expected_cost THEN RETURN jsonb_build_object('status','storage_price_changed','booked',false);END IF;
 IF q->>'airportScreenPassed' IS DISTINCT FROM 'true' OR q#>>'{departureScreen,passed}' IS DISTINCT FROM 'true' OR q#>>'{arrivalScreen,passed}' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','automatic_storage_airport_blocked','booked',false);END IF;
 IF q#>>'{licenceScreen,allowed}' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','automatic_storage_licence_blocked','booked',false);END IF;
 IF q#>>'{crewScreen,requirementsVerified}' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','automatic_storage_crew_requirements_blocked','booked',false);END IF;
 -- No ambiguity with previously issued manual approvals for this exact quote.
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_approvals_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND purpose=p_purpose AND origin_airport_key=q->>'originAirportKey' AND destination_airport_key=p_destination AND departure_utc=p_departure AND revoked_at IS NULL AND consumed_request_id IS NULL) THEN RETURN jsonb_build_object('status','automatic_storage_existing_approval_requires_review','booked',false);END IF;
 BEGIN
  aid:=gen_random_uuid();
  INSERT INTO airlinerra_game.aircraft_storage_booking_approvals_v1(id,airline_id,aircraft_inventory_id,purpose,configuration_id,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,relocation_usd,runway_review_reference,airport_restriction_review_reference,ferry_licence_review_reference,crew_review_reference,approved_at)
  VALUES(aid,p_airline,p_aircraft,p_purpose,i.configuration_id,q->>'originAirportKey',p_destination,p_departure,(q->>'arrivalUtc')::timestamptz,p_expected_cost,'auto-booking:'||aid,'auto-booking:'||aid,'auto-booking:'||aid,'auto-booking:'||aid,v_now);
  j:=airlinerra_game.confirm_crew_bound_storage_booking_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure,p_expected_cost,p_request_key);
  IF j->>'booked' IS DISTINCT FROM 'true' OR j->>'crewReserved' IS DISTINCT FROM 'true' THEN stage:=coalesce(j->>'status','automatic_storage_reservation_failed');RAISE EXCEPTION USING ERRCODE='PZ004';END IF;
  rid:=(j->>'requestId')::uuid;
  SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=rid AND airline_id=p_airline AND aircraft_inventory_id=p_aircraft;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_approvals_v1 WHERE id=aid AND consumed_request_id=rid) THEN stage:='automatic_storage_approval_mismatch';RAISE EXCEPTION USING ERRCODE='PZ004';END IF;
  IF p_purpose='storage_reactivation' THEN maintenance:=airlinerra_game.storage_reactivation_maintenance_window_v1(p_player,p_airline,p_aircraft,r.departure_utc,r.arrival_utc);
  ELSE maintenance:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(p_player,p_airline,p_aircraft,r.departure_utc,r.arrival_utc);END IF;
  IF maintenance->>'gameMaintenanceClear' IS DISTINCT FROM 'true' THEN stage:='automatic_storage_maintenance_blocked';RAISE EXCEPTION USING ERRCODE='PZ004';END IF;
  physical:=rid::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1';
  -- Simulate existing fuel supply and preflight inside a deliberately aborted
  -- subtransaction. No actual fuel loading or receipt can survive booking.
  BEGIN
   supply:=airlinerra_game.section9_auto_supply_game_only_fuel_v1(physical);
   IF supply->>'status' IN('game_only_auto_fuel_supply_recorded','game_fuel_already_sufficient') THEN fuel:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(physical);END IF;
   RAISE EXCEPTION USING ERRCODE='PZ005';
  EXCEPTION WHEN SQLSTATE 'PZ005' THEN NULL;
  END;
  IF fuel->>'fuelVerifiedForGame' IS DISTINCT FROM 'true' THEN stage:='automatic_storage_fuel_blocked';RAISE EXCEPTION USING ERRCODE='PZ004';END IF;
  INSERT INTO airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 VALUES(aid,rid,v_now,q,maintenance,fuel||jsonb_build_object('simulationRolledBack',true));
  RETURN j||jsonb_build_object('automaticClearanceGenerated',true,'departureRecheckRequired',true,'dispatchAuthorized',false);
 EXCEPTION WHEN SQLSTATE 'PZ004' THEN
  RETURN jsonb_build_object('status',stage,'booked',false,'crewReserved',false,'slotsReserved',0,'fundsHeld',false,'automaticClearanceGenerated',false);
 END;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.confirm_automatic_storage_booking_v1(uuid,uuid,uuid,text,text,timestamptz,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
