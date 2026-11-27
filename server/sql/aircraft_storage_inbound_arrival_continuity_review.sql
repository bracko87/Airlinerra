-- ROLLBACK-ONLY REVIEW. Install after signed movements and monthly billing,
-- before new inbound departures. Freeze departure evidence and storage terms.
-- No global shutdown bypass and no permission to create new flights.
BEGIN;
CREATE TABLE airlinerra_game.storage_inbound_departure_evidence_v1(
 request_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 departure_engine_event_id text UNIQUE NOT NULL REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 physical_flight_id text UNIQUE NOT NULL,airline_id uuid NOT NULL,aircraft_inventory_id uuid NOT NULL,owner_player_id uuid NOT NULL,
 configuration_id bigint NOT NULL,origin_airport_key text NOT NULL,destination_airport_key text NOT NULL,
 departure_utc timestamptz NOT NULL,arrival_utc timestamptz NOT NULL CHECK(arrival_utc>departure_utc),
 quoted_cost_usd numeric(14,2) NOT NULL,quote jsonb NOT NULL,
 billing_class text NOT NULL CHECK(billing_class IN('regional','narrowbody','widebody')),
 monthly_usd numeric(14,2) NOT NULL CHECK(monthly_usd>0),price_reference text NOT NULL CHECK(btrim(price_reference)<>'')
);
ALTER TABLE airlinerra_game.storage_inbound_departure_evidence_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_inbound_departure_evidence_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.capture_storage_inbound_departure_evidence_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;f record;cat record;price numeric;
BEGIN
 IF NEW.storage_request_id IS NULL OR NEW.storage_reactivation OR NEW.phase<>'departed' THEN RETURN NEW;END IF;
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=NEW.storage_request_id FOR UPDATE;
 SELECT * INTO STRICT f FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=r.destination_airport_key FOR SHARE;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(r.destination_airport_key,'storage_inbound')->>'eligible' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'STORAGE_DEPARTURE_ADMISSION_REVOKED';END IF;
 SELECT * INTO STRICT cat FROM airlinerra_game.aircraft_storage_billing_classes_v1 WHERE configuration_id=(r.quote->>'configurationId')::bigint FOR SHARE;
 price:=CASE cat.billing_class WHEN 'regional' THEN f.monthly_regional_usd WHEN 'narrowbody' THEN f.monthly_narrowbody_usd WHEN 'widebody' THEN f.monthly_widebody_usd END;
 IF price IS NULL OR price<=0 OR f.evidence_reference IS NULL THEN RAISE EXCEPTION 'STORAGE_DEPARTURE_BILLING_UNVERIFIED';END IF;
 INSERT INTO airlinerra_game.storage_inbound_departure_evidence_v1 VALUES(r.id,NEW.engine_event_id,NEW.flight_occurrence_id,r.airline_id,r.aircraft_inventory_id,r.owner_player_id,cat.configuration_id,r.origin_airport_key,r.destination_airport_key,r.departure_utc,r.arrival_utc,r.quoted_cost_usd,r.quote,cat.billing_class,price,f.evidence_reference||' | '||cat.approval_reference);
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.capture_storage_inbound_departure_evidence_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER capture_storage_inbound_departure_evidence_v1 AFTER INSERT ON airlinerra_game.section9_operated_flight_movements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.capture_storage_inbound_departure_evidence_v1();
CREATE TRIGGER storage_inbound_departure_evidence_immutable BEFORE UPDATE OR DELETE ON airlinerra_game.storage_inbound_departure_evidence_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1();
CREATE FUNCTION airlinerra_game.guard_frozen_storage_inbound_request_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_inbound_departure_evidence_v1 WHERE request_id=OLD.id) THEN IF TG_OP='DELETE' THEN RETURN OLD;END IF;RETURN NEW;END IF;
 IF TG_OP='DELETE' THEN RAISE EXCEPTION 'STORAGE_INBOUND_DEPARTURE_FROZEN';END IF;
 IF (to_jsonb(NEW)-'status') IS DISTINCT FROM (to_jsonb(OLD)-'status') OR (NEW.status IS DISTINCT FROM OLD.status AND NOT(OLD.status='awaiting_slot_and_dispatch_release' AND NEW.status='completed')) THEN RAISE EXCEPTION 'STORAGE_INBOUND_DEPARTURE_FROZEN';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_frozen_storage_inbound_request_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_frozen_storage_inbound_request_v1 BEFORE UPDATE OR DELETE ON airlinerra_game.aircraft_storage_relocation_requests_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_frozen_storage_inbound_request_v1();
