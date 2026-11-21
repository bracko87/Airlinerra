-- Continue the already successful reciprocal activation scenario in the
-- SAME disposable database. Source permissions, clock, fuel quote and
-- timetable source are controlled fixtures; actual dispatcher, signed
-- movement writer, fuel custody and airframe counters run unchanged.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('auth') IS NOT NULL
 OR (SELECT count(*) FROM airlinerra_game.fixture_ticket_occurrences)<>2
 THEN RAISE EXCEPTION 'DISPOSABLE_ACTIVATED_PAIR_ONLY';END IF;
END $$;
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA vault;
CREATE TABLE vault.decrypted_secrets(name text PRIMARY KEY,decrypted_secret text NOT NULL);
INSERT INTO vault.decrypted_secrets VALUES('airlinerra_operated_flight_auto_signing_v1',repeat('disposable-operation-key-',4));
CREATE TABLE public.airlinerra_game_worlds(id smallint PRIMARY KEY,state text,opens_at timestamptz);
INSERT INTO public.airlinerra_game_worlds VALUES(1,'active','2026-11-01 00:00+00');
CREATE TABLE airlinerra_game.holding_world_clock_v1(world_id smallint,clock_source text,confirmed_game_date date,last_verified_at timestamptz,engine_proof_ref text);
INSERT INTO airlinerra_game.holding_world_clock_v1 VALUES(1,'authoritative_game_engine','2026-11-21',now(),'fixture-clock-receipt');
CREATE TABLE airlinerra_game.section9_verified_game_tick_receipts_v1(world_id smallint,game_date date);
INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1 VALUES(1,'2026-11-21');
CREATE TABLE airlinerra_game.fixture_clock(t timestamptz);
INSERT INTO airlinerra_game.fixture_clock VALUES('2026-11-21 00:59+00');
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
 RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('authoritativeGameHourAvailable',true,'gameDate','2026-11-21','gameHourUtc',t)
 FROM airlinerra_game.fixture_clock
 $$;
CREATE TABLE airlinerra_game.approved_game_airports(world_id smallint,airport_key text,PRIMARY KEY(world_id,airport_key));
INSERT INTO airlinerra_game.approved_game_airports VALUES(1,'OURAIRPORTS:2212'),(1,'OURAIRPORTS:2218');
CREATE TABLE airlinerra_game.airport_reference_profiles(world_id smallint,airport_key text,country_iso text,timezone_iana text);
INSERT INTO airlinerra_game.airport_reference_profiles SELECT world_id,airport_key,'DE','Europe/Berlin' FROM airlinerra_game.approved_game_airports;
ALTER TABLE airlinerra_game.airlines ADD COLUMN home_airport_key text;
UPDATE airlinerra_game.airlines SET home_airport_key='OURAIRPORTS:2212';
ALTER TABLE airlinerra_game.airline_aircraft_inventory ADD COLUMN registration text;
UPDATE airlinerra_game.airline_aircraft_inventory SET registration='D-TEST';
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1 ADD COLUMN reference_departure_utc timestamptz,ADD COLUMN reference_arrival_utc timestamptz;
UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET reference_departure_utc=CASE WHEN flight_number='AL101' THEN '2026-11-21 01:00+00'::timestamptz ELSE '2026-11-21 03:00+00'::timestamptz END,
 reference_arrival_utc=CASE WHEN flight_number='AL101' THEN '2026-11-21 02:00+00'::timestamptz ELSE '2026-11-21 04:00+00'::timestamptz END,
 weekly_schedule=CASE WHEN flight_number='AL101' THEN '[{"day":5,"time":"02:00"}]'::jsonb ELSE '[{"day":5,"time":"04:00"}]'::jsonb END;
