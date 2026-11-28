-- ROLLBACK-ONLY REVIEW. Atomic owner-confirmed storage booking.
-- No release seed enabled. Approval is private, exact-flight evidence, not a player assertion.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_booking_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.aircraft_storage_booking_release_v1(world_id) VALUES(1);
ALTER TABLE airlinerra_game.aircraft_storage_booking_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_booking_release_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE airlinerra_game.aircraft_storage_booking_approvals_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 purpose text NOT NULL CHECK(purpose IN('storage_inbound','storage_reactivation')),configuration_id bigint NOT NULL,
 origin_airport_key text NOT NULL,destination_airport_key text NOT NULL,
 departure_utc timestamptz NOT NULL,arrival_utc timestamptz NOT NULL,relocation_usd numeric(14,2) NOT NULL CHECK(relocation_usd>0),
 runway_review_reference text NOT NULL CHECK(btrim(runway_review_reference)<>''),
 airport_restriction_review_reference text NOT NULL CHECK(btrim(airport_restriction_review_reference)<>''),
 ferry_licence_review_reference text NOT NULL CHECK(btrim(ferry_licence_review_reference)<>''),
 crew_review_reference text NOT NULL CHECK(btrim(crew_review_reference)<>''),
 approved_at timestamptz NOT NULL,revoked_at timestamptz,
 consumed_request_id uuid UNIQUE REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 CHECK(arrival_utc>departure_utc AND (revoked_at IS NULL OR revoked_at>=approved_at))
);
ALTER TABLE airlinerra_game.aircraft_storage_booking_approvals_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_booking_approvals_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.confirm_owned_aircraft_storage_booking_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz,p_expected_cost numeric,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE a record; i record; old record; approval record; r record; q jsonb; j jsonb; result jsonb; rid uuid; stage text; v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_purpose IS NULL OR p_purpose NOT IN('storage_inbound','storage_reactivation') OR p_request_key IS NULL OR p_expected_cost IS NULL OR p_expected_cost<=0 OR p_expected_cost<>round(p_expected_cost,2) OR p_departure IS NULL OR p_destination IS NULL
 THEN RETURN jsonb_build_object('status','invalid_storage_booking','booked',false);END IF;
 SELECT x.* INTO a FROM airlinerra_game.airlines x JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE x.id=p_airline AND x.world_id=1 AND x.owner_player_id=p_player FOR UPDATE OF x;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO i FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO old FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE airline_id=p_airline AND request_key=p_request_key FOR UPDATE;
 IF FOUND THEN
  IF old.owner_player_id<>p_player OR old.aircraft_inventory_id<>p_aircraft OR old.purpose<>p_purpose OR old.destination_airport_key<>p_destination OR old.departure_utc<>p_departure OR old.quoted_cost_usd<>p_expected_cost THEN
   RETURN jsonb_build_object('status','storage_request_key_conflict','booked',false);END IF;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_approvals_v1 WHERE consumed_request_id=old.id) THEN RETURN jsonb_build_object('status','storage_booking_not_confirmed','booked',false);END IF;
  RETURN jsonb_build_object('status',old.status,'requestId',old.id,'booked',old.status<>'cancelled','replayed',true);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_release_v1 WHERE world_id=1 AND enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_execution_release_v1 WHERE world_id=1 AND execution_enabled AND fuel_adapter_enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled)
 OR (p_purpose='storage_reactivation' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled))
 THEN RETURN jsonb_build_object('status','storage_booking_not_released','booked',false);END IF;
 q:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
 IF q->>'status' IS DISTINCT FROM 'storage_cost_preview_verified' THEN RETURN jsonb_build_object('status',q->>'status','booked',false);END IF;
 IF (q->>'relocationUsd')::numeric IS DISTINCT FROM p_expected_cost THEN RETURN jsonb_build_object('status','storage_price_changed','booked',false,'preview',q);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT * INTO approval FROM airlinerra_game.aircraft_storage_booking_approvals_v1
 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND purpose=p_purpose AND configuration_id=i.configuration_id
 AND origin_airport_key=q->>'originAirportKey' AND destination_airport_key=p_destination AND departure_utc=p_departure AND arrival_utc=(q->>'arrivalUtc')::timestamptz
 AND relocation_usd=p_expected_cost AND approved_at<=v_now AND revoked_at IS NULL AND consumed_request_id IS NULL
 ORDER BY approved_at DESC,id LIMIT 1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_booking_clearance_missing','booked',false);END IF;
 -- Exception block is a subtransaction: a returned failure in any stage
 -- rolls back the request, slot pair, hold and clearance together.
 BEGIN
  IF p_purpose='storage_inbound' THEN
   j:=airlinerra_game.request_aircraft_storage_relocation_v1(p_player,p_airline,p_aircraft,p_destination,p_departure,p_expected_cost,p_request_key);
  ELSE
   j:=airlinerra_game.request_aircraft_storage_reactivation_v1(p_player,p_airline,p_aircraft,p_destination,p_departure,p_expected_cost,p_request_key);
  END IF;
  IF j->>'created' IS DISTINCT FROM 'true' THEN stage:=coalesce(j->>'status','storage_request_failed');RAISE EXCEPTION USING ERRCODE='PZ001';END IF;
  rid:=(j->>'requestId')::uuid;
  IF p_purpose='storage_inbound' THEN j:=airlinerra_game.reserve_aircraft_storage_slots_v1(p_player,p_airline,rid);
  ELSE j:=airlinerra_game.reserve_aircraft_reactivation_slots_v1(p_player,p_airline,rid);END IF;
  IF j->>'slotsReserved' IS DISTINCT FROM '2' THEN stage:=coalesce(j->>'status','storage_slots_failed');RAISE EXCEPTION USING ERRCODE='PZ001';END IF;
  IF p_purpose='storage_inbound' THEN j:=airlinerra_game.hold_aircraft_storage_funds_v1(p_player,p_airline,rid);
  ELSE j:=airlinerra_game.hold_aircraft_reactivation_funds_v1(p_player,p_airline,rid);END IF;
  IF j->>'fundsHeld' IS DISTINCT FROM 'true' THEN stage:=coalesce(j->>'status','storage_funds_failed');RAISE EXCEPTION USING ERRCODE='PZ001';END IF;
  INSERT INTO airlinerra_game.aircraft_storage_dispatch_clearance_v1(request_id,configuration_id,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,runway_review_reference,airport_restriction_review_reference,ferry_licence_review_reference,crew_review_reference,approved_at)
  VALUES(rid,approval.configuration_id,approval.origin_airport_key,approval.destination_airport_key,approval.departure_utc,approval.arrival_utc,approval.runway_review_reference,approval.airport_restriction_review_reference,approval.ferry_licence_review_reference,approval.crew_review_reference,approval.approved_at);
  UPDATE airlinerra_game.aircraft_storage_booking_approvals_v1 SET consumed_request_id=rid WHERE id=approval.id AND consumed_request_id IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_BOOKING_APPROVAL_CONFLICT';END IF;
  result:=jsonb_build_object('status','storage_booking_reserved','booked',true,'requestId',rid,'slotsReserved',2,'fundsHeld',true,'departureUtc',p_departure,'arrivalUtc',approval.arrival_utc,'relocationUsd',p_expected_cost,'movementRecorded',false,'replayed',false);
 EXCEPTION WHEN SQLSTATE 'PZ001' THEN
  RETURN jsonb_build_object('status',stage,'booked',false,'slotsReserved',0,'fundsHeld',false);
 END;
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.confirm_owned_aircraft_storage_booking_v1(uuid,uuid,uuid,text,text,timestamptz,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
