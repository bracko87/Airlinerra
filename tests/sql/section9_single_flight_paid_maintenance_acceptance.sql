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
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'MAINTENANCE_ACCEPTANCE_WRONG_TARGET';END IF;
 due:=airlinerra_game.section9_owned_game_maintenance_due_v1(player,airline,aircraft,DATE '2026-11-21');
 IF due->>'dueCheckCount'<>'2' OR due->>'maintenanceReady'<>'false'
 OR due->>'gameMaintenanceGrounded'<>'true'
 THEN RAISE EXCEPTION 'Initial overdue daily+weekly count wrong: %',due;END IF;
 win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
  player,airline,aircraft,depart,arrive);
 IF win->>'flightWindowClear'<>'false' OR win->'blockers' NOT @> '["GAME_MAINTENANCE_CHECK_DUE"]'::jsonb
 THEN RAISE EXCEPTION 'Overdue window not blocked: %',win;END IF;
 dispatch:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(
  player,airline,aircraft,depart,arrive);
 IF dispatch->>'gameMaintenanceClear'<>'false' OR
    dispatch->'blockers' NOT @> '["MAINTENANCE_CHECK_DUE_DAILY","MAINTENANCE_CHECK_DUE_WEEKLY"]'::jsonb
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
 RAISE NOTICE 'PASS: real maintenance booking, cancellation, insufficient funds, single-posted game checks, due/dispatch clearance and real single-route/ticket activation. Signed movement, ticket SALES, fuel and postflight finance still NOT proven.';
END $accept$;
ROLLBACK;
DO $clean$ BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_service_receipts_v1)
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 THEN RAISE EXCEPTION 'Integrated synthetic service acceptance did not roll back';END IF;
END $clean$;