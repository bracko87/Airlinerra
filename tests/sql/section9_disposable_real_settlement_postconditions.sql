-- Real function concurrency postconditions, disposable database only.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 airline uuid:='11111111-1111-4111-8111-111111111111';
 fid text:='44444444-4444-4444-8444-444444444444:2026-11-20:5';
 n bigint; cash numeric; ledgers numeric; r jsonb;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'REFUSE_NON_DISPOSABLE_POSTCONDITIONS';END IF;
 SELECT count(*) INTO n FROM airlinerra_game.section9_route_posted_flight_financials_v1
 WHERE physical_flight_id=fid AND record_status='posted_complete';
 IF n<>1 THEN RAISE EXCEPTION 'Expected one final posted flight, found %',n;END IF;
 SELECT count(*) INTO n FROM airlinerra_game.airline_ledger
 WHERE airline_id=airline AND entry_kind='REVENUE' AND amount_usd=1000;
 IF n<>1 THEN RAISE EXCEPTION 'Revenue was not posted exactly once: %',n;END IF;
 SELECT count(*) INTO n FROM airlinerra_game.airline_ledger
 WHERE airline_id=airline AND entry_kind='EXPENSE' AND amount_usd=-500;
 IF n<>1 THEN RAISE EXCEPTION 'Expense was not posted exactly once: %',n;END IF;
 SELECT count(*) INTO n FROM airlinerra_game.airline_ledger WHERE airline_id=airline;
 IF n<>3 THEN RAISE EXCEPTION 'Unexpected number of ledger entries: %',n;END IF;
 SELECT cash_usd INTO cash FROM airlinerra_game.airlines WHERE id=airline;
 SELECT sum(amount_usd) INTO ledgers FROM airlinerra_game.airline_ledger
 WHERE airline_id=airline;
 IF cash<>5500 OR ledgers<>5500 THEN
  RAISE EXCEPTION 'Cash/ledger mismatch: cash %, ledger %',cash,ledgers;END IF;

 r:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF r->>'status'<>'complete_game_flight_finance_already_posted'
 OR r->>'replayed'<>'true' OR r->>'cashChangedNow'<>'false'
 OR r->>'ledgerPostedNow'<>'false'
 THEN RAISE EXCEPTION 'Idempotent replay rejected or recharged: %',r;END IF;

 SELECT cash_usd INTO cash FROM airlinerra_game.airlines WHERE id=airline;
 SELECT sum(amount_usd) INTO ledgers FROM airlinerra_game.airline_ledger
 WHERE airline_id=airline;
 IF cash<>5500 OR ledgers<>5500 THEN RAISE EXCEPTION 'Replay changed cash';END IF;

 SELECT count(*) INTO n FROM airlinerra_game.section9_route_posted_flight_financials_v1;
 IF n<>1 THEN RAISE EXCEPTION 'Unexpected other posted flights %',n;END IF;
 RAISE NOTICE 'PASS real settlement: one revenue, one expense, one cash delta, replay no-op';
END $test$;
