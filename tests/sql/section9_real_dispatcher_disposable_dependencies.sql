-- ONLY for disposable integration. Mock certification, permission, aircraft,
-- crew, slots and fuel top-up proof producers; execute production dispatcher,
-- fuel preflight, signed movement writer and fuel receipt UNMODIFIED.
CREATE SCHEMA IF NOT EXISTS airlinerra;
ALTER TABLE airlinerra_game.section9_activation_release_policy_v1
 ADD COLUMN crew_mode text NOT NULL DEFAULT 'deferred_phase1';
ALTER TABLE airlinerra_game.airline_aircraft_inventory
 ADD COLUMN ownership_type text NOT NULL DEFAULT 'owned';
CREATE TABLE airlinerra.aircraft_catalog_configuration_inventory (
 configuration_id bigint PRIMARY KEY,use_type text NOT NULL);
INSERT INTO airlinerra.aircraft_catalog_configuration_inventory VALUES(100,'passenger');
CREATE TABLE airlinerra_game.airlines (
 id uuid PRIMARY KEY,owner_player_id uuid,home_airport_key text);
INSERT INTO airlinerra_game.airlines VALUES
 ('22222222-2222-4222-8222-222222222222',
 '44444444-4444-4444-8444-444444444444','TEST-AAA');
ALTER TABLE airlinerra_game.airport_reference_profiles
 ADD COLUMN country_iso text NOT NULL DEFAULT 'DE';
INSERT INTO airlinerra_game.airport_reference_profiles VALUES
 (1,'TEST-BBB','UTC','DE');
ALTER TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1
 ADD COLUMN commercial_version integer NOT NULL DEFAULT 1;
CREATE TABLE airlinerra_game.section9_route_commercial_plans_v1 (
 schedule_id uuid,airline_id uuid,version integer);
INSERT INTO airlinerra_game.section9_route_commercial_plans_v1 VALUES
 ('11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222',1);
CREATE TABLE airlinerra_game.section9_schedule_operational_certifications_v1(
 schedule_id uuid,airline_id uuid,schedule_version integer,
 review_status text,valid_from_game_date date,valid_to_game_date date);
INSERT INTO airlinerra_game.section9_schedule_operational_certifications_v1
 SELECT '11111111-1111-4111-8111-111111111111'::uuid,
 '22222222-2222-4222-8222-222222222222'::uuid,1,
 'verified','2026-11-01'::date,'2026-12-01'::date
 FROM generate_series(1,5);
CREATE TABLE airlinerra_game.section9_schedule_activation_preparations_v1 (
 schedule_id uuid,schedule_version integer,airline_id uuid,
 aircraft_inventory_id uuid,verified_game_date date,
 certified_horizon_days integer,fingerprint_md5 text,release_reference text);
INSERT INTO airlinerra_game.section9_schedule_activation_preparations_v1 VALUES
 ('11111111-1111-4111-8111-111111111111',1,
 '22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333',
 '2026-11-22',7,repeat('a',32),'SYNTHETIC-CERT-RELEASE');
CREATE TABLE airlinerra_game.section6_weekly_airport_slot_reservations_v1 (
 schedule_id uuid,airport_key text,direction text);
INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1 VALUES
 ('11111111-1111-4111-8111-111111111111','TEST-AAA','departure'),
 ('11111111-1111-4111-8111-111111111111','TEST-BBB','arrival');
CREATE TABLE airlinerra_game.section9_game_permission_applications_v1(
 id uuid PRIMARY KEY,airline_id uuid,status text,
 permission_code text,ledger_entry_id uuid,
 issued_game_date date,valid_until_game_date date);
