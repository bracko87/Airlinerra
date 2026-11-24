-- Same physical flight has actual cryptographically signed DEPARTURE + ARRIVAL
-- from original production movement writer, real fuel burn and aircraft usage.
-- Airport/certification/clock/auto-fuel quote inputs remain synthetic.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 occ uuid:='00000000-0000-4000-8000-000000000004';
 fid text:='11111111-1111-4111-8111-111111111111:2026-11-23:4';
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'POST_SIGNED_ARRIVAL_DISPOSABLE_ONLY';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1
     WHERE flight_occurrence_id=fid AND phase IN('departed','arrived'))<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1
     WHERE physical_flight_id=fid)<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1
     WHERE physical_flight_id=fid)<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1
     WHERE physical_flight_id=fid)<>1
 OR (SELECT onboard_kg FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1)<>380
 OR (SELECT tracked_flight_hours FROM airlinerra_game.aircraft_maintenance_state_v1)<>1
 OR (SELECT tracked_flight_cycles FROM airlinerra_game.aircraft_maintenance_state_v1)<>1
 OR (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=occ)<>5
 OR (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
     WHERE physical_flight_id=fid)<>5
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
     WHERE occurrence_id=occ AND reservation_key='synthetic.engine.reservation.00001'
     AND seats_requested=3 AND paid_upfront=false AND recognized_revenue_usd=0)<>1
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger)<>5000000
 THEN RAISE EXCEPTION 'Booked physical flight did not complete signed 500->380kg arrival and preserved passenger/cash evidence';END IF;
 RAISE NOTICE 'PASS SAME FLIGHT booking 5 seats -> REAL signed departure -> REAL signed arrival -> 120kg fuel burn -> 1h/1cycle; ledger unchanged pending actual finance (NOT full settlement)';
END $test$;
