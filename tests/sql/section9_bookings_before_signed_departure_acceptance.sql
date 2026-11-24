-- A SINGLE synthetic 2026-11-23 flight: unchanged real booking SQL first,
-- then the existing CI uses unchanged signed auto dispatcher and fuel custody.
\set ON_ERROR_STOP on
BEGIN;
DO $test$
DECLARE
 occurrence uuid:='00000000-0000-4000-8000-000000000004';
 fid text:='11111111-1111-4111-8111-111111111111:2026-11-23:4';
 booking jsonb; replay jsonb;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'BOOKING_TO_SIGNED_ARRIVAL_DISPOSABLE_ONLY';END IF;
 IF (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id=occurrence)<>2
 OR (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
     WHERE physical_flight_id=fid)<>2
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 THEN RAISE EXCEPTION 'Expected synthetic signed-flight starting 2 seats / 1 capital record';END IF;

 booking:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
   occurrence,'synthetic.engine.reservation.00001','economy',3);
 IF booking->>'status'<>'game_passenger_seats_reserved'
 OR booking->>'seatsReservedNow'<>'3'
 OR booking->>'totalSeatsBooked'<>'5'
 OR booking->>'remainingSeats'<>'5'
 OR booking->>'chargedNow'<>'false'
 OR booking->>'revenueRecognizedNow'<>'false'
 OR booking->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Genuine passenger booking did not reserve seats safely: %',booking;END IF;
 replay:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
   occurrence,'synthetic.engine.reservation.00001','economy',3);
 IF replay->>'status'<>'game_passenger_reservation_replayed'
 OR replay->>'replayed'<>'true'
 OR replay->>'reservedNow'<>'false'
 OR replay->>'chargedNow'<>'false'
 OR (replay->>'reservationId')::uuid IS DISTINCT FROM (booking->>'reservationId')::uuid
 THEN RAISE EXCEPTION 'Repeated booking duplicated seat or charged passenger: %',replay;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
    occurrence,'synthetic.engine.reservation.00001','economy',2);
  RAISE EXCEPTION 'Mismatched replay incorrectly accepted';
 EXCEPTION WHEN unique_violation THEN
  IF SQLERRM NOT LIKE '%SECTION9_PASSENGER_RESERVATION_REPLAY_MISMATCH%'
  THEN RAISE;END IF;
 END;
 booking:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
   occurrence,'synthetic.engine.reservation.too_many','economy',6);
 IF booking->>'status'<>'blocked_insufficient_available_seats'
 OR booking->>'availableSeats'<>'5'
 OR booking->>'chargedNow'<>'false'
 OR booking->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Verified inventory allowed oversale: %',booking;END IF;
 IF (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id=occurrence)<>5
 OR (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
     WHERE physical_flight_id=fid)<>5
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
     WHERE occurrence_id=occurrence)<>2
 OR (SELECT COUNT(*) FROM airlinerra_game.airline_ledger)<>1
 OR (SELECT SUM(amount_usd) FROM airlinerra_game.airline_ledger)<>5000000
 THEN RAISE EXCEPTION 'Booking/capacity/ledger integrity failed before actual departure';END IF;
 RAISE NOTICE 'PASS REAL BOOKING BEFORE SIGNED DEPARTURE: 5 seats held, replay protected, oversell denied, money unchanged';
END $test$;
COMMIT;
