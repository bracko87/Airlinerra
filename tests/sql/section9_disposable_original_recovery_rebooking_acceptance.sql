-- Synthetic successful replacement and rollback exercise for the UNCHANGED
-- private recovery writer, installed by previous disposable acceptance.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_airport_transfer_policy_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'FULL_RECOVERY_DISPOSABLE_ONLY';END IF;
END $guard$;

ALTER TABLE airlinerra_game.section9_atomic_itinerary_holds_v1
 ALTER COLUMN status SET DEFAULT 'preflight_only';
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 ADD COLUMN world_id smallint NOT NULL DEFAULT 1,
 ADD COLUMN origin_airport_key text,
 ADD COLUMN destination_airport_key text,
 ADD COLUMN arrival_utc timestamptz;
ALTER TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1
 ADD COLUMN arrival_utc timestamptz;
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ADD COLUMN flight_occurrence_id text,ADD COLUMN phase text,
 ADD COLUMN actual_event_utc timestamptz;
CREATE TABLE airlinerra_game.section9_airport_transfer_policy_v1(
 world_id smallint,airport_key text,minimum_transfer_minutes int);
INSERT INTO airlinerra_game.section9_airport_transfer_policy_v1
 VALUES(1,'OURAIRPORTS:2218',30);
-- Recovery search mentions interline agreements even when the original
-- and replacement airlines match. Empty synthetic table is sufficient.
CREATE TABLE airlinerra_game.section9_interline_agreements_v1(
 world_id smallint,agreement_status text,left_approved_at timestamptz,
 right_approved_at timestamptz,left_airline_id uuid,right_airline_id uuid,
 valid_from timestamptz,valid_until timestamptz);
CREATE VIEW airlinerra_game.section9_verified_schedule_capacity_v1 AS
 SELECT d.id AS schedule_id,d.airline_id,d.version AS schedule_version,
  110::int AS passenger_seats
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 WHERE d.status='active' AND d.operationally_verified;
CREATE FUNCTION airlinerra_game.section9_verified_world_instant_v1()
 RETURNS timestamptz LANGUAGE sql STABLE AS $fn$
 SELECT '2026-11-21T09:00:00Z'::timestamptz
 $fn$;
CREATE FUNCTION airlinerra_game.section9_effective_dispatch_window_v1(p_occ uuid)
 RETURNS TABLE(
  effective_departure_utc timestamptz,
  effective_arrival_utc timestamptz,
  dispatch_allowed boolean
 ) LANGUAGE sql STABLE AS $fn$
 SELECT o.departure_utc,o.arrival_utc,true
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=p_occ;
 $fn$;
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET origin_airport_key='OURAIRPORTS:2212',
     destination_airport_key='OURAIRPORTS:2218',
     arrival_utc='2026-11-21T11:00:00Z'
 WHERE id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET origin_airport_key='OURAIRPORTS:2218',
     destination_airport_key='OURAIRPORTS:2212',
     arrival_utc='2026-11-21T14:00:00Z'
 WHERE id='ffffffff-ffff-4fff-8fff-ffffffffffff';
UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET arrival_utc=CASE
 WHEN schedule_id='88888888-8888-4888-8888-888888888888'::uuid
 THEN '2026-11-21T11:00:00Z'::timestamptz
 ELSE '2026-11-21T14:00:00Z'::timestamptz END
 WHERE schedule_id IN ('88888888-8888-4888-8888-888888888888'::uuid,
                       '99999999-9999-4999-8999-999999999999'::uuid);

INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1 VALUES
('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',1,
 '11111111-1111-4111-8111-111111111111',
 '33333333-3333-4333-8333-333333333333',
 100,1,'active',true,'OURAIRPORTS:2218','OURAIRPORTS:2212',
 'AL110','[]'::jsonb);
INSERT INTO airlinerra_game.section9_route_commercial_plans_v1
 VALUES('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',
 '11111111-1111-4111-8111-111111111111',1,90,0);
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
 id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,
 weekly_entry,flight_local_date,verified_passenger_seats,booked_seats,
 booking_status,source_kind,departure_utc,origin_airport_key,
 destination_airport_key,arrival_utc)
 VALUES('aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa',
 '11111111-1111-4111-8111-111111111111',
 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',
 '33333333-3333-4333-8333-333333333333',1,
 1,'2026-11-21',110,0,'open','game_verified_saleable_schedule_v1',
 '2026-11-21T14:30:00Z','OURAIRPORTS:2218','OURAIRPORTS:2212',
 '2026-11-21T15:30:00Z');
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,
 commercial_version,passenger_capacity,passengers_held,status,
 departure_utc,arrival_utc)
 VALUES('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa:2026-11-21:1',
 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',
 '11111111-1111-4111-8111-111111111111',
 1,1,110,0,'preflight_only','2026-11-21T14:30:00Z',
 '2026-11-21T15:30:00Z');
