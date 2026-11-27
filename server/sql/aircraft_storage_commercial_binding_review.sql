-- ROLLBACK-ONLY REVIEW. Atomic handoff departure binding.
-- This release remains disabled. Install together with the reviewed
-- commercial dispatcher adapter and signed crew readiness functions.
BEGIN;
CREATE TABLE airlinerra_game.storage_commercial_binding_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.storage_commercial_binding_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.storage_commercial_departure_crew_evidence_v1(
 departure_event_id text PRIMARY KEY REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id) DEFERRABLE INITIALLY DEFERRED,
 physical_flight_id text UNIQUE NOT NULL,airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 plan_id uuid NOT NULL REFERENCES airlinerra_game.storage_crew_plan_handoffs_v1(plan_id),occurrence_id uuid NOT NULL,
 aircraft_inventory_id uuid NOT NULL,configuration_id bigint NOT NULL,qualification_group text NOT NULL,
 captain_ids uuid[] NOT NULL,first_officer_ids uuid[] NOT NULL,cabin_member_ids uuid[] NOT NULL,
 normalized_duties jsonb NOT NULL CHECK(jsonb_typeof(normalized_duties)='array'),
 CHECK(cardinality(captain_ids) IN(1,2) AND cardinality(first_officer_ids)=cardinality(captain_ids))
);
ALTER TABLE airlinerra_game.storage_commercial_binding_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.storage_commercial_departure_crew_evidence_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_commercial_binding_release_v1,airlinerra_game.storage_commercial_departure_crew_evidence_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER storage_commercial_departure_evidence_immutable BEFORE UPDATE OR DELETE ON airlinerra_game.storage_commercial_departure_crew_evidence_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1();

CREATE FUNCTION airlinerra_game.storage_commercial_normalized_duties_v1(p_airline uuid,p_plan uuid,p_occurrence uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE result jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('seat',to_jsonb(s),'duty',to_jsonb(d)) ORDER BY s.employee_id),'[]'::jsonb) INTO result
 FROM airlinerra_game.section9_planned_crew_seats_v1 s
 JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id
 WHERE s.airline_id=p_airline AND s.plan_id=p_plan AND s.occurrence_id=p_occurrence;
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_commercial_normalized_duties_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

