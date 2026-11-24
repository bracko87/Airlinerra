-- ONE single-direction Saturday BEG -> ZAG source-backed GAME model,
-- with the unchanged genuine game phase timing, source-snapshotted
-- 4-week BEG/ZAG/MUC airport evidence, genuine Section9 GAME guard,
-- original first-departure route transaction, and real paid game maintenance.
-- External licence issuer, slot reservation and ground position remain
-- SYNTHETIC test doubles: no production approval is asserted.
\set ON_ERROR_STOP on
BEGIN;
DO $test$
DECLARE
 player uuid:='22222222-2222-4222-8222-222222222222';
 airline uuid:='11111111-1111-4111-8111-111111111111';
 aircraft uuid:='33333333-3333-4333-8333-333333333333';
 origin text:='OURAIRPORTS:4610';
 zag text:='OURAIRPORTS:3993';
 muc text:='OURAIRPORTS:2218';
 weekly jsonb:='[{"day":5,"time":"11:00"}]'::jsonb;
 due jsonb;win jsonb;profile jsonb;receipt jsonb;result jsonb;
 job jsonb;advance jsonb;daily_job uuid;weekly_job uuid;sid uuid;
 old_cash numeric;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'BEG_ZAG_FIRST_FLIGHT_DISPOSABLE_ONLY';END IF;
 IF (SELECT count(*) FROM airlinerra_game.fixture_source_route_game_evidence)<>2
 THEN RAISE EXCEPTION 'Live game route source screen snapshot missing';END IF;
 SELECT weekly_screen INTO receipt FROM airlinerra_game.fixture_source_route_game_evidence
 WHERE destination_code='ZAG';
 IF receipt->>'weeklyTimetableChecked'<>'true'
 OR receipt->>'gameHardBlocked'<>'false'
 OR receipt->>'needsReview'<>'true'
 OR jsonb_array_length(receipt->'occurrences')<>4
 OR NOT airlinerra_game.section9_game_route_restrictions_valid_v1(origin,zag,receipt)
 THEN RAISE EXCEPTION 'Genuine BEG-ZAG game guard disagrees with 2026-11-24 read-only source';END IF;
 SELECT weekly_screen INTO receipt FROM airlinerra_game.fixture_source_route_game_evidence
 WHERE destination_code='MUC';
 IF receipt->>'gameHardBlocked'<>'false'
 OR receipt->>'needsReview'<>'true'
 OR airlinerra_game.section9_game_route_restrictions_valid_v1(origin,muc,receipt)
 THEN RAISE EXCEPTION 'MUC exact A319 noise certificate was incorrectly approved';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1
     WHERE airport_key=zag AND game_nighttime_ban)
 THEN RAISE EXCEPTION 'ZAG catalog nighttime flag disappeared (its simplified rule differs)';END IF;
 profile:=airlinerra_game.section9_game_route_phase_profile_v1(100,origin,zag,NULL);
 IF profile->>'totalMinutes'<>'54' OR profile->>'distanceKm'<>'347'
 OR profile IS DISTINCT FROM
    (SELECT phase_profile FROM airlinerra_game.fixture_source_route_game_evidence WHERE destination_code='ZAG')
 THEN RAISE EXCEPTION 'Real game A319 timing changed relative to read-only live source: %',profile;END IF;
 old_cash:=(SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger WHERE airline_id=airline);
 IF old_cash<>5000000 THEN RAISE EXCEPTION 'Opening synthetic airline balance incorrect';END IF;
 due:=airlinerra_game.section9_owned_game_maintenance_due_v1(player,airline,aircraft,DATE '2026-11-28');
 win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
  player,airline,aircraft,'2026-11-28 10:00+00'::timestamptz,'2026-11-28 10:54+00'::timestamptz);
 IF due->>'dueCheckCount'<>'2' OR win->>'flightWindowClear'<>'false'
 THEN RAISE EXCEPTION 'Before service, aircraft must be GROUNDED: % / %',due,win;END IF;
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL105',origin,zag,weekly,
  'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'blocked_first_departure'
 OR result#>>'{details,reason}'<>'MAINTENANCE_FLIGHT_WINDOW_BLOCKED'
 OR result->>'routeCreated'<>'false'
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 THEN RAISE EXCEPTION 'Overdue source-backed BEG-ZAG route did not roll back: %',result;END IF;

 -- GENUINE paid maintenance engine from main, using source-grounded
 -- provisional game price $240 Daily and $900 Weekly. Not player money.
 job:=airlinerra_game.section9_owned_game_maintenance_job_v1(player,airline,aircraft,'book','daily');
 IF job->>'status'<>'scheduled' OR job->>'quotedCostUsd'<>'240'
 THEN RAISE EXCEPTION 'Daily maintenance booking was rejected: %',job;END IF;
 daily_job:=(job->>'jobId')::uuid;
 UPDATE airlinerra_game.fixture_game_now SET simulated_now='2026-11-28 01:05+00';
 advance:=airlinerra_game.section9_advance_game_maintenance_jobs_v1();
 IF advance->>'financialPostings'<>'1' OR advance->>'gameMaintenanceExpenseUsd'<>'240'
 OR (SELECT status FROM airlinerra_game.section9_game_maintenance_jobs_v1
     WHERE job_id=daily_job)<>'completed'
 THEN RAISE EXCEPTION 'Daily paid completion did not post: %',advance;END IF;
 job:=airlinerra_game.section9_owned_game_maintenance_job_v1(player,airline,aircraft,'book','weekly');
 IF job->>'status'<>'scheduled' OR job->>'quotedCostUsd'<>'900'
 THEN RAISE EXCEPTION 'Weekly maintenance booking was rejected: %',job;END IF;
 weekly_job:=(job->>'jobId')::uuid;
 UPDATE airlinerra_game.fixture_game_now SET simulated_now='2026-11-28 04:15+00';
 advance:=airlinerra_game.section9_advance_game_maintenance_jobs_v1();
 IF advance->>'financialPostings'<>'1' OR advance->>'gameMaintenanceExpenseUsd'<>'900'
 OR (SELECT status FROM airlinerra_game.section9_game_maintenance_jobs_v1
     WHERE job_id=weekly_job)<>'completed'
 THEN RAISE EXCEPTION 'Weekly paid completion did not post: %',advance;END IF;
 advance:=airlinerra_game.section9_advance_game_maintenance_jobs_v1();
 IF advance->>'financialPostings'<>'0'
 OR (SELECT count(*) FROM airlinerra_game.section9_game_maintenance_service_receipts_v1)<>2
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE entry_kind='EXPENSE')<>2
 OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger WHERE airline_id=airline)<>4998860
 THEN RAISE EXCEPTION 'Game maintenance expense replay/sums incorrect';END IF;
 due:=airlinerra_game.section9_owned_game_maintenance_due_v1(player,airline,aircraft,DATE '2026-11-28');
 win:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
  player,airline,aircraft,'2026-11-28 10:00+00'::timestamptz,'2026-11-28 10:54+00'::timestamptz);
 IF due->>'dueCheckCount'<>'0' OR win->>'flightWindowClear'<>'true'
 THEN RAISE EXCEPTION 'Paid maintenance did not clear 10UTC first departure: % / %',due,win;END IF;

 -- Even after GAME maintenance, MUC cannot use the uncertified noise chapter.
 -- The *REAL* Section9 airport game guard is called in the atomic transaction
 -- at the synthetic certificate edge and must roll back ALL earlier inserts.
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL106',origin,muc,weekly,
  'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'blocked_operational_requirement'
 OR result->>'clearanceType'<>'airport_slot_capacity'
 OR result#>>'{details,status}'<>'blocked_actual_section9_game_restrictions'
 OR result->>'routeCreated'<>'false'
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 OR (SELECT count(*) FROM airlinerra_game.fixture_certificates)<>0
 THEN RAISE EXCEPTION 'MUC noise GAME restriction failure leaked route or rights: %',result;END IF;
 -- Actual first departure reachable check: no impossible BEG departure if
 -- synthetic aircraft starts at ZAG. Future return remains only a warning.
 UPDATE airlinerra_game.fixture_single_route_control SET position_airport=zag;
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL107',origin,zag,weekly,
  'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'blocked_first_departure'
 OR result#>>'{details,reason}'<>'AIRCRAFT_CANNOT_REACH_FIRST_DEPARTURE'
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 THEN RAISE EXCEPTION 'Wrong first departure position did not roll back: %',result;END IF;
 UPDATE airlinerra_game.fixture_single_route_control SET position_airport=origin;

 -- Genuine current single-flight creator on source-grounded GAME phase/
 -- airport restrictions and paid maintenance. Slot & licence certificate
 -- signers remain explicitly SYNTHETIC (not a live operating approval).
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL105',origin,zag,weekly,
  'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'active' OR result->>'routeCreated'<>'true'
 OR result->>'slotsReserved'<>'true'
 OR result->>'bookingEnabled'<>'true'
 OR result->>'ledgerPosted'<>'false'
 OR result->>'saleableDepartures'<>'1'
 OR result->>'estimatedDurationMinutes'<>'54'
 OR result->>'referenceDepartureUtc' IS NULL
 OR result->>'referenceArrivalUtc' IS NULL
 THEN RAISE EXCEPTION 'BEG-ZAG daytime A319 positive route not activated: %',result;END IF;
 sid:=(result->>'scheduleId')::uuid;
 IF (result->>'referenceDepartureUtc')::timestamptz
        IS DISTINCT FROM '2026-11-28 10:00+00'::timestamptz
 OR (result->>'referenceArrivalUtc')::timestamptz
        IS DISTINCT FROM '2026-11-28 10:54+00'::timestamptz
 OR (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1
     WHERE id=sid AND origin_airport_key=origin AND destination_airport_key=zag
       AND status='active' AND operationally_verified)<>1
 OR (SELECT passenger_seats FROM airlinerra_game.section9_verified_schedule_capacity_v1 WHERE schedule_id=sid)<>125
 OR (SELECT count(*) FROM airlinerra_game.fixture_certificates WHERE schedule_id=sid)<>5
 OR (SELECT count(*) FROM airlinerra_game.fixture_slot_reservations WHERE schedule_id=sid)<>2
 OR (SELECT count(*) FROM airlinerra_game.fixture_ticket_occurrences
     WHERE schedule_id=sid AND flight_local_date=DATE '2026-11-28' AND passenger_seats=125)<>1
 OR (SELECT count(*) FROM airlinerra_game.airline_route_planning_drafts_v1
     WHERE airline_id=airline AND flight_number='AL105')<>1
 OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger WHERE airline_id=airline)<>4998860
 THEN RAISE EXCEPTION 'Positive source-grounded single flight had wrong seat/timing/fee records';END IF;
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL105',origin,zag,weekly,
  'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'blocked_flight_number_exists' OR result->>'routeCreated'<>'false'
 OR (SELECT count(*) FROM airlinerra_game.fixture_ticket_occurrences WHERE schedule_id=sid)<>1
 OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger WHERE airline_id=airline)<>4998860
 THEN RAISE EXCEPTION 'Duplicate positive flight caused extra charges or inventory: %',result;END IF;

 RAISE NOTICE 'PASS: source-grounded actual A319 BEG-ZAG GAME phase 347km/54m and GAME restriction, synthetic issuer only; overdue daily+weekly -> genuine $240+$900 game maintenance -> 125 seats active first flight 10:00Z; MUC unverified chapter/wrong airport/duplicate all roll back.';
END $test$;
ROLLBACK;

DO $clean$ BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_service_receipts_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_certificates)
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 THEN RAISE EXCEPTION 'Source-grounded BEG-ZAG test transaction not rolled back';END IF;
END $clean$;