CREATE TABLE airlinerra.aircraft_catalog_configuration_inventory(configuration_id bigint,use_type text);
INSERT INTO airlinerra.aircraft_catalog_configuration_inventory VALUES(100,'passenger');
CREATE TABLE airlinerra_game.section9_verified_schedule_capacity_v1(schedule_id uuid,airline_id uuid,schedule_version int,verification_source text);
INSERT INTO airlinerra_game.section9_verified_schedule_capacity_v1 SELECT s.id,s.airline_id,s.version,c.source
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s JOIN airlinerra_game.fixture_verified_seat_capacity c ON c.schedule_id=s.id;
CREATE TABLE airlinerra_game.section9_dated_flight_occurrences_v1(
 id uuid PRIMARY KEY,world_id smallint,schedule_id uuid,airline_id uuid,aircraft_inventory_id uuid,schedule_version int,
 flight_local_date date,weekly_entry int,departure_utc timestamptz,arrival_utc timestamptz,booking_status text,
 booked_seats int,verified_passenger_seats int,origin_airport_key text,destination_airport_key text,source_kind text);
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1
 SELECT CASE WHEN s.flight_number='AL101' THEN '77777777-7777-4777-8777-777777777777'::uuid ELSE '88888888-8888-4888-8888-888888888888'::uuid END,
 1,s.id,s.airline_id,s.aircraft_inventory_id,s.version,t.flight_local_date,1,s.reference_departure_utc,s.reference_arrival_utc,
 'open',20,t.passenger_seats,s.origin_airport_key,s.destination_airport_key,'game_verified_saleable_schedule_v1'
 FROM airlinerra_game.fixture_ticket_occurrences t JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=t.schedule_id;
