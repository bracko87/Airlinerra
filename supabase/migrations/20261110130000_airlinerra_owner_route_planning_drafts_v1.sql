-- Airlinerra Route Planning v1
-- Owner-scoped, durable PRE-OPERATIONAL planning records only.
-- Does NOT write slot reservations, aircraft positions, passenger allocations,
-- flight operations, or finance ledgers. Existing Section5/6 activation
-- and fully verified scheduling paths remain unchanged.
BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.airline_route_planning_drafts_v1 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK (world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE CASCADE,
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 flight_number text NOT NULL CHECK (flight_number ~ '^[A-Z0-9]{2}[0-9]{1,4}$'),
 origin_airport_key text NOT NULL,
 destination_airport_key text NOT NULL,
 weekly_schedule jsonb NOT NULL CHECK (jsonb_typeof(weekly_schedule)='array' AND
   jsonb_array_length(weekly_schedule) BETWEEN 1 AND 7),
 departure_stand_type text CHECK (departure_stand_type IN ('terminal','remote','cargo')),
 arrival_stand_type text NOT NULL CHECK (arrival_stand_type IN ('terminal','remote','cargo')),
 turnaround_minutes integer NOT NULL CHECK (turnaround_minutes BETWEEN 45 AND 360),
 planning_options jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (
   jsonb_typeof(planning_options)='object' AND
   pg_column_size(planning_options)<=2048),
 reference_departure_utc timestamptz,
 reference_arrival_utc timestamptz,
 status text NOT NULL DEFAULT 'planning' CHECK (status='planning'),
 operationally_verified boolean NOT NULL DEFAULT false CHECK (operationally_verified=false),
 slots_reserved boolean NOT NULL DEFAULT false CHECK (slots_reserved=false),
 activated boolean NOT NULL DEFAULT false CHECK (activated=false),
 created_by_player_id uuid NOT NULL,
 version integer NOT NULL DEFAULT 1 CHECK (version>=1),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (airline_id,flight_number),
 CONSTRAINT route_planning_distinct_airports CHECK (origin_airport_key<>destination_airport_key),
 CONSTRAINT route_planning_origin_fk FOREIGN KEY (world_id,origin_airport_key)
  REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key),
 CONSTRAINT route_planning_destination_fk FOREIGN KEY (world_id,destination_airport_key)
  REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key),
 CONSTRAINT route_planning_optional_example_times CHECK (
   (reference_departure_utc IS NULL AND reference_arrival_utc IS NULL)
   OR (reference_departure_utc IS NOT NULL AND reference_arrival_utc IS NOT NULL
       AND reference_arrival_utc>reference_departure_utc
       AND reference_arrival_utc<=reference_departure_utc+interval '72 hours'))
);
CREATE INDEX IF NOT EXISTS airline_route_planning_aircraft_idx
 ON airlinerra_game.airline_route_planning_drafts_v1(airline_id,aircraft_inventory_id);
ALTER TABLE airlinerra_game.airline_route_planning_drafts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airline_route_planning_drafts_v1 FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE airlinerra_game.airline_route_planning_drafts_v1 IS
 'Pre-operational owner-scoped route proposals. No slots, flight activation, bookings, or cash effects. Read/write only through the verified airline-owner Edge API.';
COMMIT;