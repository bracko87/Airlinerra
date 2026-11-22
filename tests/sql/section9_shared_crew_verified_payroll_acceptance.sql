-- Isolated rollback tests; use historical verified dates, never change world clock.
DO $test$
DECLARE a record;grp text;req uuid:=gen_random_uuid();r jsonb;dt date;before_cash numeric;before_ledger bigint;expected numeric;
BEGIN
 IF (SELECT sum(airlinerra_game.section9_daily_salary_share_v1(8500,d::date)) FROM generate_series('2026-11-01'::timestamp,'2026-11-30'::timestamp,interval '1 day')d)<>8500 OR
 (SELECT sum(airlinerra_game.section9_daily_salary_share_v1(5500,d::date)) FROM generate_series('2028-02-01'::timestamp,'2028-02-29'::timestamp,interval '1 day')d)<>5500 THEN RAISE EXCEPTION 'monthly rounding';END IF;
 BEGIN
 SELECT id,owner_player_id,home_airport_key,cash_usd INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT p.qualification_group INTO STRICT grp FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=f.configuration_id WHERE f.airline_id=a.id AND p.seat_basis<>'cargo_zero' LIMIT 1;
 dt:=(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date;
 before_cash:=a.cash_usd; SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger WHERE airline_id=a.id;
 IF airlinerra_game.section9_post_shared_crew_payroll_v1(a.id,dt-1)->>'status'<>'shared_payroll_disabled' THEN RAISE EXCEPTION 'disabled gate';END IF;
 UPDATE airlinerra_game.section9_shared_crew_employment_release_v1 SET manual_hiring_enabled=true,payroll_start_game_date=dt-1,payroll_enabled=true WHERE world_id=1;
 r:=airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,req,a.home_airport_key,grp,1,1,4,22800);
 IF r->>'status'<>'shared_crew_hired' THEN RAISE EXCEPTION 'hire %',r;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_shared_crew_salary_terms_v1 WHERE request_id=req)<>6 OR (SELECT sum(monthly_salary_usd) FROM airlinerra_game.section9_shared_crew_salary_terms_v1 WHERE request_id=req)<>22800 THEN RAISE EXCEPTION 'salary capture';END IF;
 IF airlinerra_game.section9_post_shared_crew_payroll_v1(a.id,dt)->>'status'<>'payroll_day_not_completed' THEN RAISE EXCEPTION 'open day';END IF;
 -- Backdate ONLY the test fixture after validating actual contract capture.
 UPDATE airlinerra_game.section9_shared_crew_hire_batches_v1 SET effective_game_date=dt-1 WHERE airline_id=a.id AND request_id=req;
 UPDATE airlinerra_game.section9_shared_crew_salary_terms_v1 SET effective_game_date=dt-1 WHERE request_id=req;
 UPDATE airlinerra_game.section9_airline_crew_roster_v1 SET game_effective_date=dt-1 WHERE airline_id=a.id;
 UPDATE airlinerra_game.section9_cabin_crew_members_v1 SET effective_game_date=dt-1 WHERE airline_id=a.id;
 expected:=airlinerra_game.section9_daily_salary_share_v1(8500,dt-1)+airlinerra_game.section9_daily_salary_share_v1(5500,dt-1)+4*airlinerra_game.section9_daily_salary_share_v1(2200,dt-1);
 UPDATE airlinerra_game.airlines SET cash_usd=0 WHERE id=a.id;
 r:=airlinerra_game.section9_post_shared_crew_payroll_v1(a.id,dt-1);
 IF r->>'status'<>'payroll_insufficient_cash' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_crew_payroll_days_v1 WHERE airline_id=a.id) THEN RAISE EXCEPTION 'cash guard %',r;END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=before_cash WHERE id=a.id;
 r:=airlinerra_game.section9_post_shared_crew_payroll_v1(a.id,dt-1);
 IF r->>'status'<>'shared_crew_payroll_posted' OR (r->>'amountUsd')::numeric<>expected OR r->>'crewCount'<>'6' THEN RAISE EXCEPTION 'posting %',r;END IF;
 IF airlinerra_game.section9_post_shared_crew_payroll_v1(a.id,dt-1)->>'status'<>'already_posted' THEN RAISE EXCEPTION 'duplicate';END IF;
 IF (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=a.id)<>before_cash-expected OR (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE airline_id=a.id)<>before_ledger+1 OR (SELECT sum(amount_usd) FROM airlinerra_game.section9_shared_crew_payroll_lines_v1 WHERE airline_id=a.id AND game_date=dt-1)<>expected THEN RAISE EXCEPTION 'ledger reconciliation';END IF;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;END;
END $test$;
SELECT 'passed' test,(SELECT count(*) FROM airlinerra_game.section9_shared_crew_payroll_lines_v1) persisted_lines,(SELECT count(*) FROM airlinerra_game.section9_shared_crew_salary_terms_v1) persisted_terms,(SELECT count(*) FROM airlinerra_game.section9_game_crew_payroll_days_v1) persisted_days,has_function_privilege('authenticated','airlinerra_game.section9_post_shared_crew_payroll_v1(uuid,date)','execute') client_access,(SELECT to_jsonb(r) FROM airlinerra_game.section9_shared_crew_employment_release_v1 r) release;