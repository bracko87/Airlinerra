-- Six connections race actual production once-only final finance function
-- against the same synthetic but real-signed/real-booked physical flight.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 fid text:='11111111-1111-4111-8111-111111111111:2026-11-23:4';
 airline uuid:='22222222-2222-4222-8222-222222222222';
 ret jsonb;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'SIGNED_FLIGHT_FINANCE_POST_DISPOSABLE_ONLY';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_route_posted_flight_financials_v1
    WHERE physical_flight_id=fid AND record_status='posted_complete'
      AND passenger_count=5 AND ticket_income_usd=250 AND fuel_cost_usd=144
      AND airport_navigation_cost_usd=75)<>1
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger
     WHERE airline_id=airline AND entry_kind='REVENUE' AND amount_usd=250)<>1
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger
     WHERE airline_id=airline AND entry_kind='EXPENSE' AND amount_usd=-219)<>1
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE airline_id=airline)<>3
 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=airline)<>5000031
 OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger
     WHERE airline_id=airline)<>5000031
 THEN RAISE EXCEPTION 'Same signed booked arrival failed exactly-once $250-$219=$31 settlement';END IF;
 ret:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF ret->>'status'<>'complete_game_flight_finance_already_posted'
 OR ret->>'ledgerPostedNow'<>'false' OR ret->>'cashChangedNow'<>'false'
 THEN RAISE EXCEPTION 'Sequential final finance replay double posted: %',ret;END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE airline_id=airline)<>3
 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=airline)<>5000031
 THEN RAISE EXCEPTION 'Replay modified game ledger balance';END IF;
 ret:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(fid);
 IF ret->>'status'<>'already_posted_do_not_rebook'
 OR ret->>'financeAlreadyPosted'<>'true'
 THEN RAISE EXCEPTION 'Actual reconciler failed to recognize completed posting: %',ret;END IF;
 RAISE NOTICE 'PASS SAME genuine-booked genuine-signed arrived fuel-burned physical flight: $250 actual booked income, $144 synthetic fuel+$75 synthetic airport cost, once-only +$31 cash, 3 ledger rows, replay no-op. Cost approval remains SYNTHETIC CI only.';
END $test$;
