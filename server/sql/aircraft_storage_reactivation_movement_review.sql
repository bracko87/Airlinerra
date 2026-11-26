-- ROLLBACK-ONLY REVIEW. Requires inbound movement, billing and reactivation reservation schemas.
-- Maintain legacy FK guarantees, introduce a purpose-specific outbound origin.
BEGIN;
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ADD COLUMN storage_reactivation boolean NOT NULL DEFAULT false,
 ADD CONSTRAINT storage_reactivation_parent_required CHECK(NOT storage_reactivation OR storage_request_id IS NOT NULL),
 DROP CONSTRAINT section9_operated_flight_movements_unified_origin_fk,
 DROP CONSTRAINT section9_movement_legacy_destination_fk,
 DROP CONSTRAINT section9_movement_storage_destination_fk,
 DROP COLUMN legacy_destination_airport_key,
 DROP COLUMN storage_destination_airport_key;
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ADD COLUMN legacy_origin_airport_key text GENERATED ALWAYS AS (CASE WHEN NOT storage_reactivation THEN origin_airport_key END) STORED,
 ADD COLUMN storage_origin_airport_key text GENERATED ALWAYS AS (CASE WHEN storage_reactivation THEN origin_airport_key END) STORED,
 ADD COLUMN legacy_destination_airport_key text GENERATED ALWAYS AS (CASE WHEN storage_request_id IS NULL OR storage_reactivation THEN destination_airport_key END) STORED,
 ADD COLUMN storage_destination_airport_key text GENERATED ALWAYS AS (CASE WHEN storage_request_id IS NOT NULL AND NOT storage_reactivation THEN destination_airport_key END) STORED;
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ADD CONSTRAINT section9_movement_legacy_origin_fk FOREIGN KEY(world_id,legacy_origin_airport_key) REFERENCES airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key),
 ADD CONSTRAINT section9_movement_storage_origin_fk FOREIGN KEY(world_id,storage_origin_airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key),
 ADD CONSTRAINT section9_movement_legacy_destination_fk FOREIGN KEY(world_id,legacy_destination_airport_key) REFERENCES airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key),
 ADD CONSTRAINT section9_movement_storage_destination_fk FOREIGN KEY(world_id,storage_destination_airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key);
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1
 ADD COLUMN storage_reactivation boolean NOT NULL DEFAULT false,
 ADD CONSTRAINT storage_position_reactivation_parent_required CHECK(NOT storage_reactivation OR storage_request_id IS NOT NULL),
 DROP CONSTRAINT section9_position_legacy_airport_fk,
 DROP CONSTRAINT section9_position_storage_airport_fk,
 DROP COLUMN legacy_airport_key,
 DROP COLUMN storage_airport_key;
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1
 ADD COLUMN legacy_airport_key text GENERATED ALWAYS AS (CASE WHEN storage_request_id IS NULL OR storage_reactivation THEN airport_key END) STORED,
 ADD COLUMN storage_airport_key text GENERATED ALWAYS AS (CASE WHEN storage_request_id IS NOT NULL AND NOT storage_reactivation THEN airport_key END) STORED;
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1
 ADD CONSTRAINT section9_position_legacy_airport_fk FOREIGN KEY(world_id,legacy_airport_key) REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key),
 ADD CONSTRAINT section9_position_storage_airport_fk FOREIGN KEY(world_id,storage_airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key);
CREATE TABLE airlinerra_game.aircraft_storage_reactivation_release_v1(world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false);
INSERT INTO airlinerra_game.aircraft_storage_reactivation_release_v1(world_id) VALUES(1);
ALTER TABLE airlinerra_game.aircraft_storage_reactivation_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_reactivation_release_v1 FROM PUBLIC,anon,authenticated,service_role;

