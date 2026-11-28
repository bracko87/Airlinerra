-- ROLLBACK-ONLY REVIEW. Atomic crew-bound booking wrapper.
-- Not connected to the player API until the signed crew history handoff
-- and dispatch-time validation are complete. No release is enabled.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_crew_booking_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.aircraft_storage_crew_booking_release_v1(world_id) VALUES(1);
ALTER TABLE airlinerra_game.aircraft_storage_crew_booking_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_crew_booking_release_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.confirm_crew_bound_storage_booking_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz,p_expected_cost numeric,p_request_key uuid)
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
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s WHERE s.airline_id=p_airline AND s.status<>'cancelled' AND s.employee_id::text IN(SELECT jsonb_array_elements_text((q->'candidateCaptains')||(q->'candidateFirstOfficers')||(q->'candidateCabinCrew')))) THEN RETURN jsonb_build_object('status','storage_crew_already_reserved','booked',false);END IF;
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
REVOKE ALL ON FUNCTION airlinerra_game.confirm_crew_bound_storage_booking_v1(uuid,uuid,uuid,text,text,timestamptz,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
