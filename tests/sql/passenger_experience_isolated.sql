\set ON_ERROR_STOP on
-- Run only against a fresh disposable PostgreSQL database, never production.
-- No production credentials, financial posting, signing keys or game data.
BEGIN;
CREATE SCHEMA airlinerra_game;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
SET search_path TO airlinerra_game, pg_catalog;
CREATE TABLE airlines(id uuid PRIMARY KEY,world_id smallint);
CREATE TABLE section9_dated_flight_occurrences_v1(
 id uuid PRIMARY KEY, world_id smallint, airline_id uuid, schedule_id uuid,
 aircraft_inventory_id uuid, flight_local_date date, weekly_entry integer,
 departure_utc timestamptz,arrival_utc timestamptz,booking_status text
);
CREATE TABLE section9_route_posted_flight_financials_v1(
 physical_flight_id text PRIMARY KEY, schedule_id uuid, airline_id uuid,
 arrived_event_id text, passenger_count integer,ticket_income_usd numeric
);
CREATE TABLE section9_operated_flight_movements_v1(
 engine_event_id text PRIMARY KEY,flight_occurrence_id text,phase text,
 airline_id uuid,actual_event_utc timestamptz
);
CREATE TABLE section9_flight_cancellation_receipts_v1(
 occurrence_id uuid PRIMARY KEY,physical_flight_id text,airline_id uuid,
 cancelled_seats int,cancelled_at timestamptz
);
CREATE TABLE section9_atomic_itinerary_holds_v1(
 source_allocation_key text PRIMARY KEY,physical_flight_ids text[],passengers int,cargo_tonnes numeric
);
CREATE TABLE section9_connection_recovery_receipts_v1(
 source_allocation_key text PRIMARY KEY,recorded_at timestamptz,result jsonb
);
CREATE TABLE section9_passenger_reservation_batches_v1(
 reservation_key text,occurrence_id uuid
);
CREATE TABLE aircraft_installed_cabins_v1(
 aircraft_inventory_id uuid,airline_id uuid,configuration_id bigint,updated_at timestamptz
);
CREATE TABLE section9_installed_cabin_comfort_v1(
 aircraft_inventory_id uuid,airline_id uuid,configuration_id bigint,comfort_rating int
);
CREATE FUNCTION section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS $$ SELECT '2026-11-21 20:00:00+00'::timestamptz $$;
CREATE FUNCTION section9_game_airframe_condition_v1(uuid,uuid,timestamptz) RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT '{"conditionPct":90}'::jsonb $$;
\ir ../../server/sql/section9_passenger_experience_reputation_foundation.sql
DO $test$
DECLARE
 a uuid:='10000000-0000-4000-8000-000000000001';
 b uuid:='10000000-0000-4000-8000-000000000002';
 tail uuid:='10000000-0000-4000-8000-000000000003';
 leg uuid:='10000000-0000-4000-8000-000000000004';
 cancel_leg uuid:='10000000-0000-4000-8000-000000000005';
 s uuid:='10000000-0000-4000-8000-000000000006';
 s2 uuid:='10000000-0000-4000-8000-000000000007';
 physical text:=s::text||':2026-11-21:1';
 physical2 text:=s2::text||':2026-11-21:1';
 r jsonb; e record;
