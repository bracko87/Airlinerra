-- ROLLBACK-ONLY REVIEW. Player automatic booking entry points.
-- Deploy only with all storage reviews; no legacy/manual booking fallback.
BEGIN;
CREATE TABLE airlinerra_game.storage_player_automatic_booking_release_v1(world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false);
INSERT INTO airlinerra_game.storage_player_automatic_booking_release_v1(world_id) VALUES(1);
ALTER TABLE airlinerra_game.storage_player_automatic_booking_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_player_automatic_booking_release_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.storage_player_automatic_booking_enabled_v1(p_purpose text)
RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT current_user='postgres' AND p_purpose IN('storage_inbound','storage_reactivation')
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_player_automatic_booking_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_facility_admission_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_automatic_booking_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_operational_departure_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_departure_validation_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_booking_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_execution_release_v1 WHERE world_id=1 AND execution_enabled AND fuel_adapter_enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled)
 AND (p_purpose='storage_reactivation' AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled)
 OR p_purpose='storage_inbound' AND to_regclass('airlinerra_game.storage_inbound_departure_evidence_v1') IS NOT NULL)
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_player_automatic_booking_enabled_v1(text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_automatic_booking_preview_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE q jsonb;op jsonb;crew jsonb;eligible boolean:=false;reason text;
BEGIN
 -- Owner verification is performed by the existing cost preview even while disabled.
 q:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
 IF q->>'status' IS DISTINCT FROM 'storage_cost_preview_verified' THEN RETURN q||jsonb_build_object('bookingEligible',false);END IF;
 IF airlinerra_game.storage_player_automatic_booking_enabled_v1(p_purpose) IS DISTINCT FROM true THEN reason:='storage_player_automatic_booking_not_released';
 ELSE
  op:=airlinerra_game.owned_aircraft_storage_operational_screen_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
  IF op->>'status' IS DISTINCT FROM 'storage_cost_preview_verified' OR op->>'airportScreenPassed' IS DISTINCT FROM 'true' OR op#>>'{departureScreen,passed}' IS DISTINCT FROM 'true' OR op#>>'{arrivalScreen,passed}' IS DISTINCT FROM 'true' THEN reason:='storage_airport_screen_blocked';
  ELSIF op#>>'{licenceScreen,allowed}' IS DISTINCT FROM 'true' THEN reason:='storage_ferry_licence_blocked';
  ELSIF op#>>'{crewScreen,requirementsVerified}' IS DISTINCT FROM 'true' THEN reason:='storage_crew_requirements_blocked';
  ELSE
   crew:=airlinerra_game.owned_aircraft_storage_crew_candidates_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
   IF crew->>'status' IS DISTINCT FROM 'storage_crew_candidates_found' THEN reason:='storage_crew_unavailable';
   ELSE eligible:=true;reason:='storage_booking_attempt_available';END IF;
  END IF;
 END IF;
 -- Only expose readiness; no roster IDs or private review evidence.
 RETURN q||jsonb_build_object('bookingEligible',eligible,'bookingReadiness',reason,'bookingRequiresFinalChecks',true,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_automatic_booking_preview_v1(uuid,uuid,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.confirm_player_automatic_storage_booking_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz,p_expected_cost numeric,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=p_player AND w.state='active' WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 -- Existing automatic confirmations retain their idempotent replay path.
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r JOIN airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 e ON e.request_id=r.id WHERE r.airline_id=p_airline AND r.request_key=p_request_key)
 THEN RETURN airlinerra_game.confirm_automatic_storage_booking_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure,p_expected_cost,p_request_key);END IF;
 IF airlinerra_game.storage_player_automatic_booking_enabled_v1(p_purpose) IS DISTINCT FROM true THEN RETURN jsonb_build_object('status','storage_player_automatic_booking_not_released','booked',false);END IF;
 RETURN airlinerra_game.confirm_automatic_storage_booking_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure,p_expected_cost,p_request_key);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.confirm_player_automatic_storage_booking_v1(uuid,uuid,uuid,text,text,timestamptz,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
