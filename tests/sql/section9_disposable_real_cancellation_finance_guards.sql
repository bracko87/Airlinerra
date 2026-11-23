-- Snapshot of the unchanged production cancellation worker, tested on a
-- disposable isolated occurrence against finance and payment guard states.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_flight_cancellation_receipts_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'FINANCE_CANCELLATION_GUARD_DISPOSABLE_ONLY';END IF;
END $guard$;
ALTER TABLE airlinerra_game.section9_disruption_release_v1
 ADD COLUMN cancellation_enabled boolean NOT NULL DEFAULT false;
UPDATE airlinerra_game.section9_disruption_release_v1
 SET cancellation_enabled=true WHERE world_id=1;
ALTER TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1
 ADD COLUMN cargo_held_tonnes numeric NOT NULL DEFAULT 0;
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 ADD COLUMN recognized_revenue_usd numeric NOT NULL DEFAULT 0;
CREATE TABLE airlinerra_game.section9_flight_cancellation_receipts_v1(
 occurrence_id uuid PRIMARY KEY,physical_flight_id text,airline_id uuid,
 cancelled_at timestamptz,reason text,cancelled_seats int,
 released_held_seats int,cancelled_holds int,foregone_ticket_quote_usd numeric);
CREATE TABLE airlinerra_game.section9_actual_ticket_finance_preparations_v1(
 physical_flight_id text PRIMARY KEY,preparation_status text NOT NULL);
\i tests/sql/section9_disposable_original_unflown_cancellation_writer.sql

-- Unique, independent one-leg fixture avoids unrelated connecting holds.
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
 id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,
 weekly_entry,flight_local_date,verified_passenger_seats,booked_seats,
 booking_status,source_kind,departure_utc,world_id,recognized_revenue_usd)
 VALUES('bbbbbbbb-1111-4111-8111-bbbbbbbbbbbb',
 '11111111-1111-4111-8111-111111111111',
 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb',
 '33333333-3333-4333-8333-333333333333',1,
 1,'2026-11-21',110,2,'open','game_verified_saleable_schedule_v1',
 '2026-11-21T16:00:00Z',1,0);
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id,schedule_id,airline_id,schedule_version,
 commercial_version,passenger_capacity,passengers_held,status,
 departure_utc,arrival_utc,cargo_held_tonnes)
 VALUES('bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb:2026-11-21:1',
 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb',
 '11111111-1111-4111-8111-111111111111',
 1,1,110,2,'preflight_only','2026-11-21T16:00:00Z',
 '2026-11-21T17:00:00Z',0);
INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1(
 occurrence_id,reservation_key,fare_class,seats_requested,quoted_fare_usd,
 reservation_status,paid_upfront,recognized_revenue_usd)
 VALUES('bbbbbbbb-1111-4111-8111-bbbbbbbbbbbb',
 'fixture.finance.protected','economy',2,100,'reserved',false,0);
DO $checks$
DECLARE r jsonb; occ uuid:='bbbbbbbb-1111-4111-8111-bbbbbbbbbbbb';
 physical text:='bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb:2026-11-21:1';
BEGIN
 INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1
 VALUES(physical,'UNPOSTED_GAME_ESTIMATE');
 r:=airlinerra_game.section9_cancel_unflown_occurrence_v1(occ,'maximum_delay_exceeded');
 IF r->>'status'<>'flight_already_operated_or_settled' OR r->>'cancelled'<>'false'
 THEN RAISE EXCEPTION 'Finance-prepared cancellation not blocked: %',r;END IF;
 DELETE FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id=physical;

 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1
 (schedule_id,flight_local_date,weekly_entry,flight_occurrence_id,phase,actual_event_utc)
 VALUES('bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb', '2026-11-21',1,
 physical,'departed','2026-11-21T16:00:00Z');
 r:=airlinerra_game.section9_cancel_unflown_occurrence_v1(occ,'maximum_delay_exceeded');
 IF r->>'status'<>'flight_already_operated_or_settled' OR r->>'cancelled'<>'false'
 THEN RAISE EXCEPTION 'Operated flight cancellation not blocked: %',r;END IF;
 DELETE FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=physical;

 UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET recognized_revenue_usd=200 WHERE id=occ;
 r:=airlinerra_game.section9_cancel_unflown_occurrence_v1(occ,'maximum_delay_exceeded');
 IF r->>'status'<>'flight_not_cancellable' OR r->>'cancelled'<>'false'
 THEN RAISE EXCEPTION 'Recognized revenue cancellation not blocked: %',r;END IF;
 UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET recognized_revenue_usd=0 WHERE id=occ;

 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1
 SET paid_upfront=true WHERE occurrence_id=occ;
 r:=airlinerra_game.section9_cancel_unflown_occurrence_v1(occ,'maximum_delay_exceeded');
 IF r->>'status'<>'reservation_reconciliation_required' OR r->>'cancelled'<>'false'
 THEN RAISE EXCEPTION 'Upfront-paid reservation cancellation not blocked: %',r;END IF;

 IF (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
  WHERE id=occ)<>2
 OR (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
  WHERE physical_flight_id=physical)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_flight_cancellation_receipts_v1
  WHERE occurrence_id=occ)<>0
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
  WHERE occurrence_id=occ AND reservation_status='reserved')<>1
 THEN RAISE EXCEPTION 'Rejected cancellation mutated money or bookings';END IF;
 RAISE NOTICE 'PASS unchanged cancellation writer rejects finance prep, operated, recognized and paid bookings without mutation';
END $checks$;