CREATE TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id text PRIMARY KEY,passenger_capacity int,passengers_held int,schedule_version int,commercial_version int,departure_utc timestamptz,arrival_utc timestamptz);
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1 SELECT schedule_id::text||':'||flight_local_date::text||':1',verified_passenger_seats,booked_seats,schedule_version,1,departure_utc,arrival_utc FROM airlinerra_game.section9_dated_flight_occurrences_v1;
CREATE TABLE airlinerra_game.section9_schedule_activation_preparations_v1(schedule_id uuid,schedule_version int,airline_id uuid,aircraft_inventory_id uuid,verified_game_date date,certified_horizon_days int,fingerprint_md5 text,release_reference text);
INSERT INTO airlinerra_game.section9_schedule_activation_preparations_v1 SELECT id,version,airline_id,aircraft_inventory_id,'2026-11-20',28,repeat('a',32),'fixture-approval-reference' FROM airlinerra_game.airline_flight_schedule_drafts_v1;
CREATE TABLE airlinerra_game.section6_weekly_airport_slot_reservations_v1(schedule_id uuid,airport_key text,direction text);
INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1 SELECT id,origin_airport_key,'departure' FROM airlinerra_game.airline_flight_schedule_drafts_v1 UNION ALL SELECT id,destination_airport_key,'arrival' FROM airlinerra_game.airline_flight_schedule_drafts_v1;
CREATE TABLE airlinerra_game.section9_game_permission_applications_v1(id uuid PRIMARY KEY,airline_id uuid,status text,permission_code text,ledger_entry_id bigint,issued_game_date date,valid_until_game_date date);
INSERT INTO airlinerra_game.section9_game_permission_applications_v1 VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','issued','AIR_OPERATOR_CERTIFICATE',1,'2026-11-20','2027-11-20'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','11111111-1111-4111-8111-111111111111','issued','DOMESTIC',2,'2026-11-20','2027-11-20');
CREATE TABLE airlinerra_game.section9_operator_licence_evidence_v1(world_id smallint,airline_id uuid,issued_application_id uuid,jurisdiction_iso2 text,evidence_status text,valid_from date,valid_until date,evidence_reference text);
INSERT INTO airlinerra_game.section9_operator_licence_evidence_v1 SELECT 1,airline_id,id,'DE','verified',issued_game_date,valid_until_game_date,'game-permission-issued-v1-'||id::text FROM airlinerra_game.section9_game_permission_applications_v1 WHERE permission_code='AIR_OPERATOR_CERTIFICATE';
CREATE TABLE airlinerra_game.section9_route_operating_permission_evidence_v1(world_id smallint,airline_id uuid,issued_application_id uuid,origin_airport_key text,destination_airport_key text,service_type text,evidence_status text,valid_from date,valid_until date,evidence_reference text);
INSERT INTO airlinerra_game.section9_route_operating_permission_evidence_v1 SELECT 1,a.airline_id,a.id,s.origin_airport_key,s.destination_airport_key,'passenger','verified',a.issued_game_date,a.valid_until_game_date,'game-permission-issued-v1-'||a.id::text FROM airlinerra_game.section9_game_permission_applications_v1 a CROSS JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s WHERE a.permission_code='DOMESTIC';
CREATE FUNCTION airlinerra_game.section9_required_game_traffic_permission_v1(text,text,text,text,date) RETURNS text LANGUAGE sql AS $$SELECT 'DOMESTIC'::text$$;
CREATE FUNCTION airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(uuid,uuid,uuid,timestamptz,timestamptz) RETURNS jsonb LANGUAGE sql AS $$SELECT '{"gameMaintenanceClear":true}'::jsonb$$;
CREATE TABLE airlinerra_game.section9_aircraft_delivery_position_v1(airport_key text,anchored_game_date date,acquisition_order_id uuid,airline_id uuid,aircraft_inventory_id uuid,inspection_id uuid,inspection_reviewed_at timestamptz,reviewer_reference text);
CREATE TABLE airlinerra_game.aircraft_acquisition_orders_v1(order_id uuid,airline_id uuid,aircraft_inventory_id uuid,order_status text,registration text,configuration_id bigint,delivery_home_airport_key text);
CREATE TABLE airlinerra_game.aircraft_delivery_inspections_v1(inspection_id uuid,order_id uuid,inspection_status text,reviewed_at timestamptz,reviewer_reference text);
CREATE FUNCTION airlinerra_game.section9_starter_origin_evidence_v1(uuid,uuid,date) RETURNS jsonb LANGUAGE sql AS $$SELECT '{"verified":true,"airportKey":"OURAIRPORTS:2212"}'::jsonb$$;
CREATE FUNCTION airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(p_airline uuid,p_aircraft uuid,p_date date) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('status','verified_operational_candidates_only','candidates',coalesce(jsonb_agg(jsonb_build_object(
 'scheduleId',o.schedule_id,'scheduleVersion',o.schedule_version,'flightLocalDate',o.flight_local_date,'weeklyEntry',o.weekly_entry,
 'phase',v.phase,'scheduledEventUtc',v.t,'eventId','operate-v1.'||replace(o.schedule_id::text,'-','')||'.'||replace(o.flight_local_date::text,'-','')||'.'||o.weekly_entry||'.'||v.phase)), '[]'::jsonb))
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o CROSS JOIN LATERAL(VALUES('departed',o.departure_utc),('arrived',o.arrival_utc)) v(phase,t)
 WHERE o.airline_id=p_airline AND o.aircraft_inventory_id=p_aircraft AND o.flight_local_date=p_date
 $$;
CREATE TABLE airlinerra_game.aircraft_maintenance_state_v1(aircraft_inventory_id uuid PRIMARY KEY,airline_id uuid,verified_tracking_started_utc timestamptz,tracked_flight_hours numeric,tracked_flight_cycles int,updated_at timestamptz);
INSERT INTO airlinerra_game.aircraft_maintenance_state_v1 SELECT id,airline_id,'2026-11-20',0,0,now() FROM airlinerra_game.airline_aircraft_inventory;
-- Install exact production table constraints and movement state transition.
\ir ../../supabase/migrations/20261109160000_section9_operated_aircraft_movement_schema.sql
-- The CI step installs exact fuel custody DDL and movement/usage functions next.
