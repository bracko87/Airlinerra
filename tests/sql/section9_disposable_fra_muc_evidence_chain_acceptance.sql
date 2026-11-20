-- Isolated database only. Uses SQL fixtures and the REAL deployed inspector
-- function source; asserts its evidence joins, refusal and one-record identity.
-- No production DB connection or real airline ledger.
\set ON_ERROR_STOP on
BEGIN;
DO $test$
DECLARE
 flight text:='33333333-3333-4333-8333-333333333333:2026-11-20:5';
 owner uuid:='11111111-1111-4111-8111-111111111111';
 aircraft uuid:='22222222-2222-4222-8222-222222222222';
 schedule uuid:='33333333-3333-4333-8333-333333333333';
 occ uuid:='44444444-4444-4444-8444-444444444444';
 result jsonb; failed boolean:=false;
BEGIN
 SELECT airlinerra_game.section9_inspect_completed_flight_chain_v1(flight)
 INTO result;
 IF result->>'status'<>'EVIDENCE_CHAIN_INCOMPLETE'
 OR result->>'canPost'<>'false'
 OR NOT result->'issues' ? 'SIGNED_DEPARTURE_MISSING'
 THEN RAISE EXCEPTION 'Missing flight incorrectly accepted: %',result;END IF;

 INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1
 (id,world_id,schedule_id,airline_id,aircraft_inventory_id,
 schedule_version,weekly_entry,flight_local_date,
 origin_airport_key,destination_airport_key,booked_seats,verified_passenger_seats)
 VALUES(occ,1,schedule,owner,aircraft,1,5,DATE '2026-11-20',
 'OURAIRPORTS:2212','OURAIRPORTS:2218',4,100);
 IF NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1
   WHERE id=occ AND origin_airport_key='OURAIRPORTS:2212'
   AND destination_airport_key='OURAIRPORTS:2218')
 THEN RAISE EXCEPTION 'FRA–MUC test route invalid';END IF;
 INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1
 (id,occurrence_id,seats_requested,reservation_status,paid_upfront,
 recognized_revenue_usd) VALUES
 ('55555555-5555-4555-8555-555555555555',occ,3,'reserved',false,0);
 SELECT airlinerra_game.section9_inspect_completed_flight_chain_v1(flight)
 INTO result;
 IF NOT result->'issues' ? 'BOOKED_SEATS_RESERVATIONS_MISMATCH'
 THEN RAISE EXCEPTION 'Seat inventory mismatch not detected: %',result;END IF;

 INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1
 (id,occurrence_id,seats_requested,reservation_status,paid_upfront,
 recognized_revenue_usd) VALUES
 ('66666666-6666-4666-8666-666666666666',occ,1,'reserved',false,0);
 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1
 SET paid_upfront=true
 WHERE id='66666666-6666-4666-8666-666666666666';
 SELECT airlinerra_game.section9_inspect_completed_flight_chain_v1(flight)
 INTO result;
 IF NOT result->'issues' ? 'RESERVATION_PREPAID_OR_PREMATURE_REVENUE'
 THEN RAISE EXCEPTION 'Premature booking payment not detected: %',result;END IF;
 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1
 SET paid_upfront=false WHERE paid_upfront=true;

 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1
 (world_id,flight_occurrence_id,phase,engine_event_id,airline_id,
 schedule_id,schedule_version,aircraft_inventory_id,actual_event_utc,recorded_at)
 VALUES
 (1,flight,'departed','evt-depart',owner,schedule,1,aircraft,
 '2026-11-20 10:00:00+00','2026-11-20 10:00:00+00'),
 (1,flight,'arrived','evt-arrive',owner,schedule,1,aircraft,
 '2026-11-20 11:00:00+00','2026-11-20 11:00:00+00');
 INSERT INTO airlinerra_game.section9_arrived_aircraft_usage_receipts_v1
 VALUES(flight,'evt-arrive','evt-depart');
 INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1
 VALUES(flight,'evt-arrive');
 INSERT INTO airlinerra_game.section9_flight_final_cost_approvals_v1
 VALUES(flight,'approved','evt-arrive');

 SELECT airlinerra_game.section9_inspect_completed_flight_chain_v1(flight)
 INTO result;
 IF result->'issues' ? 'SIGNED_DEPARTURE_MISSING'
 OR result->'issues' ? 'SIGNED_ARRIVAL_MISSING'
 OR result->'issues' ? 'BOOKED_SEATS_RESERVATIONS_MISMATCH'
 OR NOT result->'issues' ? 'COMPLETED_FLIGHT_FINANCE_NOT_POSTED'
 OR result->>'canPost'<>'false'
 THEN RAISE EXCEPTION 'Pre-settlement chain result incorrect: %',result;END IF;

 INSERT INTO airlinerra_game.section9_route_posted_flight_financials_v1
 VALUES(flight,'evt-arrive',1001,1002);
 SELECT airlinerra_game.section9_inspect_completed_flight_chain_v1(flight)
 INTO result;
 IF result->>'status'<>
 'EVIDENCE_CHAIN_PRESENT_REQUIRES_INDEPENDENT_SIGNATURE_AND_LEDGER_VERIFICATION'
 OR result->>'alreadyPosted'<>'true'
 OR result->>'ledgerPosted'<>'false'
 OR result->>'canPost'<>'false'
 OR jsonb_array_length(result->'issues')<>0
 THEN RAISE EXCEPTION 'Complete evidence chain falsely authorized: %',result;END IF;

 BEGIN
  INSERT INTO airlinerra_game.section9_route_posted_flight_financials_v1
  VALUES(flight,'evt-arrive',1003,1004);
 EXCEPTION WHEN unique_violation THEN failed:=true;
 END;
 IF NOT failed THEN
  RAISE EXCEPTION 'Duplicate flight identity must not be posted twice';END IF;

 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1
 (world_id,flight_occurrence_id,phase,engine_event_id,airline_id,
 schedule_id,schedule_version,aircraft_inventory_id,actual_event_utc,recorded_at)
 VALUES(1,flight,'arrived','evt-arrive-duplicate',owner,schedule,1,aircraft,
 '2026-11-20 11:10:00+00','2026-11-20 11:10:00+00');
 SELECT airlinerra_game.section9_inspect_completed_flight_chain_v1(flight)
 INTO result;
 IF NOT result->'issues' ? 'DUPLICATE_OPERATED_PHASE_RECORDS'
 THEN RAISE EXCEPTION 'Duplicate arrival not identified: %',result;END IF;
 RAISE NOTICE 'PASS: missing evidence, seat mismatch, premature booking, verified phase pair, pre-settlement hold, duplicate-post identity, duplicate arrival';
END $test$;
ROLLBACK;
