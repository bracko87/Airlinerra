-- Financial settlement bridge for the EXISTING synthetic physical flight
-- with actual HMAC-signed departure+arrival, real seat bookings, 120kg burn.
-- Finance cost approval and source tariff/clock remain TEST-ONLY evidence.
-- Never run against Supabase production or player funds.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_operated_flight_movements_v1') IS NULL
 OR to_regclass('airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1') IS NULL
 OR to_regclass('airlinerra_game.airline_ledger') IS NULL
 THEN RAISE EXCEPTION 'SAME_FLIGHT_FINANCE_DISPOSABLE_ONLY';END IF;
END $guard$;

ALTER TABLE airlinerra_game.airlines
 ADD COLUMN world_id smallint NOT NULL DEFAULT 1,
 ADD COLUMN cash_usd numeric(16,2) NOT NULL DEFAULT 5000000;

ALTER TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1
 ADD COLUMN financial_settlement_release text NOT NULL DEFAULT 'RELEASED',
 ADD COLUMN operational_dispatch_release text NOT NULL DEFAULT 'RELEASED';

ALTER TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1
 ADD COLUMN local_departure_date date NOT NULL DEFAULT '2026-11-23',
 ADD COLUMN weekly_entry integer NOT NULL DEFAULT 4;
UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET weekly_entry=split_part(physical_flight_id,':',3)::integer
 WHERE physical_flight_id LIKE '11111111-1111-4111-8111-111111111111:2026-11-23:%';

ALTER TABLE airlinerra_game.section9_actual_ticket_finance_preparations_v1
 ADD COLUMN airline_id uuid,ADD COLUMN schedule_id uuid,
 ADD COLUMN flight_local_date date,ADD COLUMN arrival_event_id text,
 ADD COLUMN passenger_count integer,ADD COLUMN ticket_quote_usd numeric(16,2),
 ADD COLUMN preparation_status text,ADD COLUMN source_version text;

CREATE TABLE airlinerra_game.section9_flight_finance_posting_release_v1(
 world_id smallint PRIMARY KEY,release_state text NOT NULL,
 approved_at timestamptz,approval_reference text);
INSERT INTO airlinerra_game.section9_flight_finance_posting_release_v1
 VALUES(1,'paused',NULL,NULL);

CREATE TABLE airlinerra_game.section9_flight_final_cost_approvals_v1(
 physical_flight_id text PRIMARY KEY,airline_id uuid,arrived_event_id text,
 approval_state text,approved_at timestamptz,approval_reference text,
 fuel_reserve_verified boolean,fuel_reserve_kg numeric(14,3),
 fuel_source_reference text,tariff_source_reference text,
 fuel_cost_usd numeric(16,2),airport_navigation_cost_usd numeric(16,2),
 crew_cost_usd numeric(16,2),maintenance_cost_usd numeric(16,2),
 ownership_cost_usd numeric(16,2),other_cost_usd numeric(16,2),
 airport_fee_lines jsonb,tariff_model_version text);

CREATE TABLE airlinerra_game.section9_route_posted_flight_financials_v1(
 physical_flight_id text PRIMARY KEY,schedule_id uuid,airline_id uuid,
 flown_game_day date,arrived_event_id text,passenger_count integer,
 cargo_tonnes numeric,ticket_income_usd numeric(16,2),
 cargo_income_usd numeric(16,2),other_income_usd numeric(16,2),
 airport_navigation_cost_usd numeric(16,2),fuel_cost_usd numeric(16,2),
 crew_cost_usd numeric(16,2),maintenance_cost_usd numeric(16,2),
 ownership_cost_usd numeric(16,2),other_cost_usd numeric(16,2),
 airport_fee_lines jsonb,
 revenue_ledger_id bigint,expense_ledger_id bigint,
 tariff_model_version text,settlement_source_reference text,
 record_status text);
