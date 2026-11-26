-- Disposable PostgreSQL fixture only. Do not run on Supabase.
DO $$ BEGIN IF current_database()<>'airlinerra_disposable' THEN RAISE EXCEPTION 'DISPOSABLE_DATABASE_REQUIRED';END IF;END $$;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE SCHEMA airlinerra_game;
CREATE TABLE airlinerra_game.airlines(id uuid PRIMARY KEY,world_id smallint NOT NULL,cash_usd numeric(14,2) NOT NULL);
CREATE TABLE airlinerra_game.airline_ledger(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,airline_id uuid REFERENCES airlinerra_game.airlines(id),entry_kind text NOT NULL,amount_usd numeric(14,2) NOT NULL);
CREATE TABLE airlinerra_game.airline_aircraft_inventory(id uuid PRIMARY KEY,airline_id uuid REFERENCES airlinerra_game.airlines(id),fleet_status text,ownership_type text,registration text,configuration_id bigint);
CREATE TABLE airlinerra_game.aircraft_acquisition_orders_v1(order_id uuid PRIMARY KEY,world_id smallint,airline_id uuid REFERENCES airlinerra_game.airlines(id),aircraft_inventory_id uuid REFERENCES airlinerra_game.airline_aircraft_inventory(id),transaction_type text,registration text,configuration_id bigint,order_status text,delivery_due_at timestamptz,contract_months smallint,recurring_monthly_usd numeric(14,2));
CREATE TABLE airlinerra_game.section9_aircraft_delivery_position_v1(acquisition_order_id uuid REFERENCES airlinerra_game.aircraft_acquisition_orders_v1(order_id),aircraft_inventory_id uuid PRIMARY KEY REFERENCES airlinerra_game.airline_aircraft_inventory(id),airline_id uuid,world_id smallint,anchored_game_date date,recorded_at timestamptz,inspection_reviewed_at timestamptz);
-- Test substitute for existing signed world-clock reader: controllable only in this fixture.
CREATE TABLE airlinerra_game.test_clock(t timestamptz NOT NULL);
INSERT INTO airlinerra_game.test_clock VALUES('2027-01-31 12:00+00');
CREATE FUNCTION airlinerra_game.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql AS $$SELECT t FROM airlinerra_game.test_clock$$;
