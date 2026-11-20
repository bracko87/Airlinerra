-- Actual production pair activation, with controlled disposable dependency
-- services. Verify every rollback leaves both schedules drafts and 0 tickets.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 p uuid:='22222222-2222-4222-8222-222222222222';
 a uuid:='11111111-1111-4111-8111-111111111111';
 out_id uuid:='44444444-4444-4444-8444-444444444444';
 back_id uuid:='55555555-5555-4555-8555-555555555555';
 x jsonb;error_seen boolean;blocked_status text;
BEGIN
 IF current_database()<>'airlinerra_disposable'
 OR current_user<>'postgres' THEN
  RAISE EXCEPTION 'POSITIVE_FRA_MUC_NOT_DISPOSABLE'; END IF;
 -- Pre-existing independent certification count must be exactly ten.
 SELECT count(*)::text INTO blocked_status
 FROM airlinerra_game.section9_schedule_operational_certifications_v1;
 IF blocked_status<>'10' THEN RAISE EXCEPTION 'Expected ten fixture receipts';END IF;
 -- Missing one signed receipt must block BEFORE either leg is activated.
 UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
 SET review_status='pending' WHERE schedule_id=back_id AND clearance_type='slots';
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
  p,a,out_id,back_id,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'blocked_ten_independent_signed_certifications_missing'
 OR x->>'certificationsFound'<>'9'
 THEN RAISE EXCEPTION 'Missing signed certification did not deny pair: %',x;END IF;
 UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
 SET review_status='certified' WHERE schedule_id=back_id AND clearance_type='slots';
 -- In all rollback tests, use a savepoint via nested PL/pgSQL exception
 -- subtransaction, so a real RAISE rolls back BOTH activation and inventory.
 UPDATE airlinerra_game.fixture_reject SET enabled=true WHERE name='second_leg';
 error_seen:=false;
 BEGIN
  PERFORM airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
   p,a,out_id,back_id,1,1,DATE '2026-11-20',28);
 EXCEPTION WHEN SQLSTATE '42501' THEN error_seen:=true;
 END;
 IF NOT error_seen THEN RAISE EXCEPTION 'Second leg failure not atomic';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE status<>'draft' OR operationally_verified)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_verified_seat_capacity)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 THEN RAISE EXCEPTION 'Second leg rollback leaked schedule or inventory'; END IF;
 UPDATE airlinerra_game.fixture_reject SET enabled=false WHERE name='second_leg';

 UPDATE airlinerra_game.fixture_reject SET enabled=true WHERE name='capacity';
 error_seen:=false;
 BEGIN
  PERFORM airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
   p,a,out_id,back_id,1,1,DATE '2026-11-20',28);
 EXCEPTION WHEN SQLSTATE '42501' THEN error_seen:=true;
 END;
 IF NOT error_seen THEN RAISE EXCEPTION 'Second capacity failure not atomic';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE status<>'draft' OR operationally_verified)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_verified_seat_capacity)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 THEN RAISE EXCEPTION 'Capacity rollback leaked schedule or inventory'; END IF;
 UPDATE airlinerra_game.fixture_reject SET enabled=false WHERE name='capacity';

 UPDATE airlinerra_game.fixture_reject SET enabled=true WHERE name='return_ticket';
 error_seen:=false;
 BEGIN
  PERFORM airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
   p,a,out_id,back_id,1,1,DATE '2026-11-20',28);
 EXCEPTION WHEN SQLSTATE '42501' THEN error_seen:=true;
 END;
 IF NOT error_seen THEN RAISE EXCEPTION 'Return ticket failure not atomic';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE status<>'draft' OR operationally_verified)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_verified_seat_capacity)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 THEN RAISE EXCEPTION 'Return inventory rollback leaked schedule or tickets'; END IF;
 UPDATE airlinerra_game.fixture_reject SET enabled=false WHERE name='return_ticket';

 -- Actual production SQL now activates both legs and opens two *saleable*
 -- dated occurrences; no reservations, movements or ledger created.
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
  p,a,out_id,back_id,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'certified_roundtrip_schedules_activated_and_tickets_open'
 OR x->>'operatingSchedulesActivated'<>'true'
 OR x->>'ticketSalesOpen'<>'true'
 OR (x->>'verifiedPassengerSeatsPerFlight')::integer<>110
 OR (x->>'outboundSaleableOccurrences')::integer<>1
 OR (x->>'returnSaleableOccurrences')::integer<>1
 OR x->>'ticketsSold'<>'0' OR x->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Positive pair activation contract mismatch: %',x;END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE status='active' AND operationally_verified)=2
 AND (SELECT count(*) FROM airlinerra_game.fixture_verified_seat_capacity
  WHERE passenger_seats=110)=2
 AND (SELECT count(*) FROM airlinerra_game.fixture_ticket_occurrences
  WHERE flight_local_date=DATE '2026-11-21'
    AND passenger_seats=110)=2
 THEN NULL;
 ELSE RAISE EXCEPTION 'Dual-leg activation did not persist exactly two schedules and inventories'; END IF;
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
  p,a,out_id,back_id,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'blocked_pair_stale_or_not_a_return_route'
 THEN RAISE EXCEPTION 'Replay reactivated an active schedule: %',x;END IF;
 IF (SELECT count(*) FROM airlinerra_game.fixture_ticket_occurrences)<>2
 THEN RAISE EXCEPTION 'Replay added duplicate inventory';END IF;
 RAISE NOTICE 'PASS: 10 certification records, 3 atomic rollback cases, successful FRA–MUC/MUC–FRA activation, two ticket inventories, no sales, replay blocked';
END $test$;
