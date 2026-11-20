-- Run after real production HMAC verifier & ticket reconciliation are installed
-- on disposable PG17. Tamper with independently signed event and fare data.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 fid text:='44444444-4444-4444-8444-444444444444:2026-11-20:5';
 x jsonb; previous_sig text;bad_code text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'SIGNED_ACCEPTANCE_DISPOSABLE_ONLY';END IF;
 x:=airlinerra_game.section9_verify_operated_flight_hmac_pair_v1(fid);
 IF x->>'status'<>'signed_departure_and_arrival_verified'
 OR x->>'checkedEvents'<>'2' THEN
 RAISE EXCEPTION 'Real signed departure and arrival rejected: %',x;END IF;
 x:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(fid);
 IF x->>'status'<>'postarrival_ticket_totals_reconciled'
 OR x->>'ticketPassengers'<>'20' OR x->>'ticketIncomeUsd'<>'1000' THEN
 RAISE EXCEPTION 'Real booking receipts failed reconciliation: %',x;END IF;

 SELECT event_hmac_sha256 INTO previous_sig
 FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE engine_event_id='signed-arrival-01';
 UPDATE airlinerra_game.section9_operated_flight_movements_v1
 SET event_hmac_sha256=repeat('a',64)
 WHERE engine_event_id='signed-arrival-01';
 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF x->>'status'<>'blocked_unverified_signed_flight_movement'
 THEN RAISE EXCEPTION 'Tampered HMAC incorrectly settled: %',x;END IF;
 UPDATE airlinerra_game.section9_operated_flight_movements_v1
 SET event_hmac_sha256=previous_sig
 WHERE engine_event_id='signed-arrival-01';

 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1
 SET seats_requested=9 WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF x->>'status'<>'blocked_real_tickets_not_reconciled'
 THEN RAISE EXCEPTION 'Actual reserved-seat mismatch incorrectly settled: %',x;END IF;
 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1
 SET seats_requested=10 WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1
 SET paid_upfront=true WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF x->>'status'<>'blocked_real_tickets_not_reconciled'
 THEN RAISE EXCEPTION 'Premature paid booking incorrectly settled: %',x;END IF;
 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1
 SET paid_upfront=false WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF x->>'status'<>'verified_complete_flight_finance_posted_once'
 THEN RAISE EXCEPTION 'Real signed + ticket settlement failed: %',x;END IF;
 SELECT count(*)::text INTO bad_code
 FROM airlinerra_game.section9_route_posted_flight_financials_v1;
 IF bad_code<>'1' THEN RAISE EXCEPTION 'Wrong posted-flight count: %',bad_code;END IF;
 RAISE NOTICE 'PASS signed HMAC, real 20 ticket receipts, tamper and mismatches blocked; single real posting';
END $test$;
