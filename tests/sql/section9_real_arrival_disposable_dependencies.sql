-- Disposable arrival-specific extensions. The actual production arrival
-- airframe and fuel functions are executed unchanged, with synthetic
-- airplane state and clock/certification proof producers.
ALTER TABLE airlinerra_game.section9_aircraft_game_fuel_custody_v1
 ADD COLUMN recorded_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1
 ADD COLUMN physical_flight_id text UNIQUE,
 ADD COLUMN trip_burn_kg numeric;
CREATE TABLE airlinerra_game.aircraft_maintenance_state_v1 (
 aircraft_inventory_id uuid PRIMARY KEY,airline_id uuid,
 verified_tracking_started_utc timestamptz,
 tracked_flight_hours numeric NOT NULL DEFAULT 0,
 tracked_flight_cycles bigint NOT NULL DEFAULT 0,
 updated_at timestamptz);
INSERT INTO airlinerra_game.aircraft_maintenance_state_v1 VALUES
 ('33333333-3333-4333-8333-333333333333',
 '22222222-2222-4222-8222-222222222222',
 '2026-11-01 00:00+00',0,0,now());
CREATE TABLE airlinerra_game.section9_arrived_aircraft_usage_receipts_v1(
 physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,
 arrived_engine_event_id text,departed_engine_event_id text,
 elapsed_flight_hours numeric,flight_cycles bigint);
-- HMAC remains genuine pgcrypto; this additional overload signs arrivals.
CREATE FUNCTION airlinerra_game.test_sign_event(
 p_event text,p_time timestamptz,p_entry integer,p_phase text)
 RETURNS text LANGUAGE sql STABLE AS $$
 SELECT encode(extensions.hmac(
 convert_to(concat_ws(E'\n','airlinerra-operated-game-event-v1','1',
 '22222222-2222-4222-8222-222222222222',
 '11111111-1111-4111-8111-111111111111','1','2026-11-23',p_entry::text,p_phase,
 to_char(p_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),p_event),'UTF8'),
 convert_to(repeat('a',80),'UTF8'),'sha256'),'hex')$$;
-- The real position-decision algorithm is not the target of this test.
-- This deterministic fixture permits departure and arrival only with
-- the expected synthetic aircraft state and current occurrence.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aircraft_movement_decision_v1(
 text,text,text,text,timestamptz,timestamptz,text,text,text,timestamptz)
 RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT CASE
 WHEN $1='departed' AND $2='grounded' AND $3=$7 THEN
 '{"allowed":true,"newState":"airborne","newAirport":"TEST-AAA"}'::jsonb
 WHEN $1='arrived' AND $2='airborne' AND $4=$9 THEN
 '{"allowed":true,"newState":"grounded","newAirport":"TEST-BBB"}'::jsonb
 ELSE '{"allowed":false,"reason":"TEST_STATE_NOT_ELIGIBLE"}'::jsonb END $$;
-- The actual dispatcher must be able to discover BOTH phase events.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
 uuid,uuid,date) RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('status','verified_operational_candidates_only',
 'candidates',coalesce(jsonb_agg(jsonb_build_object(
 'scheduleId',o.schedule_id,'scheduleVersion',o.schedule_version,
 'flightLocalDate',o.flight_local_date,'weeklyEntry',o.weekly_entry,
 'phase',phase.phase,'scheduledEventUtc',phase.event_time,
 'eventId','TEST-AUTO-DISPATCH-'||upper(phase.phase)||'-'||o.weekly_entry)), '[]'::jsonb))
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 CROSS JOIN LATERAL (VALUES
 ('departed'::text,o.departure_utc),('arrived'::text,o.arrival_utc))
 phase(phase,event_time)
 WHERE o.airline_id=$1 AND o.aircraft_inventory_id=$2
 AND o.flight_local_date=$3 AND o.booking_status IN ('open','closed')
 $$;
-- Keep all other synthetic flights outside the current dispatcher hour.
-- The target is entry 4 (depart 18:00, arrive 19:00 UTC).
