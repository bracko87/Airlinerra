-- REVIEW ONLY. Player-facing readiness and tail-scoped cancellation.
BEGIN;
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_booking_preview_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE q jsonb; eligible boolean:=false;
BEGIN
 q:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
 IF q->>'status'='storage_cost_preview_verified' THEN
 eligible:=EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_release_v1 WHERE world_id=1 AND enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_execution_release_v1 WHERE world_id=1 AND execution_enabled AND fuel_adapter_enabled)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled)
 AND (p_purpose='storage_inbound' OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled))
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_approvals_v1 a JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=a.aircraft_inventory_id AND i.configuration_id=a.configuration_id AND i.airline_id=a.airline_id
 WHERE a.airline_id=p_airline AND a.aircraft_inventory_id=p_aircraft AND a.purpose=p_purpose AND a.origin_airport_key=q->>'originAirportKey' AND a.destination_airport_key=p_destination AND a.departure_utc=p_departure
 AND a.arrival_utc=(q->>'arrivalUtc')::timestamptz AND a.relocation_usd=(q->>'relocationUsd')::numeric AND a.approved_at<=airlinerra_game.section9_verified_world_instant_v1() AND a.revoked_at IS NULL AND a.consumed_request_id IS NULL);
 END IF;
 RETURN q||jsonb_build_object('bookingEligible',eligible);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_booking_preview_v1(uuid,uuid,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_player_overview_v1(p_player uuid,p_airline uuid,p_aircraft uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE q jsonb;
BEGIN
 q:=airlinerra_game.owned_aircraft_storage_overview_v1(p_player,p_airline,p_aircraft);
 RETURN q||jsonb_build_object('cancellationEligible',q->>'ownershipType'='owned' AND q#>>'{pendingRequest,departed}'='false' AND q#>>'{pendingRequest,requestId}' IS NOT NULL);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_player_overview_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.cancel_owned_aircraft_storage_booking_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; j jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE a.id=p_airline AND a.world_id=1 AND a.owner_player_id=p_player FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request AND airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND owner_player_id=p_player FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF r.status='completed' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='departed') THEN RETURN jsonb_build_object('status','storage_flight_already_departed','cancelled',false,'requestId',r.id);END IF;
 j:=airlinerra_game.cancel_aircraft_storage_relocation_request_v1(p_player,p_airline,p_request);
 RETURN j||jsonb_build_object('cancelled',j->>'status'='cancelled','requestId',r.id);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.cancel_owned_aircraft_storage_booking_v1(uuid,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
