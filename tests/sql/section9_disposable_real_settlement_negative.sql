-- Run only with the disposable PG17 bootstrap and exact real function source.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 base text:='44444444-4444-4444-8444-444444444444:2026-11-20:5';
 low text:='55555555-5555-4555-8555-555555555555:2026-11-20:5';
 drift text:='66666666-6666-4666-8666-666666666666:2026-11-20:5';
 x jsonb; n bigint;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR
 current_user<>'postgres' THEN
  RAISE EXCEPTION 'REFUSE_NON_DISPOSABLE_SETTLEMENT_ACCEPTANCE';END IF;

 UPDATE airlinerra_game.section9_flight_finance_posting_release_v1
 SET release_state='paused' WHERE world_id=1;
 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(base);
 IF x->>'status'<>'blocked_game_financial_or_flight_release' THEN
  RAISE EXCEPTION 'Paused release did not block: %',x;END IF;
 UPDATE airlinerra_game.section9_flight_finance_posting_release_v1
 SET release_state='approved' WHERE world_id=1;

 UPDATE airlinerra_game.test_independent_evidence SET verified=false
 WHERE physical_flight_id=base;
 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(base);
 IF x->>'status'<>'blocked_unverified_signed_flight_movement' THEN
  RAISE EXCEPTION 'Missing independent proof accepted: %',x;END IF;
 UPDATE airlinerra_game.test_independent_evidence SET verified=true
 WHERE physical_flight_id=base;

 UPDATE airlinerra_game.section9_flight_final_cost_approvals_v1
 SET fuel_reserve_verified=false WHERE physical_flight_id=base;
 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(base);
 IF x->>'status'<>'blocked_unapproved_final_fuel_or_airport_cost' THEN
  RAISE EXCEPTION 'Missing final fuel cost accepted: %',x;END IF;
 UPDATE airlinerra_game.section9_flight_final_cost_approvals_v1
 SET fuel_reserve_verified=true WHERE physical_flight_id=base;

 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(low);
 IF x->>'status'<>'blocked_insufficient_flight_settlement_funds' THEN
  RAISE EXCEPTION 'Insufficient funds accepted: %',x;END IF;
 x:=airlinerra_game.section9_post_completed_flight_finance_once_v1(drift);
 IF x->>'status'<>'blocked_cash_ledger_reconciliation' THEN
  RAISE EXCEPTION 'Ledger drift accepted: %',x;END IF;

 SELECT count(*) INTO n FROM airlinerra_game.section9_route_posted_flight_financials_v1;
 IF n<>0 THEN RAISE EXCEPTION 'Failed preflight posted money';END IF;
 SELECT count(*) INTO n FROM airlinerra_game.airline_ledger
 WHERE entry_kind IN ('REVENUE','EXPENSE');
 IF n<>0 THEN RAISE EXCEPTION 'Failed preflight created ledger entries';END IF;
 RAISE NOTICE 'PASS: paused release, invalid proofs, insufficient cash, ledger drift prevent posting';
END $test$;
