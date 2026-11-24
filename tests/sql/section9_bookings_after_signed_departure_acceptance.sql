-- Run immediately after the UNCHANGED actual dispatcher records signed
-- departure and fuel departure custody for the SAME occurrence.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 occ uuid:='00000000-0000-4000-8000-000000000004';
 fid text:='11111111-1111-4111-8111-111111111111:2026-11-23:4';
 result jsonb;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'POST_SIGNED_DEPARTURE_DISPOSABLE_ONLY';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1
     WHERE flight_occurrence_id=fid AND phase='departed')<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1
     WHERE physical_flight_id=fid)<>1
 OR (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id=occ)<>'closed'
 THEN RAISE EXCEPTION 'No real signed departure/fuel custody/closed booking for same passenger flight';END IF;
 result:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
  occ,'synthetic.engine.after.departure','economy',1);
 IF result->>'status'<>'blocked_slots_or_flight_already_operated'
 OR result->>'reserved'<>'false' OR result->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Booked seats after signed movement: %',result;END IF;
 IF (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id=occ)<>5
 OR (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
     WHERE physical_flight_id=fid)<>5
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 THEN RAISE EXCEPTION 'Signed departure mutated seats or airline money';END IF;
 RAISE NOTICE 'PASS SAME-FLIGHT SIGNED DEPARTURE: 5 passenger seats retained, no further ticketing, real fuel receipt, no upfront money';
END $test$;
