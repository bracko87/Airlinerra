-- Disconnected PostgreSQL acceptance for the UNCHANGED production
-- two-leg hold-to-ticket issuance function; no live migration or API.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_capacity_hold_plans_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'REAL_TWO_LEG_TICKET_DISPOSABLE_ONLY';END IF;
END $guard$;
ALTER TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1
 ADD COLUMN departure_utc timestamptz;
ALTER TABLE airlinerra_game.section9_capacity_hold_plan_items_v1
 ADD COLUMN plan_id uuid;
CREATE TABLE airlinerra_game.section9_capacity_hold_plans_v1(
 id uuid PRIMARY KEY,world_id smallint NOT NULL,
 status text NOT NULL,next_allocation_seq integer NOT NULL,
 allocation_count integer NOT NULL,completed_at timestamptz);
CREATE TABLE airlinerra_game.fixture_reject_second_leg(
 enabled boolean NOT NULL);
INSERT INTO airlinerra_game.fixture_reject_second_leg VALUES(true);
CREATE FUNCTION airlinerra_game.fixture_reject_connecting_leg()
 RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
 IF NEW.occurrence_id='ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid
 AND (SELECT enabled FROM airlinerra_game.fixture_reject_second_leg)
 THEN RAISE EXCEPTION 'SYNTHETIC_SECOND_LEG_FAILURE';END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER synthetic_second_leg_failure
 BEFORE INSERT ON airlinerra_game.section9_passenger_reservation_batches_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.fixture_reject_connecting_leg();
-- Two fresh active schedules do not touch any already-tested flight.
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1 VALUES
 ('88888888-8888-4888-8888-888888888888',1,
  '11111111-1111-4111-8111-111111111111',
  '33333333-3333-4333-8333-333333333333',
  100,1,'active',true,'OURAIRPORTS:2212','OURAIRPORTS:2218','AL108','[]'::jsonb),
 ('99999999-9999-4999-8999-999999999999',1,
  '11111111-1111-4111-8111-111111111111',
  '33333333-3333-4333-8333-333333333333',
  100,1,'active',true,'OURAIRPORTS:2218','OURAIRPORTS:2212','AL109','[]'::jsonb);
INSERT INTO airlinerra_game.section9_route_commercial_plans_v1 VALUES
 ('88888888-8888-4888-8888-888888888888',
  '11111111-1111-4111-8111-111111111111',1,80,0),
 ('99999999-9999-4999-8999-999999999999',
  '11111111-1111-4111-8111-111111111111',1,90,0);
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1 VALUES
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  '11111111-1111-4111-8111-111111111111',
  '88888888-8888-4888-8888-888888888888',
  '33333333-3333-4333-8333-333333333333',
  1,1,DATE '2026-11-21',110,0,'open',
  'game_verified_saleable_schedule_v1','2026-11-21T10:00:00Z'),
 ('ffffffff-ffff-4fff-8fff-ffffffffffff',
  '11111111-1111-4111-8111-111111111111',
  '99999999-9999-4999-8999-999999999999',
  '33333333-3333-4333-8333-333333333333',
  1,1,DATE '2026-11-21',110,0,'open',
  'game_verified_saleable_schedule_v1','2026-11-21T13:00:00Z');
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,commercial_version,
 passenger_capacity,passengers_held,status,departure_utc) VALUES
 ('88888888-8888-4888-8888-888888888888:2026-11-21:1',
  '88888888-8888-4888-8888-888888888888',
  '11111111-1111-4111-8111-111111111111',1,1,110,2,'preflight_only',
  '2026-11-21T10:00:00Z'),
 ('99999999-9999-4999-8999-999999999999:2026-11-21:1',
  '99999999-9999-4999-8999-999999999999',
  '11111111-1111-4111-8111-111111111111',1,1,110,2,'preflight_only',
  '2026-11-21T13:00:00Z');
INSERT INTO airlinerra_game.section9_capacity_hold_plans_v1
 VALUES('aaaaaaaa-0000-4000-8000-000000000001',1,'completed',1,1,now());
INSERT INTO airlinerra_game.section9_atomic_itinerary_holds_v1
 VALUES('s9g1:'||repeat('b',64),
  ARRAY['88888888-8888-4888-8888-888888888888:2026-11-21:1',
        '99999999-9999-4999-8999-999999999999:2026-11-21:1'],
  2,0,'preflight_only');
