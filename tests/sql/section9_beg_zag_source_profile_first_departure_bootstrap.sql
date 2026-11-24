-- 2026-11-24 READ-ONLY World 1 game reference snapshot (no player IDs):
-- A319-100 config #16: 840 km/h cruise, 75,500 kg MTOW,
-- 125 simultaneous passenger seats, 156 rated maximum.
-- BEG 44.818401 20.309099, Major Hub, 3,500m runway
-- ZAG 45.742901 16.068800, Large, 3,251.9m runway
-- MUC 48.353802 11.786100, Major Hub, 3,999.9m runway.
-- All three airports are currently admitted. ZAG catalog night flag
-- disagrees with simplified Section5 night flag; this flight is DAYTIME.
-- Aircraft/airline UUIDs, real-world tariff evidence, AOC, slots and
-- issuer signatures are SYNTHETIC. Never apply to production.
\set ON_ERROR_STOP on
DO $safe$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.fixture_single_route_control') IS NULL
 OR to_regclass('airlinerra_game.section9_game_maintenance_jobs_v1') IS NULL
 THEN RAISE EXCEPTION 'BEG_ZAG_REAL_PROFILE_REQUIRES_DISPOSABLE_PRIOR_FIXTURES'; END IF;
END $safe$;

UPDATE airlinerra_game.fixture_game_now SET simulated_now='2026-11-28 00:00:00+00';
UPDATE airlinerra_game.holding_world_clock_v1
 SET confirmed_game_date='2026-11-28',last_verified_at='2026-11-28 00:00+00';
UPDATE airlinerra_game.fixture_single_route_control
 SET position_airport='OURAIRPORTS:4610',fail_at='none';
UPDATE airlinerra_game.airlines SET home_airport_key='OURAIRPORTS:4610';
-- Actual live quote ($240/$900) remains a *provisional game tariff*
-- captured read-only. This fixture charges SYNTHETIC money only.
UPDATE airlinerra_game.aircraft_maintenance_check_overview_v1
 SET base_estimate_usd=CASE check_code WHEN 'daily' THEN 240 WHEN 'weekly' THEN 900 ELSE base_estimate_usd END
 WHERE check_code IN('daily','weekly');
INSERT INTO airlinerra_game.approved_game_airports VALUES
 (1,'OURAIRPORTS:4610'),(1,'OURAIRPORTS:3993') ON CONFLICT DO NOTHING;

ALTER TABLE airlinerra_game.airport_reference_profiles
 ADD COLUMN latitude_deg numeric, ADD COLUMN longitude_deg numeric;
INSERT INTO airlinerra_game.airport_reference_profiles
 (world_id,airport_key,timezone_iana,latitude_deg,longitude_deg)
VALUES
 (1,'OURAIRPORTS:4610','Europe/Belgrade',44.818401,20.309099),
 (1,'OURAIRPORTS:3993','Europe/Zagreb',45.742901,16.068800);
UPDATE airlinerra_game.airport_reference_profiles
 SET latitude_deg=48.353802,longitude_deg=11.786100
 WHERE airport_key='OURAIRPORTS:2218';

-- Deliberately minimal proxy for READ-ONLY live unified GAME airport fields.
-- Real PostgreSQL Section9 restriction function is installed unchanged next.
CREATE TABLE airlinerra_game.airport_unified_operations_v1(
 world_id smallint NOT NULL,airport_key text NOT NULL,
 game_category text NOT NULL,game_runway_length_m numeric NOT NULL,
 game_nighttime_ban boolean NOT NULL,game_noise_restrictions boolean NOT NULL,
 operationally_authorized boolean NOT NULL,
 dispatch_eligible_by_airport_admission boolean NOT NULL,
 PRIMARY KEY(world_id,airport_key)
);
INSERT INTO airlinerra_game.airport_unified_operations_v1 VALUES
 (1,'OURAIRPORTS:4610','Major Hub',3500,false,false,true,true),
 (1,'OURAIRPORTS:3993','Large',3251.9,true,false,true,true),
 (1,'OURAIRPORTS:2218','Major Hub',3999.9,true,false,true,true);