CREATE OR REPLACE FUNCTION airlinerra_game.aircraft_storage_leg_evidence_v1(p_physical text)
RETURNS TABLE(request_id uuid,airline_id uuid,aircraft_inventory_id uuid,owner_player_id uuid,
 configuration_id bigint,origin_airport_key text,destination_airport_key text,
 departure_utc timestamptz,arrival_utc timestamptz,flight_local_date date,flight_occurrence_id text,
 purpose text,quoted_cost_usd numeric,quote jsonb)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT r.id,r.airline_id,r.aircraft_inventory_id,r.owner_player_id,i.configuration_id,
 r.origin_airport_key,r.destination_airport_key,r.departure_utc,r.arrival_utc,
 (r.departure_utc AT TIME ZONE 'UTC')::date,
 r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1',
 'storage_inbound'::text,r.quoted_cost_usd,r.quote
 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=r.aircraft_inventory_id AND i.airline_id=r.airline_id
 JOIN airlinerra_game.airlines a ON a.id=r.airline_id AND a.world_id=1 AND a.owner_player_id=r.owner_player_id
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=r.owner_player_id AND w.state='active'
 WHERE current_user='postgres' AND r.world_id=1 AND r.status='awaiting_slot_and_dispatch_release'
 AND i.ownership_type='owned' AND i.fleet_status='in_service'
 AND p_physical=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1'
 AND r.quote->>'status'='storage_relocation_cost_estimate'
 AND r.quote->>'passengers'='0' AND r.quote->>'cargoTonnes'='0' AND r.quote->>'ticketRevenueUsd'='0'
 AND r.quote->>'fuelRangeConfirmed'='true'
 AND (r.quote->>'directOperatingCostUsd')::numeric=r.quoted_cost_usd
 AND (r.quote->>'configurationId')::bigint=i.configuration_id
 AND r.arrival_utc=r.departure_utc+make_interval(mins=>(r.quote#>>'{phases,totalMinutes}')::integer)
 AND airlinerra_game.aircraft_storage_airport_admission_v1(r.destination_airport_key,'storage_inbound')->>'eligible'='true'
 AND EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 u
 WHERE u.world_id=1 AND u.airport_key=r.origin_airport_key AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 s
 WHERE s.world_id=1 AND s.request_id=r.id AND s.direction='departure' AND s.airport_key=r.origin_airport_key AND s.movement_utc=r.departure_utc)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 s
 WHERE s.world_id=1 AND s.request_id=r.id AND s.direction='arrival' AND s.airport_key=r.destination_airport_key AND s.movement_utc=r.arrival_utc)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.airline_id=r.airline_id AND s.aircraft_inventory_id=r.aircraft_inventory_id AND s.status='active')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j
 WHERE j.airline_id=r.airline_id AND j.aircraft_inventory_id=r.aircraft_inventory_id AND j.status IN ('scheduled','in_progress','payment_required'))
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 t
 WHERE t.aircraft_inventory_id=r.aircraft_inventory_id AND t.status='reserved')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_inbound_departure_evidence_v1 e WHERE e.request_id=r.id)
 UNION ALL
 SELECT e.request_id,e.airline_id,e.aircraft_inventory_id,e.owner_player_id,e.configuration_id,
 e.origin_airport_key,e.destination_airport_key,e.departure_utc,e.arrival_utc,
 (e.departure_utc AT TIME ZONE 'UTC')::date,e.physical_flight_id,'storage_inbound'::text,e.quoted_cost_usd,e.quote
 FROM airlinerra_game.storage_inbound_departure_evidence_v1 e
 JOIN airlinerra_game.aircraft_storage_relocation_requests_v1 r ON r.id=e.request_id
 JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=e.departure_engine_event_id
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=e.aircraft_inventory_id AND i.airline_id=e.airline_id
 WHERE current_user='postgres' AND p_physical=e.physical_flight_id AND r.status='awaiting_slot_and_dispatch_release'
 AND r.airline_id=e.airline_id AND r.aircraft_inventory_id=e.aircraft_inventory_id AND r.owner_player_id=e.owner_player_id
 AND r.origin_airport_key=e.origin_airport_key AND r.destination_airport_key=e.destination_airport_key
 AND r.departure_utc=e.departure_utc AND r.arrival_utc=e.arrival_utc AND r.quote=e.quote AND r.quoted_cost_usd=e.quoted_cost_usd
 AND i.configuration_id=e.configuration_id AND i.ownership_type='owned' AND i.fleet_status='in_service'
 AND d.phase='departed' AND d.world_id=1 AND NOT d.storage_reactivation AND d.storage_request_id=e.request_id
 AND d.airline_id=e.airline_id AND d.aircraft_inventory_id=e.aircraft_inventory_id AND d.flight_occurrence_id=e.physical_flight_id
 AND d.origin_airport_key=e.origin_airport_key AND d.destination_airport_key=e.destination_airport_key
 AND d.actual_event_utc=e.departure_utc AND d.scheduled_departure_utc=e.departure_utc AND d.scheduled_arrival_utc=e.arrival_utc;
$fn$;
-- Capture from the signed departure, not mutable airport or class prices.
CREATE OR REPLACE FUNCTION airlinerra_game.capture_storage_billing_terms_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE e record;
BEGIN
 SELECT * INTO e FROM airlinerra_game.storage_inbound_departure_evidence_v1 WHERE request_id=NEW.request_id AND airline_id=NEW.airline_id AND aircraft_inventory_id=NEW.aircraft_inventory_id AND destination_airport_key=NEW.airport_key AND physical_flight_id=NEW.physical_flight_id AND arrival_utc=NEW.storage_started_utc;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_BILLING_DEPARTURE_EVIDENCE_MISSING';END IF;
 INSERT INTO airlinerra_game.aircraft_storage_billing_terms_v1 VALUES(NEW.request_id,e.billing_class,e.monthly_usd,(NEW.storage_started_utc AT TIME ZONE 'Europe/Berlin')::date,e.price_reference);
 RETURN NEW;
END $fn$;
ROLLBACK;
