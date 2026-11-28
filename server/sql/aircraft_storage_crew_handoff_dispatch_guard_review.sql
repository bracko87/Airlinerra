-- ROLLBACK-ONLY REVIEW. Protect signed storage history and prevent premature
-- commercial dispatch from consuming a promoted review plan.
-- A reviewed plan is not yet a released commercial dispatch plan.
BEGIN;
CREATE FUNCTION airlinerra_game.guard_storage_crew_receipt_immutability_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; a record; pol record;
BEGIN
 IF TG_OP='DELETE' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_CREW_RECEIPT_IMMUTABLE';END IF;
 IF OLD.arrival_engine_event_id IS NOT NULL OR OLD.completed_duty_end_utc IS NOT NULL
 OR (to_jsonb(NEW)-ARRAY['arrival_engine_event_id','actual_arrival_utc','completed_duty_end_utc','rest_complete_utc']) IS DISTINCT FROM
 (to_jsonb(OLD)-ARRAY['arrival_engine_event_id','actual_arrival_utc','completed_duty_end_utc','rest_complete_utc'])
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_CREW_RECEIPT_IMMUTABLE';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=OLD.request_id AND airline_id=OLD.airline_id AND status='completed';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_CREW_COMPLETION_NOT_VERIFIED';END IF;
 SELECT * INTO a FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=NEW.arrival_engine_event_id AND phase='arrived' AND storage_request_id=r.id AND airline_id=r.airline_id AND aircraft_inventory_id=r.aircraft_inventory_id AND origin_airport_key=r.origin_airport_key AND destination_airport_key=r.destination_airport_key AND actual_event_utc=r.arrival_utc;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_CREW_COMPLETION_NOT_VERIFIED';END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF pol.postflight_minutes IS NULL OR pol.minimum_rest_minutes IS NULL OR pol.minimum_rest_minutes<720
 OR NEW.actual_arrival_utc IS DISTINCT FROM a.actual_event_utc
 OR NEW.completed_duty_end_utc IS DISTINCT FROM a.actual_event_utc+make_interval(mins=>pol.postflight_minutes)
 OR NEW.rest_complete_utc IS DISTINCT FROM NEW.completed_duty_end_utc+make_interval(mins=>pol.minimum_rest_minutes)
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_CREW_COMPLETION_NOT_VERIFIED';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_crew_receipt_immutability_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_storage_crew_receipt_immutability_v1 BEFORE UPDATE OR DELETE ON airlinerra_game.aircraft_storage_crew_duty_receipts_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_crew_receipt_immutability_v1();

CREATE FUNCTION airlinerra_game.storage_commercial_handoff_dispatch_check_v1(p_airline uuid,p_physical text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF EXISTS(
 SELECT 1 FROM airlinerra_game.section9_planned_flight_crews_v1 f
 JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=f.plan_id AND b.airline_id=f.airline_id AND b.status='validated_preview'
 JOIN airlinerra_game.storage_crew_plan_handoffs_v1 h ON h.plan_id=f.plan_id AND h.airline_id=f.airline_id
 WHERE f.airline_id=p_airline AND f.physical_flight_id=p_physical
 ) THEN RETURN jsonb_build_object('allowed',false,'status','storage_handoff_dispatch_integration_required');END IF;
 IF EXISTS(
 SELECT 1 FROM airlinerra_game.section9_planned_flight_crews_v1 f
 JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=f.plan_id AND b.airline_id=f.airline_id AND b.status='validated_preview'
 JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=f.plan_id AND s.airline_id=f.airline_id AND s.occurrence_id=f.occurrence_id
 JOIN airlinerra_game.aircraft_storage_crew_reservations_v1 c ON c.airline_id=s.airline_id AND c.employee_id=s.employee_id AND c.status<>'cancelled'
 WHERE f.airline_id=p_airline AND f.physical_flight_id=p_physical
 ) THEN RETURN jsonb_build_object('allowed',false,'status','storage_crew_custody_conflict');END IF;
 RETURN jsonb_build_object('allowed',true,'status','no_storage_handoff_conflict','commercialDispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_commercial_handoff_dispatch_check_v1(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.guard_commercial_departure_storage_handoff_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE j jsonb;
BEGIN
 IF NEW.storage_request_id IS NOT NULL OR NEW.schedule_id IS NULL OR NEW.phase<>'departed' THEN RETURN NEW;END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id AND world_id=1 FOR UPDATE;
 j:=airlinerra_game.storage_commercial_handoff_dispatch_check_v1(NEW.airline_id,NEW.flight_occurrence_id);
 IF j->>'allowed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_HANDOFF_DISPATCH_BLOCKED';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_commercial_departure_storage_handoff_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_commercial_departure_storage_handoff_v1 BEFORE INSERT ON airlinerra_game.section9_operated_flight_movements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_commercial_departure_storage_handoff_v1();
ROLLBACK;
