-- Section 9. Seven-day booking storage foundation, OFF by design.
-- No ticket sales, no money, no automatic changes to World 1.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_dated_flight_occurrences_v1 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK (world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE RESTRICT,
 schedule_id uuid NOT NULL REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id) ON DELETE RESTRICT,
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 weekly_entry smallint NOT NULL CHECK(weekly_entry BETWEEN 1 AND 7),
 flight_local_date date NOT NULL CHECK (flight_local_date BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'),
 origin_airport_key text NOT NULL,
 destination_airport_key text NOT NULL,
 departure_utc timestamptz NOT NULL,
 arrival_utc timestamptz NOT NULL,
 turnaround_minutes integer NOT NULL CHECK(turnaround_minutes BETWEEN 45 AND 360),
 verified_passenger_seats integer CHECK(verified_passenger_seats BETWEEN 0 AND 1000),
 booking_status text NOT NULL DEFAULT 'not_open' CHECK(booking_status='not_open'),
 booked_seats integer NOT NULL DEFAULT 0 CHECK(booked_seats=0),
 recognized_revenue_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(recognized_revenue_usd=0),
 source_kind text NOT NULL DEFAULT 'verified_schedule_preview_not_saleable'
  CHECK(source_kind='verified_schedule_preview_not_saleable'),
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(arrival_utc>departure_utc AND arrival_utc<=departure_utc+interval '72 hours'),
 CHECK(origin_airport_key<>destination_airport_key),
 UNIQUE(schedule_id,flight_local_date,weekly_entry)
);
CREATE INDEX IF NOT EXISTS section9_dated_flight_occurrences_airline_date_v1
 ON airlinerra_game.section9_dated_flight_occurrences_v1(airline_id,flight_local_date);
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 FROM PUBLIC, anon, authenticated, service_role;
-- Rows below would be unissued test/rebooking candidates only, NEVER paid/confirmed.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_passenger_reservation_batches_v1 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 occurrence_id uuid NOT NULL REFERENCES
  airlinerra_game.section9_dated_flight_occurrences_v1(id) ON DELETE RESTRICT,
 reservation_key text NOT NULL CHECK (length(reservation_key) BETWEEN 8 AND 100),
 fare_class text NOT NULL CHECK(fare_class IN ('economy','premium','business','first')),
 seats_requested integer NOT NULL CHECK (seats_requested BETWEEN 1 AND 1000),
 quoted_fare_usd numeric(12,2) NOT NULL CHECK(quoted_fare_usd>=0),
 reservation_status text NOT NULL DEFAULT 'unissued'
  CHECK(reservation_status='unissued'),
 paid_upfront boolean NOT NULL DEFAULT false CHECK(paid_upfront=false),
 recognized_revenue_usd numeric(14,2) NOT NULL DEFAULT 0
  CHECK(recognized_revenue_usd=0),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(occurrence_id,reservation_key)
);
ALTER TABLE airlinerra_game.section9_passenger_reservation_batches_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_passenger_reservation_batches_v1
 FROM PUBLIC, anon, authenticated, service_role;