-- After departure, retain exact evidence even if the origin facility is suspended.
-- Arrival must not be blocked by subsequent admission changes.
CREATE FUNCTION airlinerra_game.aircraft_storage_any_leg_evidence_v1(p_physical text)
RETURNS TABLE(request_id uuid,airline_id uuid,aircraft_inventory_id uuid,owner_player_id uuid,configuration_id bigint,origin_airport_key text,destination_airport_key text,departure_utc timestamptz,arrival_utc timestamptz,flight_local_date date,flight_occurrence_id text,purpose text,quoted_cost_usd numeric,quote jsonb)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT * FROM airlinerra_game.aircraft_storage_leg_evidence_v1(p_physical)
 UNION ALL
 SELECT r.id,r.airline_id,r.aircraft_inventory_id,r.owner_player_id,(r.quote->>'configurationId')::bigint,r.origin_airport_key,r.destination_airport_key,r.departure_utc,r.arrival_utc,(r.departure_utc AT TIME ZONE 'UTC')::date,p_physical,r.purpose,r.quoted_cost_usd,r.quote
 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=r.aircraft_inventory_id AND i.airline_id=r.airline_id AND i.configuration_id=(r.quote->>'configurationId')::bigint AND i.ownership_type='owned'
 WHERE current_user='postgres' AND r.purpose='storage_reactivation' AND r.status='reactivation_awaiting_review'
 AND p_physical=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1'
 AND (airlinerra_game.reactivation_reservation_evidence_v1(r.id)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 d WHERE d.storage_request_id=r.id AND d.storage_reactivation AND d.phase='departed' AND d.flight_occurrence_id=p_physical AND d.airline_id=r.airline_id AND d.aircraft_inventory_id=r.aircraft_inventory_id AND d.origin_airport_key=r.origin_airport_key AND d.destination_airport_key=r.destination_airport_key AND d.actual_event_utc=r.departure_utc AND d.scheduled_arrival_utc=r.arrival_utc));
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_any_leg_evidence_v1(text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.aircraft_storage_event_signing_payload_v1(p_physical text,p_phase text)
RETURNS text LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT concat_ws(E'\n','airlinerra-storage-event-v1',l.airline_id::text,l.aircraft_inventory_id::text,
 l.flight_occurrence_id,p_phase,l.origin_airport_key,l.destination_airport_key,
 to_char((CASE WHEN p_phase='departed' THEN l.departure_utc ELSE l.arrival_utc END) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
 'storage-v1:'||l.flight_occurrence_id||':'||p_phase)
 FROM airlinerra_game.aircraft_storage_any_leg_evidence_v1(p_physical) l
 WHERE current_user='postgres' AND p_phase IN ('departed','arrived');
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_event_signing_payload_v1(text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.guard_storage_signed_movement_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE l record; payload text; signer text; expected text; proof jsonb; prior record;
BEGIN
 IF NEW.storage_request_id IS NULL THEN RETURN NEW;END IF;
 IF current_user IS DISTINCT FROM 'postgres' OR NOT EXISTS(
 SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled)
 THEN RAISE EXCEPTION 'STORAGE_SIGNED_MOVEMENT_NOT_RELEASED';END IF;
 SELECT * INTO l FROM airlinerra_game.aircraft_storage_any_leg_evidence_v1(NEW.flight_occurrence_id);
 IF NOT FOUND OR NEW.storage_reactivation IS DISTINCT FROM (l.purpose='storage_reactivation') OR l.request_id IS DISTINCT FROM NEW.storage_request_id OR l.airline_id IS DISTINCT FROM NEW.airline_id
 OR l.aircraft_inventory_id IS DISTINCT FROM NEW.aircraft_inventory_id
 OR l.origin_airport_key IS DISTINCT FROM NEW.origin_airport_key OR l.destination_airport_key IS DISTINCT FROM NEW.destination_airport_key
 OR l.departure_utc IS DISTINCT FROM NEW.scheduled_departure_utc OR l.arrival_utc IS DISTINCT FROM NEW.scheduled_arrival_utc
 OR l.flight_local_date IS DISTINCT FROM NEW.flight_local_date
 OR NEW.engine_event_id IS DISTINCT FROM 'storage-v1:'||NEW.flight_occurrence_id||':'||NEW.phase
 OR NEW.actual_event_utc IS DISTINCT FROM (CASE WHEN NEW.phase='departed' THEN l.departure_utc ELSE l.arrival_utc END)
 THEN RAISE EXCEPTION 'STORAGE_MOVEMENT_EVIDENCE_MISMATCH';END IF;
 IF NEW.storage_reactivation THEN
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled) THEN RAISE EXCEPTION 'REACTIVATION_NOT_RELEASED';END IF;
  IF NEW.phase='departed' AND (NOT airlinerra_game.reactivation_reservation_evidence_v1(l.request_id)
   OR airlinerra_game.aircraft_storage_reactivation_billing_check_v1((SELECT storage_session_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=l.request_id),l.departure_utc)->>'cleared' IS DISTINCT FROM 'true')
  THEN RAISE EXCEPTION 'REACTIVATION_DEPARTURE_BLOCKED';END IF;
  IF NEW.phase='arrived' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r JOIN airlinerra_game.aircraft_storage_sessions_v1 s ON s.request_id=r.storage_session_id WHERE r.id=l.request_id AND s.storage_ended_utc=l.departure_utc)
  THEN RAISE EXCEPTION 'REACTIVATION_STORAGE_NOT_CLOSED';END IF;
 END IF;
 proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR proof->>'gameHourUtc' IS NULL OR NEW.actual_event_utc>(proof->>'gameHourUtc')::timestamptz
 OR NEW.actual_event_utc>clock_timestamp()
 OR (NEW.phase='departed' AND NEW.actual_event_utc<=(proof->>'gameHourUtc')::timestamptz-interval '10 minutes')
 THEN RAISE EXCEPTION 'STORAGE_MOVEMENT_CLOCK_BLOCKED';END IF;
 IF NEW.phase='arrived' THEN
  SELECT * INTO prior FROM airlinerra_game.section9_operated_flight_movements_v1
  WHERE flight_occurrence_id=NEW.flight_occurrence_id AND phase='departed';
  IF NOT FOUND OR prior.storage_request_id IS DISTINCT FROM NEW.storage_request_id
  OR prior.airline_id IS DISTINCT FROM NEW.airline_id OR prior.aircraft_inventory_id IS DISTINCT FROM NEW.aircraft_inventory_id
  OR prior.actual_event_utc>=NEW.actual_event_utc THEN RAISE EXCEPTION 'STORAGE_ARRIVAL_WITHOUT_DEPARTURE';END IF;
 END IF;
 payload:=airlinerra_game.aircraft_storage_event_signing_payload_v1(NEW.flight_occurrence_id,NEW.phase);
 SELECT decrypted_secret INTO signer FROM vault.decrypted_secrets WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF payload IS NULL OR signer IS NULL OR length(signer)<64 THEN RAISE EXCEPTION 'STORAGE_SIGNER_UNAVAILABLE';END IF;
 expected:=encode(extensions.hmac(convert_to(payload,'UTF8'),convert_to(signer,'UTF8'),'sha256'),'hex');
 IF NEW.event_hmac_sha256 IS DISTINCT FROM expected THEN RAISE EXCEPTION 'STORAGE_SIGNATURE_INVALID';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_signed_movement_v1() FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.guard_storage_current_position_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE m record;
BEGIN
 SELECT * INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=NEW.last_engine_event_id;
 -- Preserve legacy behavior, but a storage event always requires its exact parent.
 IF NEW.storage_request_id IS NULL AND m.storage_request_id IS NULL AND NOT NEW.storage_reactivation THEN RETURN NEW;END IF;
 IF m.storage_request_id IS NULL OR NEW.storage_reactivation IS DISTINCT FROM m.storage_reactivation OR NEW.storage_request_id IS DISTINCT FROM m.storage_request_id
 OR m.airline_id IS DISTINCT FROM NEW.airline_id OR m.aircraft_inventory_id IS DISTINCT FROM NEW.aircraft_inventory_id
 OR m.world_id IS DISTINCT FROM NEW.world_id OR m.actual_event_utc IS DISTINCT FROM NEW.last_event_utc
 OR NOT coalesce((m.phase='departed' AND NEW.location_status='in_flight' AND NEW.airport_key IS NULL
 AND NEW.current_flight_occurrence_id=m.flight_occurrence_id AND NEW.last_departure_utc=m.actual_event_utc)
 OR (m.phase='arrived' AND NEW.location_status='grounded' AND NEW.airport_key=m.destination_airport_key
 AND NEW.current_flight_occurrence_id IS NULL AND NEW.last_arrival_utc=m.actual_event_utc),false)
 THEN RAISE EXCEPTION 'STORAGE_POSITION_EVIDENCE_MISMATCH';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 later
 WHERE later.airline_id=NEW.airline_id AND later.aircraft_inventory_id=NEW.aircraft_inventory_id
 AND later.world_id=NEW.world_id AND (later.actual_event_utc>m.actual_event_utc
 OR (later.actual_event_utc=m.actual_event_utc AND later.engine_event_id<>m.engine_event_id)))
 THEN RAISE EXCEPTION 'STORAGE_POSITION_STALE';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_current_position_v1() FROM PUBLIC,anon,authenticated,service_role;

ROLLBACK;