-- Replace the conservative guard only for an exactly matched handoff when
-- ALL release switches are enabled. Never bypass normal signed movement rules.
CREATE OR REPLACE FUNCTION airlinerra_game.guard_commercial_departure_storage_handoff_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE j jsonb;f record;cp uuid[];fo uuid[];ca uuid[];duties jsonb;cfg bigint;
BEGIN
 IF NEW.storage_request_id IS NOT NULL OR NEW.schedule_id IS NULL OR NEW.phase<>'departed' THEN RETURN NEW;END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id AND world_id=1 FOR UPDATE;
 j:=airlinerra_game.storage_commercial_handoff_dispatch_check_v1(NEW.airline_id,NEW.flight_occurrence_id);
 IF j->>'allowed' IS NOT DISTINCT FROM 'true' THEN RETURN NEW;END IF;
 IF j->>'status' IS DISTINCT FROM 'storage_handoff_dispatch_integration_required'
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_binding_release_v1 WHERE world_id=1 AND enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoff_release_v1 WHERE world_id=1 AND enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled)
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_HANDOFF_DISPATCH_BLOCKED';END IF;
 SELECT pf.* INTO STRICT f FROM airlinerra_game.section9_planned_flight_crews_v1 pf
 JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview'
 JOIN airlinerra_game.storage_crew_plan_handoffs_v1 h ON h.plan_id=pf.plan_id AND h.airline_id=pf.airline_id
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=pf.occurrence_id AND o.airline_id=pf.airline_id
 WHERE pf.airline_id=NEW.airline_id AND pf.physical_flight_id=NEW.flight_occurrence_id AND pf.aircraft_inventory_id=NEW.aircraft_inventory_id
 AND o.world_id=1 AND o.schedule_id=NEW.schedule_id AND o.schedule_version=NEW.schedule_version AND o.flight_local_date=NEW.flight_local_date AND o.weekly_entry=NEW.weekly_entry
 AND pf.schedule_version=NEW.schedule_version AND pf.origin_airport_key=NEW.origin_airport_key AND pf.destination_airport_key=NEW.destination_airport_key
 AND pf.departure_utc=NEW.scheduled_departure_utc AND pf.arrival_utc=NEW.scheduled_arrival_utc AND pf.departure_utc=NEW.actual_event_utc;
 IF NEW.world_id<>1 OR NEW.source_kind IS DISTINCT FROM 'signed_operated_game_flight_v1' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_MOVEMENT_IDENTITY_INVALID';END IF;
 j:=airlinerra_game.storage_commercial_crew_departure_readiness_v1(NEW.airline_id,NEW.flight_occurrence_id);
 IF j->>'passed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_READINESS_FAILED',DETAIL=coalesce(j->>'status','unknown');END IF;
 SELECT configuration_id INTO STRICT cfg FROM airlinerra_game.airline_aircraft_inventory WHERE id=f.aircraft_inventory_id AND airline_id=f.airline_id;
 SELECT coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='captain'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='first_officer'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='cabin'),'{}')
 INTO cp,fo,ca FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE airline_id=f.airline_id AND plan_id=f.plan_id AND occurrence_id=f.occurrence_id;
 duties:=airlinerra_game.storage_commercial_normalized_duties_v1(f.airline_id,f.plan_id,f.occurrence_id);
 IF cardinality(cp)<>f.captain_count OR cardinality(fo)<>f.first_officer_count OR cardinality(ca)<>f.cabin_count OR jsonb_array_length(duties)<>cardinality(cp)+cardinality(fo)+cardinality(ca) THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_MANIFEST_CHANGED';END IF;
 INSERT INTO airlinerra_game.storage_commercial_departure_crew_evidence_v1 VALUES(NEW.engine_event_id,NEW.flight_occurrence_id,NEW.airline_id,f.plan_id,f.occurrence_id,NEW.aircraft_inventory_id,cfg,f.qualification_group,cp,fo,ca,duties);
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_commercial_departure_storage_handoff_v1() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.storage_commercial_departure_binding_exact_v1(p_event text)
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE e record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO e FROM airlinerra_game.storage_commercial_departure_crew_evidence_v1 WHERE departure_event_id=p_event;
 IF NOT FOUND THEN RETURN false;END IF;
 RETURN EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_pilot_departure_manifests_v1 m ON m.physical_flight_id=b.physical_flight_id AND m.airline_id=b.airline_id AND m.departure_event_id=b.departure_event_id
 JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 fuel ON fuel.physical_flight_id=b.physical_flight_id AND fuel.departure_engine_event_id=b.departure_event_id AND fuel.airline_id=b.airline_id
 JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=b.departure_event_id AND d.flight_occurrence_id=b.physical_flight_id AND d.airline_id=b.airline_id
 WHERE b.physical_flight_id=e.physical_flight_id AND b.airline_id=e.airline_id AND b.departure_event_id=e.departure_event_id AND b.plan_id=e.plan_id AND b.occurrence_id=e.occurrence_id AND b.cabin_member_ids=e.cabin_member_ids
 AND m.configuration_id=e.configuration_id AND m.qualification_group=e.qualification_group AND m.captain_ids=e.captain_ids AND m.first_officer_ids=e.first_officer_ids
 AND fuel.configuration_id=e.configuration_id AND fuel.aircraft_inventory_id=e.aircraft_inventory_id
 AND d.phase='departed' AND d.world_id=1 AND d.storage_request_id IS NULL AND d.schedule_id IS NOT NULL AND d.source_kind='signed_operated_game_flight_v1' AND d.aircraft_inventory_id=e.aircraft_inventory_id)
 AND airlinerra_game.storage_commercial_normalized_duties_v1(e.airline_id,e.plan_id,e.occurrence_id)=e.normalized_duties;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_commercial_departure_binding_exact_v1(text) FROM PUBLIC,anon,authenticated,service_role;