INSERT INTO airlinerra_game.section9_atomic_itinerary_hold_legs_v1
 VALUES
 ('s9g1:'||repeat('b',64),1,
  '88888888-8888-4888-8888-888888888888:2026-11-21:1'),
 ('s9g1:'||repeat('b',64),2,
  '99999999-9999-4999-8999-999999999999:2026-11-21:1');
INSERT INTO airlinerra_game.section9_capacity_hold_plan_items_v1(
 allocation_key,physical_flight_ids,passengers,cargo_tonnes,plan_id)
 VALUES('s9g1:'||repeat('b',64),
  ARRAY['88888888-8888-4888-8888-888888888888:2026-11-21:1',
        '99999999-9999-4999-8999-999999999999:2026-11-21:1'],
  2,0,'aaaaaaaa-0000-4000-8000-000000000001');

\i /tmp/section9-connecting-tickets-actual.sql

-- Confirm the unchanged production writer fails precisely on the ambiguous
-- reservation_key identifier, before testing the minimally patched candidate.
DO $original_failure$
DECLARE ticket_key text:='s9g1:'||repeat('b',64);
 caught boolean:=false;
BEGIN
 BEGIN
  PERFORM airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(ticket_key);
 EXCEPTION WHEN SQLSTATE '42702' THEN caught:=true;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'Original production writer did not reproduce ambiguous reservation_key';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE reservation_key='demand.'||ticket_key)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id IN ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
                'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)
   AND booked_seats<>0)
 THEN RAISE EXCEPTION 'Original writer failure left partial tickets';END IF;
 RAISE NOTICE 'PASS reproduced unchanged production SQL ambiguous reservation_key fail-closed';
END $original_failure$;
-- Not a migration. Install isolated candidate with variable disambiguation only.
\i /tmp/section9-connecting-tickets-disambiguated-lab.sql

-- Diagnose all production hold/inventory consistency conditions before issuance.
SELECT o.schedule_id::text AS schedule,
 cap.airline_id<>o.airline_id AS wrong_airline,
 cap.schedule_id<>o.schedule_id AS wrong_schedule,
 cap.schedule_version<>o.schedule_version AS wrong_version,
 cap.commercial_version<>plan.version AS wrong_commercial_version,
 cap.passenger_capacity<>o.verified_passenger_seats AS wrong_capacity,
 cap.passengers_held<o.booked_seats+2 AS insufficient_hold,
 o.booked_seats+2>o.verified_passenger_seats AS overbooked,
 cap.departure_utc<>o.departure_utc AS wrong_departure_time,
 cap.departure_utc AS inventory_departure,
 o.departure_utc AS occurrence_departure
FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
 ON cap.schedule_id=o.schedule_id
JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
 ON plan.schedule_id=o.schedule_id
WHERE o.id IN ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
 'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid);

DO $acceptance$
DECLARE ticket_key text:='s9g1:'||repeat('b',64);
 result jsonb;raised boolean:=false;
BEGIN
 BEGIN
  PERFORM airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(ticket_key);
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='SYNTHETIC_SECOND_LEG_FAILURE' THEN raised:=true;ELSE RAISE;END IF;
 END;
 IF NOT raised
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_reservation_batches_v1
    WHERE reservation_key='demand.'||ticket_key)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1
    WHERE id IN ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
                 'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)
      AND booked_seats<>0)
 THEN RAISE EXCEPTION 'Two-leg ticket failure was not atomic';END IF;
 UPDATE airlinerra_game.fixture_reject_second_leg SET enabled=false;
 result:=airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(ticket_key);
 IF result->>'status'<>'demand_hold_tickets_issued'
 OR result->>'newBookings'<>'2'
 OR result->>'chargedNow'<>'false'
 OR result->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Two-leg issuance failed: %',result;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
  WHERE reservation_key='demand.'||ticket_key)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1
  WHERE id IN ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
               'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)
  AND booked_seats=2)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
  WHERE schedule_id IN ('88888888-8888-4888-8888-888888888888'::uuid,
                        '99999999-9999-4999-8999-999999999999'::uuid)
  AND passengers_held=2)<>2
 THEN RAISE EXCEPTION 'Ticket count or held seats are inconsistent';END IF;
 result:=airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(ticket_key);
 IF result->>'status'<>'demand_tickets_already_issued'
 OR result->>'replayed'<>'true'
 OR result->>'newBookings'<>'0'
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
  WHERE reservation_key='demand.'||ticket_key)<>2
 THEN RAISE EXCEPTION 'Two-leg replay duplicated claims: %',result;END IF;
 RAISE NOTICE 'PASS isolated corrected two-leg candidate: rollback, two reservations, held-seat reconciliation, replay, no ledger';
END $acceptance$;