BEGIN
 INSERT INTO airlines VALUES(a,1),(b,1);
 INSERT INTO section9_dated_flight_occurrences_v1 VALUES
 (leg,1,a,s,tail,'2026-11-21',1,'2026-11-21 16:00+00','2026-11-21 17:00+00','closed'),
 (cancel_leg,1,a,s2,tail,'2026-11-21',1,'2026-11-21 18:30+00','2026-11-21 19:30+00','cancelled');
 INSERT INTO section9_route_posted_flight_financials_v1 VALUES(physical,s,a,'fixture-arrived',124,6200);
 INSERT INTO section9_operated_flight_movements_v1 VALUES
 ('fixture-departed',physical,'departed',a,'2026-11-21 16:45+00'),
 ('fixture-arrived',physical,'arrived',a,'2026-11-21 17:45+00');
 INSERT INTO aircraft_installed_cabins_v1 VALUES(tail,a,16,'2026-11-20 00:00+00');
 INSERT INTO section9_installed_cabin_comfort_v1 VALUES(tail,a,16,60);
 INSERT INTO section9_flight_cancellation_receipts_v1 VALUES(cancel_leg,physical2,a,10,'2026-11-21 18:00+00');
 INSERT INTO section9_atomic_itinerary_holds_v1 VALUES('fixture-recovery',ARRAY[physical,physical2],20,0);
 INSERT INTO section9_connection_recovery_receipts_v1 VALUES('fixture-recovery','2026-11-21 18:05+00','{"status":"connection_rebooked","recovered":true,"reason":"second_leg_cancelled"}');
 INSERT INTO section9_passenger_reservation_batches_v1 VALUES('demand.fixture-recovery',cancel_leg);
 -- Gates, actual evidence mapping, cabin/fare adjustments, weighted history and replay.
 r:=section9_collect_passenger_experience_v1(100);
 IF r->>'status'<>'passenger_experience_not_released' THEN RAISE EXCEPTION 'release gate failed: %',r;END IF;
 UPDATE section9_passenger_experience_release_v1 SET collection_enabled=true WHERE world_id=1;
 r:=section9_collect_passenger_experience_v1(1);
 IF (r->>'created')::int<>1 THEN RAISE EXCEPTION 'bounded collection failed: %',r;END IF;
 SELECT * INTO STRICT e FROM section9_passenger_experience_events_v1 WHERE event_key='arrival:'||physical;
 IF e.passengers<>124 OR e.score<>77.55 OR (e.components->>'delayMinutes')::numeric<>45 OR (e.components->>'averageFareUsd')::numeric<>50 OR (e.components->>'cabinRating')::numeric<>60 OR (e.components->>'aircraftConditionPct')::numeric<>90 THEN RAISE EXCEPTION 'arrival scoring failed: %',row_to_json(e);END IF;
 r:=section9_collect_passenger_experience_v1(100);
 IF (r->>'created')::int<>2 THEN RAISE EXCEPTION 'cancellation and recovery collection failed: %',r;END IF;
 IF NOT EXISTS(SELECT 1 FROM section9_passenger_experience_events_v1 WHERE event_kind='cancelled' AND passengers=10 AND score=15)
 OR NOT EXISTS(SELECT 1 FROM section9_passenger_experience_events_v1 WHERE event_kind='connection_rebooked' AND passengers=20 AND score=45)
 THEN RAISE EXCEPTION 'disruption scoring failed';END IF;
 r:=section9_collect_passenger_experience_v1(100);
 IF (r->>'created')::int<>0 THEN RAISE EXCEPTION 'duplicate experience event: %',r;END IF;
 r:=section9_airline_reputation_v1(a);
 IF (r->>'passengerExperiences')::int<>154 OR (r->>'arrivedPassengers')::int<>124 OR (r->>'cancelledPassengers')::int<>10 OR (r->>'rebookedPassengers')::int<>20 THEN RAISE EXCEPTION 'reputation history mismatch: %',r;END IF;
 r:=section9_airline_reputation_v1(b);
 IF (r->>'reputation')::numeric<>70 OR (r->>'passengerExperiences')::int<>0 OR r->'averageSatisfaction'<>'null'::jsonb THEN RAISE EXCEPTION 'cross-airline or empty history mismatch: %',r;END IF;
 IF has_function_privilege('authenticated','airlinerra_game.section9_collect_passenger_experience_v1(integer)','execute') OR has_table_privilege('authenticated','airlinerra_game.section9_passenger_experience_events_v1','insert') THEN RAISE EXCEPTION 'unsafe privilege';END IF;
 RAISE NOTICE 'PASS: gated arrived-flight scoring, cancellation, rebooking, bounded collection, replay, reputation, isolation and privileges';
END $test$;
ROLLBACK;
