-- ROLLBACK-ONLY REVIEW. Requires game permission policy, automatic booking
-- evidence and signed movement definitions. No independent permission API.
BEGIN;
CREATE TABLE airlinerra_game.storage_game_permission_receipts_v1(
 request_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 approval_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.aircraft_storage_automatic_booking_evidence_v1(approval_id),
 airline_id uuid NOT NULL,aircraft_inventory_id uuid NOT NULL,airport_key text NOT NULL,
 operation text NOT NULL CHECK(operation IN('arrival','departure')),
 event_utc timestamptz NOT NULL,flight_departure_utc timestamptz NOT NULL,
 granted_at timestamptz NOT NULL,review_snapshot jsonb NOT NULL,
 revoked_at timestamptz,
 CHECK(granted_at<=flight_departure_utc AND flight_departure_utc<=event_utc),
 CHECK(revoked_at IS NULL OR revoked_at>=granted_at)
);
ALTER TABLE airlinerra_game.storage_game_permission_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_game_permission_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;

-- Quote eligibility is read-only. The normal automatic booking confirmation
-- uses this same screen before holding funds or allocating crew.
ALTER FUNCTION airlinerra_game.owned_aircraft_storage_operational_screen_v1(uuid,uuid,uuid,text,text,timestamptz) RENAME TO owned_aircraft_storage_base_operational_screen_v1;
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_operational_screen_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE q jsonb; j jsonb; k text;op text;at_time timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 q:=airlinerra_game.owned_aircraft_storage_base_operational_screen_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
 IF q->>'status' IS DISTINCT FROM 'storage_cost_preview_verified' OR q->>'airportScreenPassed' IS DISTINCT FROM 'true' THEN RETURN q;END IF;
 k:=CASE WHEN p_purpose='storage_reactivation' THEN q->>'originAirportKey' ELSE p_destination END;
 op:=CASE WHEN p_purpose='storage_reactivation' THEN 'departure' ELSE 'arrival' END;
 at_time:=CASE WHEN op='departure' THEN p_departure ELSE (q->>'arrivalUtc')::timestamptz END;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=k AND admission_scope='relocation_only') THEN
  j:=airlinerra_game.storage_game_permission_candidate_v1(k,op,at_time,p_departure,airlinerra_game.section9_verified_world_instant_v1());
  RETURN q||jsonb_build_object('airportScreenPassed',j->>'passed'='true','gamePermissionScreen',j-'reviewSnapshot');
 END IF;
 RETURN q;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_operational_screen_v1(uuid,uuid,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

-- This trigger is inside the existing booking transaction. A failure rolls
-- back the booking, slots, funds, crew and automatic approval together.
CREATE FUNCTION airlinerra_game.capture_storage_game_permission_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;k text;op text;at_time timestamptz;j jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=NEW.request_id;
 k:=CASE WHEN r.purpose='storage_reactivation' THEN r.origin_airport_key ELSE r.destination_airport_key END;
 op:=CASE WHEN r.purpose='storage_reactivation' THEN 'departure' ELSE 'arrival' END;
 at_time:=CASE WHEN op='departure' THEN r.departure_utc ELSE r.arrival_utc END;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=k AND admission_scope='relocation_only') THEN RETURN NEW;END IF;
 j:=airlinerra_game.storage_game_permission_candidate_v1(k,op,at_time,r.departure_utc,NEW.checked_at);
 IF j->>'passed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_GAME_PERMISSION_BLOCKED',DETAIL=coalesce(j->>'status','unknown');END IF;
 IF j->>'permissionRequired'='true' THEN
  INSERT INTO airlinerra_game.storage_game_permission_receipts_v1 VALUES(r.id,NEW.approval_id,r.airline_id,r.aircraft_inventory_id,k,op,at_time,r.departure_utc,NEW.checked_at,j->'reviewSnapshot',NULL);
 END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.capture_storage_game_permission_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER capture_storage_game_permission_v1 AFTER INSERT ON airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.capture_storage_game_permission_v1();

-- Only new departures are checked: a policy change never strands an
-- aircraft with a signed departure already in the movement history.
CREATE FUNCTION airlinerra_game.guard_storage_game_permission_departure_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; receipt record;k text;op text;at_time timestamptz;j jsonb;found_receipt boolean;
BEGIN
 IF NEW.storage_request_id IS NULL OR NEW.phase<>'departed' THEN RETURN NEW;END IF;
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=NEW.storage_request_id;
 k:=CASE WHEN r.purpose='storage_reactivation' THEN r.origin_airport_key ELSE r.destination_airport_key END;
 op:=CASE WHEN r.purpose='storage_reactivation' THEN 'departure' ELSE 'arrival' END;
 at_time:=CASE WHEN op='departure' THEN r.departure_utc ELSE r.arrival_utc END;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=k AND admission_scope='relocation_only') THEN RETURN NEW;END IF;
 SELECT * INTO receipt FROM airlinerra_game.storage_game_permission_receipts_v1 WHERE request_id=r.id FOR UPDATE;
 found_receipt:=FOUND;
 j:=airlinerra_game.storage_game_permission_candidate_v1(k,op,at_time,r.departure_utc,CASE WHEN found_receipt THEN receipt.granted_at ELSE airlinerra_game.section9_verified_world_instant_v1() END);
 IF j->>'passed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_GAME_PERMISSION_DEPARTURE_BLOCKED';END IF;
 IF found_receipt OR j->>'permissionRequired'='true' THEN
  IF NOT found_receipt OR j->>'permissionRequired' IS DISTINCT FROM 'true' OR receipt.revoked_at IS NOT NULL
   OR receipt.airline_id IS DISTINCT FROM r.airline_id OR receipt.aircraft_inventory_id IS DISTINCT FROM r.aircraft_inventory_id
   OR receipt.airport_key IS DISTINCT FROM k OR receipt.operation IS DISTINCT FROM op OR receipt.event_utc IS DISTINCT FROM at_time
   OR receipt.flight_departure_utc IS DISTINCT FROM r.departure_utc OR receipt.review_snapshot IS DISTINCT FROM j->'reviewSnapshot'
   OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 e WHERE e.request_id=r.id AND e.approval_id=receipt.approval_id AND e.checked_at=receipt.granted_at)
  THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_GAME_PERMISSION_RECEIPT_INVALID';END IF;
 END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_game_permission_departure_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_storage_game_permission_departure_v1 BEFORE INSERT ON airlinerra_game.section9_operated_flight_movements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_game_permission_departure_v1();

CREATE FUNCTION airlinerra_game.revoke_storage_game_permission_v1(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 -- Match the worker's airline-first lock order, serializing revocation with departure.
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.aircraft_storage_relocation_requests_v1 q ON q.airline_id=a.id WHERE q.id=p_request FOR UPDATE OF a;
 SELECT * INTO r FROM airlinerra_game.storage_game_permission_receipts_v1 WHERE request_id=p_request FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('revoked',false,'status','storage_game_permission_missing');END IF;
 IF r.revoked_at IS NOT NULL THEN RETURN jsonb_build_object('revoked',true,'replayed',true);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR v_now<r.granted_at OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=p_request AND phase='departed') THEN RETURN jsonb_build_object('revoked',false,'status','storage_game_permission_revocation_blocked');END IF;
 UPDATE airlinerra_game.storage_game_permission_receipts_v1 SET revoked_at=v_now WHERE request_id=p_request;
 RETURN jsonb_build_object('revoked',true,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.revoke_storage_game_permission_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
