-- Real maintenance booking + due + settled game expense + dispatch preflight
-- connected to the same synthetic aircraft's real atomic single-route SQL.
-- All other certification/slot/ticket authorities remain synthetic.
\set ON_ERROR_STOP on
BEGIN;
DO $accept$
DECLARE
 player uuid:='22222222-2222-4222-8222-222222222222';
 airline uuid:='11111111-1111-4111-8111-111111111111';
 aircraft uuid:='33333333-3333-4333-8333-333333333333';
 origin text:='OURAIRPORTS:2212';
 dest text:='OURAIRPORTS:2218';
 depart timestamptz:='2026-11-21 14:00:00+00';
 arrive timestamptz:='2026-11-21 15:00:00+00';
 weekly jsonb:='[{"day":5,"time":"15:00"}]'::jsonb;
 due jsonb;win jsonb;dispatch jsonb;job jsonb;result jsonb;advance jsonb;
 dail_id uuid;week_id uuid;
 booking_occurrence uuid; booking jsonb; booking_replay jsonb; reservation_id uuid; active_schedule uuid;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'MAINTENANCE_ACCEPTANCE_WRONG_TARGET';END IF;
 due:=airlinerra_game.section9_owned_game_maintenance_due_v1(player,airline,aircraft,DATE '2026-11-21');
 IF due->>'dueCheckCount'<>'2' OR due->>'maintenanceReady'<>'false'
 OR due->>'gameMaintenanceGrounded'<>'true'
 THEN RAISE EXCEPTION 'Initial overdue daily+weekly count wrong: %',due;END IF;
 win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
  player,airline,aircraft,depart,arrive);
 IF win->>'flightWindowClear'<>'false' OR NOT (win->'blockers' @> '["GAME_MAINTENANCE_CHECK_DUE"]'::jsonb)
 THEN RAISE EXCEPTION 'Overdue window not blocked: %',win;END IF;
 dispatch:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(
  player,airline,aircraft,depart,arrive);
 IF dispatch->>'gameMaintenanceClear'<>'false' OR
    NOT (dispatch->'blockers' @> '["MAINTENANCE_CHECK_DUE_DAILY","MAINTENANCE_CHECK_DUE_WEEKLY"]'::jsonb)
 THEN RAISE EXCEPTION 'Signed-dispatch-side maintenance preflight not blocked: %',dispatch;END IF;
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL104',origin,dest,weekly,'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'blocked_first_departure' OR result#>>'{details,reason}'<>'MAINTENANCE_FLIGHT_WINDOW_BLOCKED'
 OR result->>'routeCreated'<>'false'
 THEN RAISE EXCEPTION 'Flight was not blocked by genuine maintenance function: %',result;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 THEN RAISE EXCEPTION 'Blocked maintenance flight leaked slot/tickets';END IF;
 -- True current booking SQL: cancel a scheduled Daily before it begins.
 job:=airlinerra_game.section9_owned_game_maintenance_job_v1(player,airline,aircraft,'book','daily');
 IF job->>'status'<>'scheduled' OR job->>'chargedNow'<>'false' OR job->>'created'<>'true'
 THEN RAISE EXCEPTION 'Daily maintenance booking failed: %',job;END IF;
 dail_id:=(job->>'jobId')::uuid;
 job:=airlinerra_game.section9_owned_game_maintenance_job_v1(player,airline,aircraft,'book','weekly');
 IF job->>'status'<>'aircraft_already_booked_for_maintenance' OR job->>'created'<>'false'
 THEN RAISE EXCEPTION 'Concurrent maintenance booking not blocked: %',job;END IF;
 job:=airlinerra_game.section9_owned_game_maintenance_job_v1(player,airline,aircraft,'cancel',NULL);
 IF job->>'status'<>'cancelled' OR job->>'changed'<>'true'
 THEN RAISE EXCEPTION 'Scheduled service cancellation failed: %',job;END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE entry_kind='EXPENSE')<>0
 THEN RAISE EXCEPTION 'Cancelled service charged money';END IF;
 job:=airlinerra_game.section9_owned_game_maintenance_job_v1(player,airline,aircraft,'book','daily');
 IF job->>'status'<>'scheduled' OR job->>'quotedCostUsd'<>'125'
 THEN RAISE EXCEPTION 'Replacement daily game service did not book: %',job;END IF;
 dail_id:=(job->>'jobId')::uuid;
 -- Advance the synthetic world hour past one-hour Daily end with ZERO funds.
 -- The actual settlement worker must retain an unpaid grounded job.
 UPDATE airlinerra_game.fixture_game_now SET simulated_now='2026-11-21 08:05+00';
 UPDATE airlinerra_game.airline_ledger SET amount_usd=0 WHERE entry_kind='CAPITAL';
 advance:=airlinerra_game.section9_advance_game_maintenance_jobs_v1();
 IF (SELECT status FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE job_id=dail_id)<>'payment_required'
 OR (SELECT count(*) FROM airlinerra_game.section9_game_maintenance_service_receipts_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE entry_kind='EXPENSE')<>0
 OR advance->>'financialPostings'<>'0'
 THEN RAISE EXCEPTION 'Unpaid Daily must remain grounded with zero charges: %',advance;END IF;
 due:=airlinerra_game.section9_owned_game_maintenance_due_v1(player,airline,aircraft,DATE '2026-11-21');
 IF due->>'dueCheckCount'<>'2' OR due->>'gameJobBlocksDate'<>'true'
 THEN RAISE EXCEPTION 'Unpaid maintenance incorrectly released Daily: %',due;END IF;
 -- Funding allows exactly one completion charge and one source receipt.
 UPDATE airlinerra_game.airline_ledger SET amount_usd=5000000 WHERE entry_kind='CAPITAL';
 advance:=airlinerra_game.section9_advance_game_maintenance_jobs_v1();
 IF advance->>'financialPostings'<>'1' OR advance->>'gameMaintenanceExpenseUsd'<>'125'
 OR (SELECT status FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE job_id=dail_id)<>'completed'
 THEN RAISE EXCEPTION 'Daily completion was not settled once: %',advance;END IF;
 advance:=airlinerra_game.section9_advance_game_maintenance_jobs_v1();
 IF advance->>'financialPostings'<>'0' OR
 (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE entry_kind='EXPENSE')<>1
 THEN RAISE EXCEPTION 'Daily service replay charged twice: %',advance;END IF;
 due:=airlinerra_game.section9_owned_game_maintenance_due_v1(player,airline,aircraft,DATE '2026-11-21');
 IF due->>'dueCheckCount'<>'1' THEN RAISE EXCEPTION 'Paid Daily should leave only Weekly due: %',due;END IF;
 -- Book Weekly after Daily completion, then collect one genuine paid receipt.
 job:=airlinerra_game.section9_owned_game_maintenance_job_v1(player,airline,aircraft,'book','weekly');
 IF job->>'status'<>'scheduled' OR job->>'quotedCostUsd'<>'450'
 THEN RAISE EXCEPTION 'Weekly service did not book: %',job;END IF;
 week_id:=(job->>'jobId')::uuid;
 UPDATE airlinerra_game.fixture_game_now SET simulated_now='2026-11-21 11:10+00';
 advance:=airlinerra_game.section9_advance_game_maintenance_jobs_v1();
 IF advance->>'financialPostings'<>'1' OR advance->>'gameMaintenanceExpenseUsd'<>'450'
 OR (SELECT status FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE job_id=week_id)<>'completed'
 THEN RAISE EXCEPTION 'Weekly service not financially settled: %',advance;END IF;
 advance:=airlinerra_game.section9_advance_game_maintenance_jobs_v1();
 IF advance->>'financialPostings'<>'0'
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE entry_kind='EXPENSE')<>2
 OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger WHERE entry_kind='EXPENSE')<>-575
 OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger WHERE airline_id=airline)<>4999425
 OR (SELECT count(*) FROM airlinerra_game.section9_game_maintenance_service_receipts_v1 r
   JOIN airlinerra_game.airline_ledger l ON l.id=r.paid_ledger_entry_id
   WHERE r.airline_id=airline AND l.entry_kind='EXPENSE'
   AND l.amount_usd=-r.settled_cost_usd)<>2
 THEN RAISE EXCEPTION 'Exactly-once maintenance charge/receipt invariant violated: %',advance;END IF;
 due:=airlinerra_game.section9_owned_game_maintenance_due_v1(player,airline,aircraft,DATE '2026-11-21');
 IF due->>'dueCheckCount'<>'0' OR due->>'gameMaintenanceGrounded'<>'false'
 THEN RAISE EXCEPTION 'Both paid game checks should clear current day: %',due;END IF;
 win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(player,airline,aircraft,depart,arrive);
 dispatch:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(player,airline,aircraft,depart,arrive);
 IF win->>'flightWindowClear'<>'true' OR dispatch->>'gameMaintenanceClear'<>'true'
 OR dispatch->>'dispatchApproved'<>'false'
 THEN RAISE EXCEPTION 'Post-service flight preflight not clear: % :: %',win,dispatch;END IF;
 -- Regression: calendar-day gate must not reject a future morning flight
 -- before its verified paid Daily deadline, nor permit arrival at/after it.
 -- Historical fixture has separate paid Daily and Weekly receipts.
 DECLARE deadline timestamptz; original_now timestamptz;
 BEGIN
  SELECT game_completed_at_utc+interval '24 hours' INTO STRICT deadline
   FROM airlinerra_game.section9_game_maintenance_service_receipts_v1 WHERE job_id=dail_id;
  win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(player,airline,aircraft,deadline-interval '2 hours',deadline-interval '1 minute');
  IF win->>'flightWindowClear' IS DISTINCT FROM 'true'
   THEN RAISE EXCEPTION 'Future due-date morning flight wrongly blocked: %',win; END IF;
  win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(player,airline,aircraft,deadline-interval '1 hour',deadline);
  IF win->>'flightWindowClear' IS DISTINCT FROM 'false' OR NOT (win->'blockers' @> '["GAME_MAINTENANCE_CHECK_DUE"]'::jsonb)
   THEN RAISE EXCEPTION 'Exact maintenance expiry must block: %',win; END IF;
  win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(player,airline,aircraft,deadline+interval '1 minute',deadline+interval '1 hour');
  IF win->>'flightWindowClear' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Overdue future departure passed: %',win; END IF;
  win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(player,airline,aircraft,deadline-interval '12 hours',deadline-interval '1 minute');
  IF win->>'flightWindowClear' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Cross-midnight before expiry blocked: %',win; END IF;
  SELECT simulated_now INTO STRICT original_now FROM airlinerra_game.fixture_game_now;
  UPDATE airlinerra_game.fixture_game_now SET simulated_now=deadline-interval '2 hours';
  UPDATE airlinerra_game.holding_world_clock_v1 SET confirmed_game_date=(deadline AT TIME ZONE 'Europe/Berlin')::date;
  win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(player,airline,aircraft,deadline-interval '1 hour',deadline+interval '1 minute');
  IF win->>'flightWindowClear' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Current-day crossing deadline passed: %',win; END IF;
  UPDATE airlinerra_game.fixture_game_now SET simulated_now=original_now;
  UPDATE airlinerra_game.holding_world_clock_v1 SET confirmed_game_date=(original_now AT TIME ZONE 'Europe/Berlin')::date;
  RAISE NOTICE 'PASS: paid maintenance exact deadline, before/equal/after and cross-midnight.';
 END;
 -- The SAME synthetic aircraft can now use exact genuine main single-route code.
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL104',origin,dest,weekly,'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'active' OR result->>'routeCreated'<>'true'
 OR result->>'activated'<>'true' OR result->>'bookingEnabled'<>'true'
 OR result->>'slotsReserved'<>'true' OR result->>'ledgerPosted'<>'false'
 OR result->>'saleableDepartures'<>'1'
 THEN RAISE EXCEPTION 'Single flight not activated after real paid maintenance: %',result;END IF;
 IF (SELECT count(*) FROM airlinerra_game.fixture_ticket_occurrences
      WHERE schedule_id=(result->>'scheduleId')::uuid AND passenger_seats=110)<>1
 THEN RAISE EXCEPTION 'Expected one saleable synthetic ticket occurrence';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE entry_kind='EXPENSE')<>2
 THEN RAISE EXCEPTION 'Route creation charged extra money';END IF;

 -- Materialize the same synthetic saleable flight from the route receipt.
 -- The route's certification/slot/ticket-opening authorities remain fixtures,
 -- while every following reservation change uses genuine production SQL.
 active_schedule:=(result->>'scheduleId')::uuid;
 INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1
  (schedule_id,direction)
 SELECT schedule_id,CASE WHEN airport_key=origin THEN 'departure' ELSE 'arrival' END
 FROM airlinerra_game.fixture_slot_reservations WHERE schedule_id=active_schedule;
 IF (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
     WHERE schedule_id=active_schedule)<>2 THEN
  RAISE EXCEPTION 'Test did not attach exactly two existing synthetic slot receipts';END IF;
 INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1
  (schedule_id,airline_id,aircraft_inventory_id,flight_local_date,weekly_entry,
   schedule_version,commercial_version,verified_passenger_seats,booked_seats,
   source_kind,booking_status)
 SELECT s.id,s.airline_id,s.aircraft_inventory_id,f.flight_local_date,f.weekly_entry,
   s.version,p.version,f.passenger_seats,0,'game_verified_saleable_schedule_v1','open'
 FROM airlinerra_game.fixture_ticket_occurrences f
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=f.schedule_id
 JOIN airlinerra_game.section9_route_commercial_plans_v1 p ON p.schedule_id=s.id
 WHERE s.id=active_schedule
 RETURNING id INTO booking_occurrence;
 INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1
  (physical_flight_id,schedule_id,airline_id,passenger_capacity,
   schedule_version,commercial_version,passengers_held,status)
 SELECT o.schedule_id::text||':'||o.flight_local_date||':'||o.weekly_entry,
    o.schedule_id,o.airline_id,o.verified_passenger_seats,
    o.schedule_version,o.commercial_version,0,'preflight_only'
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=booking_occurrence;
 booking:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
   booking_occurrence,'trusted.test.booking.00001','economy',20);
 IF booking->>'status'<>'game_passenger_seats_reserved' OR
    booking->>'seatsReservedNow'<>'20' OR booking->>'totalSeatsBooked'<>'20'
 OR booking->>'remainingSeats'<>'90' OR booking->>'chargedNow'<>'false'
 OR booking->>'revenueRecognizedNow'<>'false' OR booking->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Real passenger booking failed: %',booking;END IF;
 reservation_id:=(booking->>'reservationId')::uuid;
 booking_replay:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
   booking_occurrence,'trusted.test.booking.00001','economy',20);
 IF booking_replay->>'status'<>'game_passenger_reservation_replayed'
 OR booking_replay->>'replayed'<>'true' OR booking_replay->>'reservedNow'<>'false'
 OR (booking_replay->>'reservationId')::uuid<>reservation_id
 THEN RAISE EXCEPTION 'Same reservation key duplicated passengers: %',booking_replay;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
   booking_occurrence,'trusted.test.booking.00001','economy',19);
  RAISE EXCEPTION 'Mismatched replay was accepted without a hard error';
 EXCEPTION WHEN unique_violation THEN
  IF SQLERRM NOT LIKE '%SECTION9_PASSENGER_RESERVATION_REPLAY_MISMATCH%'
  THEN RAISE;END IF;
 END;
 booking:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
  booking_occurrence,'trusted.test.booking.too-many','economy',95);
 IF booking->>'status'<>'blocked_insufficient_available_seats'
 OR booking->>'availableSeats'<>'90' OR booking->>'chargedNow'<>'false'
 THEN RAISE EXCEPTION 'Oversell was not denied: %',booking;END IF;
 booking:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
  booking_occurrence,'trusted.test.booking.00002','economy',90);
 IF booking->>'status'<>'game_passenger_seats_reserved'
 OR booking->>'totalSeatsBooked'<>'110' OR booking->>'remainingSeats'<>'0'
 OR booking->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Remaining seat booking incorrect: %',booking;END IF;
 IF (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id=booking_occurrence)<>110
 OR (SELECT passengers_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
     WHERE schedule_id=active_schedule)<>110
 OR (SELECT count(*) FROM airlinerra_game.section9_passenger_reservation_batches_v1 b
     WHERE b.occurrence_id=booking_occurrence)<>2
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE entry_kind='EXPENSE')<>2
 OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger
     WHERE airline_id=airline)<>4999425
 THEN RAISE EXCEPTION 'Bookings diverged from inventory or posted upfront money';END IF;
 -- Controlled test movement row only, NOT a signed engine event:
 -- the real writer must refuse further reservations after any movement.
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1
 (event_id,schedule_id,flight_local_date,weekly_entry)
 SELECT 'synthetic-booking-closed-marker',o.schedule_id,o.flight_local_date,o.weekly_entry
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=booking_occurrence;
 booking:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
  booking_occurrence,'trusted.test.booking.after-movement','economy',1);
 IF booking->>'status'<>'blocked_slots_or_flight_already_operated'
 OR booking->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Post-movement booking did not fail closed: %',booking;END IF;
 RAISE NOTICE 'PASS real paid maintenance -> real single-route activation -> real synthetic passenger reservations: 20+90 seats, replay and oversell rejected, no preflight ticket revenue, booking blocked after synthetic movement marker. Signed actual departure/arrival, fuel and final flight finance remain UNPROVEN.';
END $accept$;
ROLLBACK;
DO $clean$ BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_service_receipts_v1)
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_reservation_batches_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1)
 THEN RAISE EXCEPTION 'Integrated synthetic service and booking acceptance did not roll back';END IF;
END $clean$;