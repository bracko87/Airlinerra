-- ROLLBACK-ONLY REVIEW. One-way storage movement parent and position adapter.
-- Does not grant commercial admission or dispatch authority.
BEGIN;
-- Retain the old unified-origin FK and all other movement constraints.
-- The legacy destination FK remains equivalent for every non-storage row.
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ADD COLUMN storage_request_id uuid REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 ADD COLUMN legacy_destination_airport_key text GENERATED ALWAYS AS
 (CASE WHEN storage_request_id IS NULL THEN destination_airport_key END) STORED,
 ADD COLUMN storage_destination_airport_key text GENERATED ALWAYS AS
 (CASE WHEN storage_request_id IS NOT NULL THEN destination_airport_key END) STORED;
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 DROP CONSTRAINT section9_movement_exact_parent_v2,
 DROP CONSTRAINT section9_operated_flight_movements_unified_destination_fk,
 ADD CONSTRAINT section9_movement_exact_parent_v3 CHECK (
  num_nonnulls(schedule_id,relocation_trip_id,storage_request_id)=1
  AND (relocation_trip_id IS NULL OR (schedule_version=1 AND weekly_entry IN(1,2)))
  AND (storage_request_id IS NULL OR (schedule_version=1 AND weekly_entry=1))
  AND flight_occurrence_id=coalesce(schedule_id,relocation_trip_id,storage_request_id)::text||':'||flight_local_date::text||':'||weekly_entry::text
 ),
 ADD CONSTRAINT section9_movement_legacy_destination_fk FOREIGN KEY(world_id,legacy_destination_airport_key)
 REFERENCES airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key),
 ADD CONSTRAINT section9_movement_storage_destination_fk FOREIGN KEY(world_id,storage_destination_airport_key)
 REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key);
-- Grounded legacy positions must still reference approved_game_airports.
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1
 ADD COLUMN storage_request_id uuid REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 ADD COLUMN legacy_airport_key text GENERATED ALWAYS AS
 (CASE WHEN storage_request_id IS NULL THEN airport_key END) STORED,
 ADD COLUMN storage_airport_key text GENERATED ALWAYS AS
 (CASE WHEN storage_request_id IS NOT NULL THEN airport_key END) STORED;
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1
 DROP CONSTRAINT section9_aircraft_current_position_v1_world_id_airport_key_fkey,
 ADD CONSTRAINT section9_position_legacy_airport_fk FOREIGN KEY(world_id,legacy_airport_key)
 REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key),
 ADD CONSTRAINT section9_position_storage_airport_fk FOREIGN KEY(world_id,storage_airport_key)
 REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key);
-- Independent disabled gate; a future executor must explicitly release this
-- after the fuel adapter, dispatch, restrictions and settlement are tested.
CREATE TABLE airlinerra_game.aircraft_storage_signed_movement_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.aircraft_storage_signed_movement_release_v1(world_id) VALUES(1);
ALTER TABLE airlinerra_game.aircraft_storage_signed_movement_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_signed_movement_release_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.guard_storage_signed_movement_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE l record; payload text; signer text; expected text; proof jsonb; prior record;
BEGIN
 IF NEW.storage_request_id IS NULL THEN RETURN NEW;END IF;
 IF current_user IS DISTINCT FROM 'postgres' OR NOT EXISTS(
 SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled)
 THEN RAISE EXCEPTION 'STORAGE_SIGNED_MOVEMENT_NOT_RELEASED';END IF;
 SELECT * INTO l FROM airlinerra_game.aircraft_storage_leg_evidence_v1(NEW.flight_occurrence_id);
 IF NOT FOUND OR l.request_id IS DISTINCT FROM NEW.storage_request_id OR l.airline_id IS DISTINCT FROM NEW.airline_id
 OR l.aircraft_inventory_id IS DISTINCT FROM NEW.aircraft_inventory_id
 OR l.origin_airport_key IS DISTINCT FROM NEW.origin_airport_key OR l.destination_airport_key IS DISTINCT FROM NEW.destination_airport_key
 OR l.departure_utc IS DISTINCT FROM NEW.scheduled_departure_utc OR l.arrival_utc IS DISTINCT FROM NEW.scheduled_arrival_utc
 OR l.flight_local_date IS DISTINCT FROM NEW.flight_local_date
 OR NEW.engine_event_id IS DISTINCT FROM 'storage-v1:'||NEW.flight_occurrence_id||':'||NEW.phase
 OR NEW.actual_event_utc IS DISTINCT FROM (CASE WHEN NEW.phase='departed' THEN l.departure_utc ELSE l.arrival_utc END)
 THEN RAISE EXCEPTION 'STORAGE_MOVEMENT_EVIDENCE_MISMATCH';END IF;
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
CREATE TRIGGER storage_signed_movement_guard BEFORE INSERT ON airlinerra_game.section9_operated_flight_movements_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_signed_movement_v1();

CREATE FUNCTION airlinerra_game.guard_storage_current_position_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE m record;
BEGIN
 SELECT * INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=NEW.last_engine_event_id;
 -- Preserve legacy behavior, but a storage event always requires its exact parent.
 IF NEW.storage_request_id IS NULL AND m.storage_request_id IS NULL THEN RETURN NEW;END IF;
 IF m.storage_request_id IS NULL OR NEW.storage_request_id IS DISTINCT FROM m.storage_request_id
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
CREATE TRIGGER storage_position_guard BEFORE INSERT OR UPDATE ON airlinerra_game.section9_aircraft_current_position_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_current_position_v1();
-- These are review definitions only. No release state or actual movement persists.
ROLLBACK;
