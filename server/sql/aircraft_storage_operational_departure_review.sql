-- ROLLBACK-ONLY REVIEW. Final operational screen at signed departure.
-- A booking approval is not permanent permission to take off.
BEGIN;
CREATE TABLE airlinerra_game.storage_operational_departure_release_v1(world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false);
INSERT INTO airlinerra_game.storage_operational_departure_release_v1(world_id) VALUES(1);
ALTER TABLE airlinerra_game.storage_operational_departure_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_operational_departure_release_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.storage_operational_departure_check_v1(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE r record;i record;c record;v_now timestamptz;o jsonb;d jsonb;lic jsonb;crew jsonb;outbound boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request;
 IF NOT FOUND OR r.status NOT IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review') THEN RETURN jsonb_build_object('passed',false,'status','storage_operational_request_invalid');END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR v_now<r.departure_utc OR v_now>=r.departure_utc+interval '10 minutes' THEN RETURN jsonb_build_object('passed',false,'status','storage_operational_clock_invalid');END IF;
 SELECT * INTO i FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id AND ownership_type='owned';
 IF NOT FOUND OR i.configuration_id IS DISTINCT FROM (r.quote->>'configurationId')::bigint THEN RETURN jsonb_build_object('passed',false,'status','storage_operational_configuration_changed');END IF;
 SELECT * INTO c FROM airlinerra_game.aircraft_storage_dispatch_clearance_v1 WHERE request_id=r.id AND configuration_id=i.configuration_id AND origin_airport_key=r.origin_airport_key AND destination_airport_key=r.destination_airport_key AND departure_utc=r.departure_utc AND arrival_utc=r.arrival_utc AND approved_at<=r.departure_utc AND revoked_at IS NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('passed',false,'status','storage_operational_clearance_invalid');END IF;
 -- Automatic approvals must have exact consumed evidence and live release.
 IF c.crew_review_reference LIKE 'auto-booking:%' THEN
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_automatic_booking_release_v1 WHERE world_id=1 AND enabled)
  OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 e JOIN airlinerra_game.aircraft_storage_booking_approvals_v1 a ON a.id=e.approval_id
   WHERE e.request_id=r.id AND a.consumed_request_id=r.id AND a.airline_id=r.airline_id AND a.aircraft_inventory_id=r.aircraft_inventory_id AND a.purpose=r.purpose AND a.configuration_id=i.configuration_id
    AND a.origin_airport_key=r.origin_airport_key AND a.destination_airport_key=r.destination_airport_key AND a.departure_utc=r.departure_utc AND a.arrival_utc=r.arrival_utc AND a.relocation_usd=r.quoted_cost_usd AND a.revoked_at IS NULL
    AND c.crew_review_reference='auto-booking:'||a.id::text AND c.runway_review_reference=a.runway_review_reference AND c.airport_restriction_review_reference=a.airport_restriction_review_reference AND c.ferry_licence_review_reference=a.ferry_licence_review_reference)
  THEN RETURN jsonb_build_object('passed',false,'status','storage_automatic_approval_revoked_or_missing');END IF;
 END IF;
 outbound:=r.purpose='storage_reactivation';
 o:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(r.origin_airport_key,i.configuration_id,'departure',r.departure_utc,outbound);
 d:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(r.destination_airport_key,i.configuration_id,'arrival',r.arrival_utc,NOT outbound);
 IF o->>'passed' IS DISTINCT FROM 'true' OR d->>'passed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status','storage_operational_airport_changed');END IF;
 lic:=airlinerra_game.aircraft_storage_ferry_licence_screen_v1(r.airline_id,r.purpose,r.origin_airport_key,r.destination_airport_key,r.departure_utc,r.arrival_utc);
 IF lic->>'allowed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status','storage_operational_licence_changed');END IF;
 crew:=airlinerra_game.storage_crew_departure_check_v1(r.id);
 IF crew->>'passed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status','storage_operational_crew_changed','crewStatus',crew->>'status');END IF;
 RETURN jsonb_build_object('passed',true,'status','storage_operational_departure_revalidated','checkedAtUtc',v_now,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_operational_departure_check_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.guard_storage_operational_departure_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE j jsonb; automatic boolean;
BEGIN
 IF NEW.storage_request_id IS NULL OR NEW.phase<>'departed' THEN RETURN NEW;END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id FOR UPDATE;
 SELECT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_dispatch_clearance_v1 c WHERE c.request_id=NEW.storage_request_id AND c.crew_review_reference LIKE 'auto-booking:%') INTO automatic;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_operational_departure_release_v1 WHERE world_id=1 AND enabled) THEN
  IF automatic THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_OPERATIONAL_DEPARTURE_NOT_RELEASED';END IF;
  RETURN NEW;
 END IF;
 j:=airlinerra_game.storage_operational_departure_check_v1(NEW.storage_request_id);
 IF j->>'passed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_OPERATIONAL_DEPARTURE_REVALIDATION_FAILED',DETAIL=coalesce(j->>'status','unknown');END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_operational_departure_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_storage_operational_departure_v1 BEFORE INSERT ON airlinerra_game.section9_operated_flight_movements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_operational_departure_v1();
ROLLBACK;
