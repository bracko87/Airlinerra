-- Isolated companion schema for executing the actual production fuel
-- preflight and departure receipt functions. The quote provider and clock
-- are explicitly synthetic dependencies; the tested functions are unchanged.
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 ADD COLUMN IF NOT EXISTS world_id smallint NOT NULL DEFAULT 1,
 ADD COLUMN departure_utc timestamptz NOT NULL DEFAULT '2026-11-23 18:00+00',
 ADD COLUMN arrival_utc timestamptz NOT NULL DEFAULT '2026-11-23 19:00+00',
 ADD COLUMN verified_passenger_seats integer NOT NULL DEFAULT 10;
ALTER TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1
 ADD COLUMN passenger_capacity integer NOT NULL DEFAULT 10,
 ADD COLUMN departure_utc timestamptz NOT NULL DEFAULT '2026-11-23 18:00+00',
 ADD COLUMN arrival_utc timestamptz NOT NULL DEFAULT '2026-11-23 19:00+00';
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ADD COLUMN source_kind text NOT NULL DEFAULT 'signed_operated_game_flight_v1';
ALTER TABLE airlinerra_game.section9_aircraft_game_fuel_custody_v1
 ADD COLUMN airline_id uuid NOT NULL DEFAULT '22222222-2222-4222-8222-222222222222',
 ADD COLUMN world_id smallint NOT NULL DEFAULT 1,
 ADD COLUMN configuration_id bigint NOT NULL DEFAULT 100,
 ADD COLUMN at_airport_key text NOT NULL DEFAULT 'TEST-AAA',
 ADD COLUMN fuel_game_family text NOT NULL DEFAULT 'TURBINE_KEROSENE_ASSUMED',
 ADD COLUMN source_event_id text NOT NULL DEFAULT 'SYNTHETIC-FUEL-LOAD-EVENT-1',
 ADD COLUMN source_event_kind text NOT NULL DEFAULT 'approved_game_fuel_load',
 ADD COLUMN evidence_reference text NOT NULL DEFAULT 'SYNTHETIC-APPROVED-SUPPLIER',
 ADD COLUMN game_hour_utc timestamptz NOT NULL DEFAULT '2026-11-23 18:00+00',
 ADD COLUMN revision bigint NOT NULL DEFAULT 1;
CREATE TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1(
 configuration_id bigint PRIMARY KEY,game_calculation_ready boolean NOT NULL,
 tank_capacity_kg numeric NOT NULL, fuel_game_family text NOT NULL);
INSERT INTO airlinerra_game.section9_game_fuel_model_snapshot_v1
 VALUES(100,true,1000,'TURBINE_KEROSENE_ASSUMED');
CREATE TABLE airlinerra_game.airport_facilities(
 world_id smallint,airport_key text,fuel_available boolean);
INSERT INTO airlinerra_game.airport_facilities VALUES(1,'TEST-AAA',true);
CREATE TABLE airlinerra_game.section9_game_approved_fuel_load_receipts_v1(
 source_event_id text PRIMARY KEY,source_status text,airline_id uuid,
 aircraft_inventory_id uuid,at_airport_key text,fuel_family text,
 fuel_after_load_kg numeric,game_hour_utc timestamptz,game_supplier_reference text);
INSERT INTO airlinerra_game.section9_game_approved_fuel_load_receipts_v1
 SELECT source_event_id,'game_authority_approved',airline_id,
 aircraft_inventory_id,at_airport_key,fuel_game_family,onboard_kg,
 game_hour_utc,evidence_reference
 FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1;
CREATE TABLE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1(
 arrival_engine_event_id text,airline_id uuid,aircraft_inventory_id uuid,
 location_airport_key text,onboard_after_arrival_kg numeric);
CREATE TABLE airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(
 physical_flight_id text PRIMARY KEY,
 airline_id uuid,aircraft_inventory_id uuid,departure_engine_event_id text,
 departure_airport_key text,destination_airport_key text,
 configuration_id bigint,fuel_custody_source_event_id text,
 fuel_custody_revision bigint,onboard_at_departure_kg numeric,
 planned_trip_burn_kg numeric,planned_contingency_kg numeric,
 planned_holding_reserve_kg numeric,minimum_planned_onboard_kg numeric,
 model_version text,verified_game_hour_utc timestamptz);
-- NOT the production quote calculator: deterministic source-labelled proof
-- fixture only, with sufficient, insufficient and source-mismatch states
-- exercised by unchanged actual preflight SQL.
CREATE FUNCTION airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(
 bigint,numeric,integer,integer,integer,integer,integer)
 RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object(
 'status','game_reserve_aware_fuel_estimate_only',
 'fuelPlanningReserveIncluded',true,'withinGameTankIncludingReserve',true,
 'accountingApproved',false,'dispatchApproved',false,
 'tripBurnKg',120,'minimumPlannedFuelOnBoardKg',180,
 'contingencyKg',30,'holdingReserveKg',30,
 'modelVersion','SYNTHETIC-CI-FUEL-QUOTE')$$;
UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET passenger_capacity=10;
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET verified_passenger_seats=10;
-- The real signed-writer test requires a fresh, eligible occurrence.
UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET weekly_schedule=
 '[{"day":"0","time":"18:00"},{"day":"0","time":"18:00"},{"day":"0","time":"18:00"},{"day":"0","time":"18:00"},{"day":"0","time":"18:00"}]'::jsonb;
DO $$
DECLARE i integer;
BEGIN
 FOR i IN 4..5 LOOP
  INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1
   (id,schedule_id,flight_local_date,weekly_entry,airline_id,aircraft_inventory_id,
    schedule_version,booking_status,source_kind,recognized_revenue_usd,booked_seats,
    origin_airport_key,destination_airport_key)
  VALUES(('00000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   '11111111-1111-4111-8111-111111111111','2026-11-23',i,
   '22222222-2222-4222-8222-222222222222',
   '33333333-3333-4333-8333-333333333333',
   1,'open','game_verified_saleable_schedule_v1',0,2,'TEST-AAA','TEST-BBB');
  INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1
   (physical_flight_id,airline_id,schedule_version,passengers_held)
  VALUES ('11111111-1111-4111-8111-111111111111:2026-11-23:'||i,
   '22222222-2222-4222-8222-222222222222',1,2);
  INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1
  VALUES(('00000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
   'reserved',2,50,false,0);
 END LOOP;
END $$;
