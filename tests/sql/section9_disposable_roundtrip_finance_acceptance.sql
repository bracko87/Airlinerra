\set ON_ERROR_STOP on
DO $test$
DECLARE r jsonb; item record;
BEGIN
 r:=airlinerra_game.section9_prepare_arrived_actual_ticket_finance_batch_v1(25);
 IF r->>'status'<>'verified_arrival_actual_ticket_finance_preflight_complete' OR (r->>'prepared')::int<>2
 THEN RAISE EXCEPTION 'ROUNDTRIP_FINANCE_PREPARATION: %',r;END IF;
 r:=airlinerra_game.section9_auto_approve_completed_game_flight_costs_v1(20);
 IF r->>'status'<>'game_cost_batch_completed' OR (r->>'approved')::int<>2
 THEN RAISE EXCEPTION 'ROUNDTRIP_COST_APPROVAL: %',r;END IF;
 IF (SELECT cash_usd FROM airlinerra_game.airlines)<>5000000 THEN RAISE EXCEPTION 'PREMATURE_FINANCE';END IF;
 r:=airlinerra_game.section9_auto_post_complete_game_flights_v1(20);
 IF r->>'status'<>'game_complete_flight_finance_batch_checked' OR (r->>'posted')::int<>2
 THEN RAISE EXCEPTION 'ROUNDTRIP_FINANCE_POST: %',r;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_route_posted_flight_financials_v1)<>2
 OR (SELECT sum(passenger_count) FROM airlinerra_game.section9_route_posted_flight_financials_v1)<>40
 OR (SELECT sum(ticket_income_usd) FROM airlinerra_game.section9_route_posted_flight_financials_v1)<>3700
 OR (SELECT sum(fuel_cost_usd) FROM airlinerra_game.section9_route_posted_flight_financials_v1)<>600
 OR (SELECT sum(airport_navigation_cost_usd) FROM airlinerra_game.section9_route_posted_flight_financials_v1)<>400
 OR (SELECT cash_usd FROM airlinerra_game.airlines)<>5002700
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>5
 OR (SELECT sum(amount_usd) FROM airlinerra_game.airline_ledger)<>5002700
 THEN RAISE EXCEPTION 'ROUNDTRIP_FINANCE_TOTAL_MISMATCH';END IF;
 r:=airlinerra_game.section9_auto_post_complete_game_flights_v1(20);
 IF (r->>'posted')::int<>0 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>5
 THEN RAISE EXCEPTION 'ROUNDTRIP_FINANCE_REPLAY: %',r;END IF;
 FOR item IN SELECT physical_flight_id FROM airlinerra_game.section9_route_posted_flight_financials_v1 LOOP
  r:=airlinerra_game.section9_post_completed_flight_finance_once_v1(item.physical_flight_id);
  IF r->>'status'<>'complete_game_flight_finance_already_posted' THEN RAISE EXCEPTION 'REPLAY: %',r;END IF;
 END LOOP;
 RAISE NOTICE 'PASS: same aircraft completed both flights, 40 reserved passengers reconciled, $3700 revenue, $1000 costs, $2700 net, no duplicate posting.';
END $test$;