-- Called after signed fuel receipt, before the commercial transaction commits.
-- Failure raises rather than degrading to advisory crew tracking.
CREATE FUNCTION airlinerra_game.bind_storage_aware_commercial_departure_v1(p_airline uuid,p_physical text,p_event text)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE e record;j jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 SELECT * INTO e FROM airlinerra_game.storage_commercial_departure_crew_evidence_v1 WHERE departure_event_id=p_event AND airline_id=p_airline AND physical_flight_id=p_physical;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_DEPARTURE_EVIDENCE_MISSING';END IF;
 IF airlinerra_game.storage_commercial_departure_binding_exact_v1(p_event) THEN RETURN jsonb_build_object('status','crew_departure_already_bound','replayed',true);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_binding_release_v1 WHERE world_id=1 AND enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoff_release_v1 WHERE world_id=1 AND enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled)
 OR airlinerra_game.storage_commercial_normalized_duties_v1(e.airline_id,e.plan_id,e.occurrence_id) IS DISTINCT FROM e.normalized_duties
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 fuel JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=fuel.departure_engine_event_id AND d.flight_occurrence_id=fuel.physical_flight_id AND d.airline_id=fuel.airline_id AND d.aircraft_inventory_id=fuel.aircraft_inventory_id
 WHERE fuel.physical_flight_id=p_physical AND fuel.departure_engine_event_id=p_event AND fuel.airline_id=p_airline AND fuel.configuration_id=e.configuration_id AND fuel.aircraft_inventory_id=e.aircraft_inventory_id AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1' AND d.storage_request_id IS NULL AND d.schedule_id IS NOT NULL)
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_BINDING_EVIDENCE_INVALID';END IF;
 j:=airlinerra_game.section9_record_pilot_departure_manifest_v1(p_airline,p_physical,e.captain_ids,e.first_officer_ids);
 IF j->>'status' IS NULL OR j->>'status' NOT IN('pilot_manifest_recorded','manifest_already_recorded') THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_PILOT_MANIFEST_FAILED';END IF;
 INSERT INTO airlinerra_game.section9_operated_crew_bindings_v1(physical_flight_id,airline_id,plan_id,occurrence_id,departure_event_id,cabin_member_ids)
 VALUES(p_physical,p_airline,e.plan_id,e.occurrence_id,p_event,e.cabin_member_ids);
 IF airlinerra_game.storage_commercial_departure_binding_exact_v1(p_event) IS DISTINCT FROM true THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_BINDING_MISMATCH';END IF;
 RETURN jsonb_build_object('status','crew_departure_bound','replayed',false,'pilotCount',cardinality(e.captain_ids)+cardinality(e.first_officer_ids),'cabinCount',cardinality(e.cabin_member_ids));
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.bind_storage_aware_commercial_departure_v1(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;

-- Commit-time backstop even if a caller forgets to invoke the binding adapter.
CREATE FUNCTION airlinerra_game.require_storage_commercial_binding_at_commit_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_departure_crew_evidence_v1 WHERE departure_event_id=NEW.engine_event_id)
 AND airlinerra_game.storage_commercial_departure_binding_exact_v1(NEW.engine_event_id) IS DISTINCT FROM true
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_DEPARTURE_NOT_BOUND';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.require_storage_commercial_binding_at_commit_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE CONSTRAINT TRIGGER require_storage_commercial_binding_at_commit_v1 AFTER INSERT ON airlinerra_game.section9_operated_flight_movements_v1 DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION airlinerra_game.require_storage_commercial_binding_at_commit_v1();
ROLLBACK;