CREATE TABLE airlinerra_game.fixture_block_replacement(enabled boolean NOT NULL);
INSERT INTO airlinerra_game.fixture_block_replacement VALUES(true);
CREATE FUNCTION airlinerra_game.fixture_fail_recovery_ticket()
RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
 IF NEW.occurrence_id='aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa'::uuid
  AND (SELECT enabled FROM airlinerra_game.fixture_block_replacement)
 THEN RAISE EXCEPTION 'SYNTHETIC_RECOVERY_REBOOKING_FAILURE';END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER fixture_recovery_ticket_failure BEFORE INSERT
 ON airlinerra_game.section9_passenger_reservation_batches_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.fixture_fail_recovery_ticket();

-- The b allocation was issued by the preceding concurrent booking tests
-- alongside unrelated c passengers on the same physical flights.
DO $rollback$
DECLARE res jsonb;raised boolean:=false; k text:='s9g1:'||repeat('b',64);
BEGIN
 BEGIN
  res:=airlinerra_game.section9_recover_connecting_passengers_v1(
   k,'99999999-9999-4999-8999-999999999999:2026-11-21:1',1440);
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='SYNTHETIC_RECOVERY_REBOOKING_FAILURE'
  THEN raised:=true;ELSE RAISE;END IF;
 END;
 IF NOT raised
 OR (SELECT count(*) FROM airlinerra_game.section9_connection_recovery_receipts_v1
   WHERE source_allocation_key=k)<>0
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE reservation_key='demand.'||k AND reservation_status='reserved')<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id IN ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
                'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)
    AND booked_seats=4)<>2
 OR (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
     WHERE schedule_id='aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa'::uuid)<>0
 THEN RAISE EXCEPTION 'Recovery failure left partial changes: %, %',raised,res;END IF;
END $rollback$;

UPDATE airlinerra_game.fixture_block_replacement SET enabled=false;
DO $success$
DECLARE res jsonb;receipt jsonb;k text:='s9g1:'||repeat('b',64);
 rkey text;replacement_flight text:=
 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa:2026-11-21:1';
BEGIN
 res:=airlinerra_game.section9_recover_connecting_passengers_v1(
  k,'99999999-9999-4999-8999-999999999999:2026-11-21:1',1440);
 IF res->>'status'<>'connection_rebooked' OR res->>'recovered'<>'true'
 OR res->>'replacementFlight'<>replacement_flight
 OR res->>'refundUsd'<>'0' OR res->>'ledgerPosted'<>'false'
 OR res->>'additionalChargeUsd'<>'0'
 THEN RAISE EXCEPTION 'Real recovery writer did not rebook: %',res;END IF;
 rkey:='demand.'||(res->>'replacementAllocationKey');
 IF (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE occurrence_id='aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa'::uuid
     AND reservation_key=rkey AND seats_requested=2
     AND reservation_status='reserved')<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE occurrence_id='ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid
     AND reservation_key='demand.'||k AND reservation_status='cancelled')<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE occurrence_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid
     AND reservation_key='demand.'||k AND reservation_status='reserved')<>1
 OR (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)<>2
 OR (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id='aaaaaaaa-2222-4222-8222-aaaaaaaaaaaa'::uuid)<>2
 OR (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
   WHERE physical_flight_id=replacement_flight)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_connection_recovery_receipts_v1
   WHERE source_allocation_key=k)<>1
 THEN RAISE EXCEPTION 'Successful replacement left inconsistent seats: %',res;END IF;
 receipt:=airlinerra_game.section9_recover_connecting_passengers_v1(
  k,'99999999-9999-4999-8999-999999999999:2026-11-21:1',1440);
 IF receipt->>'replayed'<>'true' OR receipt->>'replacementFlight'<>replacement_flight
 OR (SELECT count(*) FROM airlinerra_game.section9_connection_recovery_receipts_v1
    WHERE source_allocation_key=k)<>1
 THEN RAISE EXCEPTION 'Recovery replay mutated second time: %',receipt;END IF;
 RAISE NOTICE 'PASS unchanged recovery writer rebooked second leg, rolled back injected failure, and replayed once';
END $success$;