INSERT INTO airlinerra_game.section9_game_permission_applications_v1 VALUES
 ('55555555-5555-4555-8555-555555555555',
 '22222222-2222-4222-8222-222222222222',
 'issued','AIR_OPERATOR_CERTIFICATE',
 '66666666-6666-4666-8666-666666666666',
 '2026-11-01','2026-12-01'),
 ('77777777-7777-4777-8777-777777777777',
 '22222222-2222-4222-8222-222222222222',
 'issued','SYNTHETIC_GAME_TRAFFIC_RIGHT',
 '88888888-8888-4888-8888-888888888888',
 '2026-11-01','2026-12-01');
CREATE TABLE airlinerra_game.section9_operator_licence_evidence_v1 (
 world_id smallint,airline_id uuid,jurisdiction_iso2 text,
 evidence_status text,valid_from date,valid_until date,
 evidence_reference text,issued_application_id uuid);
INSERT INTO airlinerra_game.section9_operator_licence_evidence_v1 VALUES
 (1,'22222222-2222-4222-8222-222222222222',
 'DE','verified','2026-11-01','2026-12-01',
 'game-permission-issued-v1-55555555-5555-4555-8555-555555555555',
 '55555555-5555-4555-8555-555555555555');
CREATE TABLE airlinerra_game.section9_route_operating_permission_evidence_v1 (
 world_id smallint,airline_id uuid,
 origin_airport_key text,destination_airport_key text,
 service_type text,evidence_status text,
 valid_from date,valid_until date,evidence_reference text,
 issued_application_id uuid);
INSERT INTO airlinerra_game.section9_route_operating_permission_evidence_v1 VALUES
 (1,'22222222-2222-4222-8222-222222222222',
 'TEST-AAA','TEST-BBB','passenger','verified',
 '2026-11-01','2026-12-01',
 'game-permission-issued-v1-77777777-7777-4777-8777-777777777777',
 '77777777-7777-4777-8777-777777777777');
CREATE FUNCTION airlinerra_game.section9_required_game_traffic_permission_v1(
 text,text,text,text,date) RETURNS text LANGUAGE sql STABLE AS
 $$ SELECT 'SYNTHETIC_GAME_TRAFFIC_RIGHT'::text $$;
CREATE FUNCTION airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(
 uuid,uuid,uuid,timestamptz,timestamptz)
 RETURNS jsonb LANGUAGE sql STABLE AS
 $$ SELECT '{"gameMaintenanceClear":true}'::jsonb $$;
-- The actual production game fuel top-up is intentionally outside this
-- acceptance boundary. This mock returns no automatic refuelling.
CREATE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(text)
 RETURNS jsonb LANGUAGE sql STABLE AS
 $$ SELECT '{"status":"game_fuel_already_sufficient","ledgerPosted":false}'::jsonb $$;
CREATE FUNCTION airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
 uuid,uuid,date) RETURNS jsonb LANGUAGE sql STABLE AS
 $$
 SELECT jsonb_build_object('status','verified_operational_candidates_only',
 'candidates',jsonb_agg(jsonb_build_object(
 'scheduleId',o.schedule_id,'scheduleVersion',o.schedule_version,
 'flightLocalDate',o.flight_local_date,'weeklyEntry',o.weekly_entry,
 'phase','departed','scheduledEventUtc',o.departure_utc,
 'eventId','TEST-AUTO-DISPATCH-EVENT-'||o.weekly_entry)))
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.airline_id=$1 AND o.aircraft_inventory_id=$2
 AND o.flight_local_date=$3 AND o.booking_status='open'
 $$;
-- Install a single eligible departure and exclude other synthetic records
-- from the dispatcher candidate window without altering their booking state.
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET departure_utc='2026-11-22 18:00+00',
 arrival_utc='2026-11-22 19:00+00'
 WHERE weekly_entry<>4;
UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET departure_utc='2026-11-22 18:00+00',
 arrival_utc='2026-11-22 19:00+00'
 WHERE physical_flight_id NOT LIKE '%:4';
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET origin_airport_key='TEST-AAA',destination_airport_key='TEST-BBB'
 WHERE weekly_entry=4;
