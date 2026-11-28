-- Synthetic schema matching the relevant legacy constraints. Disposable CI only.
CREATE SCHEMA vault; CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE TABLE vault.decrypted_secrets(name text,decrypted_secret text);
INSERT INTO vault.decrypted_secrets VALUES('airlinerra_operated_flight_auto_signing_v1',repeat('a',64));
CREATE TABLE airlinerra_game.airport_sections1_8_combined_members_v1(world_id smallint,airport_key text,PRIMARY KEY(world_id,airport_key));
CREATE TABLE airlinerra_game.approved_game_airports(world_id smallint,airport_key text,PRIMARY KEY(world_id,airport_key));
INSERT INTO airlinerra_game.airport_sections1_8_combined_members_v1 VALUES(1,'OURAIRPORTS:999');
INSERT INTO airlinerra_game.approved_game_airports VALUES(1,'OURAIRPORTS:999');
CREATE TABLE airlinerra_game.section9_operated_flight_movements_v1(
 world_id smallint NOT NULL,engine_event_id text PRIMARY KEY,event_hmac_sha256 text NOT NULL,
 airline_id uuid NOT NULL,aircraft_inventory_id uuid NOT NULL,schedule_id uuid,relocation_trip_id uuid,
 schedule_version integer NOT NULL,weekly_entry integer NOT NULL,flight_local_date date NOT NULL,
 flight_occurrence_id text NOT NULL,phase text NOT NULL CHECK(phase IN ('departed','arrived')),
 origin_airport_key text NOT NULL,destination_airport_key text NOT NULL,
 scheduled_departure_utc timestamptz NOT NULL,scheduled_arrival_utc timestamptz NOT NULL,actual_event_utc timestamptz NOT NULL,
 UNIQUE(flight_occurrence_id,phase),
 CONSTRAINT section9_movement_exact_parent_v2 CHECK (
 ((schedule_id IS NOT NULL AND relocation_trip_id IS NULL) OR
 (schedule_id IS NULL AND relocation_trip_id IS NOT NULL AND schedule_version=1 AND weekly_entry IN(1,2)))
 AND flight_occurrence_id=coalesce(schedule_id,relocation_trip_id)::text||':'||flight_local_date::text||':'||weekly_entry::text),
 CONSTRAINT section9_operated_flight_movements_unified_origin_fk FOREIGN KEY(world_id,origin_airport_key)
 REFERENCES airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key),
 CONSTRAINT section9_operated_flight_movements_unified_destination_fk FOREIGN KEY(world_id,destination_airport_key)
 REFERENCES airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key)
);
CREATE TABLE airlinerra_game.section9_aircraft_current_position_v1(
 aircraft_inventory_id uuid PRIMARY KEY,world_id smallint NOT NULL,airline_id uuid NOT NULL,location_status text NOT NULL,
 airport_key text,current_flight_occurrence_id text,last_event_utc timestamptz NOT NULL,last_departure_utc timestamptz,last_arrival_utc timestamptz,
 last_engine_event_id text NOT NULL REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 CONSTRAINT section9_aircraft_current_position_v1_world_id_airport_key_fkey FOREIGN KEY(world_id,airport_key)
 REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key),
 CHECK((location_status='grounded' AND airport_key IS NOT NULL AND current_flight_occurrence_id IS NULL)
 OR (location_status='in_flight' AND airport_key IS NULL AND current_flight_occurrence_id IS NOT NULL))
);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS
 'SELECT current_setting(''test.storage_hour'')::timestamptz';
CREATE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1() RETURNS jsonb LANGUAGE sql STABLE AS
 'SELECT jsonb_build_object(''authoritativeGameHourAvailable'',true,''gameHourUtc'',airlinerra_game.section9_verified_world_instant_v1())';
DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1;

ALTER TABLE airlinerra_game.airline_ledger ADD COLUMN id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, ADD COLUMN entry_kind text, ADD COLUMN recorded_at timestamptz;
ALTER TABLE airlinerra_game.airline_aircraft_inventory ADD COLUMN updated_at timestamptz;
CREATE TABLE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,arrival_engine_event_id text,trip_burn_kg numeric,location_airport_key text);
CREATE TABLE airlinerra_game.section9_arrived_aircraft_usage_receipts_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,arrived_engine_event_id text,departed_engine_event_id text,elapsed_flight_hours numeric,flight_cycles integer);
