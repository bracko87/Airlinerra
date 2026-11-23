-- Disposable PostgreSQL only. Test the UNMODIFIED automatic-demand
-- conversion worker against the reviewed, UNDEPLOYED ticket-issuer candidate.
-- Run after section9_disposable_real_connecting_ticket_acceptance.sql.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_capacity_hold_plans_v1') IS NULL
 THEN RAISE EXCEPTION 'AUTO_DEMAND_WORKER_DISPOSABLE_ONLY';END IF;
END $guard$;
\i /tmp/section9-demand-worker-actual.sql
REVOKE ALL ON FUNCTION airlinerra_game.section9_promote_completed_demand_holds_batch_v1(integer)
 FROM PUBLIC,anon,authenticated,service_role;

-- Confirm the deployed worker skips already-issued claims without writing.
DO $already_issued$
DECLARE receipt jsonb; ticket_key text:='demand.s9g1:'||repeat('b',64);
BEGIN
 receipt:=airlinerra_game.section9_promote_completed_demand_holds_batch_v1(50);
 IF receipt->>'status'<>'verified_demand_ticket_conversion_batch_completed'
 OR receipt->>'itinerariesIssued'<>'0'
 OR receipt->>'reservationLegsCreated'<>'0'
 OR receipt->>'ledgerPosted'<>'false'
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
   WHERE reservation_key=ticket_key)<>2
 THEN RAISE EXCEPTION 'Worker double-issued existing itinerary: %',receipt;END IF;
END $already_issued$;

-- Simulate a recoverable unissued hold: held capacity remains reserved, but
-- the original ticket rows are removed only inside this disposable fixture.
DELETE FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE reservation_key='demand.s9g1:'||repeat('b',64);
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET booked_seats=0 WHERE id IN
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
  'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid);

DO $positive$
DECLARE receipt jsonb; ticket_key text:='demand.s9g1:'||repeat('b',64);
BEGIN
 receipt:=airlinerra_game.section9_promote_completed_demand_holds_batch_v1(50);
 IF receipt->>'status'<>'verified_demand_ticket_conversion_batch_completed'
 OR receipt->>'itinerariesIssued'<>'1'
 OR receipt->>'reservationLegsCreated'<>'2'
 OR receipt->>'ledgerPosted'<>'false'
 OR receipt->>'upfrontCharges'<>'false'
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
    WHERE reservation_key=ticket_key AND seats_requested=2
    AND recognized_revenue_usd=0 AND paid_upfront=false)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1
    WHERE id IN ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid,
                 'ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)
    AND booked_seats=2)<>2
 THEN RAISE EXCEPTION 'Worker failed to issue both real reservation legs: %',receipt;END IF;
 receipt:=airlinerra_game.section9_promote_completed_demand_holds_batch_v1(50);
 IF receipt->>'itinerariesIssued'<>'0' OR receipt->>'reservationLegsCreated'<>'0'
 THEN RAISE EXCEPTION 'Worker duplicate schedule pass: %',receipt;END IF;
 RAISE NOTICE 'PASS original automatic demand worker issues two legs once and skips replay';
END $positive$;

-- Create a deliberately partially issued connecting journey. The original
-- worker must FAIL CLOSED rather than silently issue one missing leg.
DELETE FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE reservation_key='demand.s9g1:'||repeat('b',64)
 AND occurrence_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid;
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET booked_seats=0 WHERE id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid;
DO $partial$
DECLARE caught boolean:=false;receipt jsonb;
BEGIN
 BEGIN
  receipt:=airlinerra_game.section9_promote_completed_demand_holds_batch_v1(50);
 EXCEPTION WHEN SQLSTATE '23505' THEN caught:=true;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'Partial connecting journey was silently accepted: %',receipt;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1
     WHERE reservation_key='demand.s9g1:'||repeat('b',64))<>1
 OR (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'::uuid)<>0
 OR (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id='ffffffff-ffff-4fff-8fff-ffffffffffff'::uuid)<>2
 THEN RAISE EXCEPTION 'Partial worker fail-closed guard mutated records';END IF;
 RAISE NOTICE 'PASS worker rejects partially issued connecting itinerary without partial repair';
END $partial$;