ALTER TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1
 ADD COLUMN cruise_speed_kmh numeric;
UPDATE airlinerra_game.section9_game_fuel_model_snapshot_v1
 SET cruise_speed_kmh=840 WHERE configuration_id=100;
CREATE TABLE airlinerra.aircraft_catalog_configuration_inventory(
 configuration_id bigint PRIMARY KEY,mtow_kg numeric,model_name text);
INSERT INTO airlinerra.aircraft_catalog_configuration_inventory
 VALUES(100,75500,'A319-100 (source properties, synthetic identity)');
UPDATE airlinerra.aircraft_service_payload_game_v1
 SET simultaneous_passenger_seats=125 WHERE configuration_id=100;
UPDATE airlinerra.aircraft_configurations SET maximum_passenger_seats=156 WHERE id=100;

-- One SATURDAY 11:00-local departure and booking occurrence, day 2026-11-28.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_saleable_departure_window_v1(
 p_schedule uuid,p_date date,p_weekly_entry integer,p_hour timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT jsonb_build_object('withinWindow',p_date=DATE '2026-11-28'
 AND p_hour<('2026-11-28 10:00+00'::timestamptz));
$fn$;

-- The real airport game hard/soft test is called INSIDE the existing atomic
-- creator's synthetic certificate path. The rest of the issuer remains mocked.
-- No source-backed operator licence, signed slot or charge is fabricated.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_issue_queued_game_clearance_v1(
 p_airline uuid,p_schedule uuid,p_version integer,p_day date,p_kind text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER AS $fn$
DECLARE s record;screen jsonb;profile jsonb;d text;actual_sec integer;
BEGIN
 IF (SELECT fail_at FROM airlinerra_game.fixture_single_route_control)=p_kind
 THEN RETURN jsonb_build_object('status','blocked_test_clearance','kind',p_kind);END IF;
 IF p_kind='airport_slot_capacity' THEN
  SELECT * INTO s FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE id=p_schedule AND airline_id=p_airline AND version=p_version;
  IF NOT FOUND THEN RETURN '{"status":"blocked_test_missing_schedule"}'::jsonb;END IF;
  SELECT weekly_screen,phase_profile INTO screen,profile
  FROM airlinerra_game.fixture_source_route_game_evidence
  WHERE destination_airport_key=s.destination_airport_key;
  actual_sec:=EXTRACT(EPOCH FROM(s.reference_arrival_utc-s.reference_departure_utc))::int;
  IF s.origin_airport_key IS DISTINCT FROM 'OURAIRPORTS:4610'
     OR s.weekly_schedule IS DISTINCT FROM '[{"day":5,"time":"11:00"}]'::jsonb
     OR s.reference_departure_utc IS DISTINCT FROM '2026-11-28 10:00+00'::timestamptz
     OR p_day IS DISTINCT FROM DATE '2026-11-28'
     OR screen IS NULL
     OR (profile->>'totalMinutes')::int*60 IS DISTINCT FROM actual_sec
     OR (screen->>'referenceDurationSeconds')::int IS DISTINCT FROM actual_sec
  THEN RETURN '{"status":"blocked_test_route_source_evidence_mismatch"}'::jsonb;END IF;
  IF NOT coalesce(airlinerra_game.section9_game_route_restrictions_valid_v1(
     s.origin_airport_key,s.destination_airport_key,screen),false)
  THEN RETURN jsonb_build_object('status','blocked_actual_section9_game_restrictions',
     'destination',s.destination_airport_key,'researchNeedsReview',screen->'needsReview');END IF;
 END IF;
 INSERT INTO airlinerra_game.fixture_certificates VALUES(p_schedule,p_kind);
 RETURN jsonb_build_object('status','certification_event_recorded',
  'syntheticIssuer',true,'realGameRestrictionsChecked',p_kind='airport_slot_capacity');
END $fn$;
