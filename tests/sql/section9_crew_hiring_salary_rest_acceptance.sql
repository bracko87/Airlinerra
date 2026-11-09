-- All fixtures and calls in ONE rollback transaction; no persistent crew
-- records, aircraft, schedules, wages or cash changes.
BEGIN;
DO $test$
DECLARE a uuid;u uuid;code text;plane uuid;s1 uuid;s2 uuid;
 offer jsonb;hire jsonb;repeat_hire jsonb;wage jsonb;pay jsonb;
 duty jsonb;ops jsonb;nonowner_denied boolean:=false;
 prior_cash numeric; prior_ledger bigint; prior_count int;
BEGIN
 SELECT id,owner_player_id,iata_code,cash_usd
 INTO a,u,code,prior_cash FROM airlinerra_game.airlines
 WHERE world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'No test airline available';END IF;
 SELECT count(*) INTO prior_ledger FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO prior_count FROM airlinerra_game.section9_airline_crew_roster_v1;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'S9-HIRE-ROLLBACK','owned','in_service') RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,
  reference_departure_utc,reference_arrival_utc,
  weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,plane,3,code||'984',
 'OURAIRPORTS:2214','OURAIRPORTS:2212',
 '2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',
 '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,u)
 RETURNING id INTO s1;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,
  reference_departure_utc,reference_arrival_utc,
  weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,plane,3,code||'985',
 'OURAIRPORTS:2212','OURAIRPORTS:2214',
 '2026-11-09T13:00:00Z','2026-11-09T14:00:00Z',
 '[{"day":0,"time":"14:00"}]'::jsonb,'{}'::jsonb,u)
 RETURNING id INTO s2;
 offer:=airlinerra_game.section9_owned_crew_offers_v1(u,a,s1);
 IF offer->>'status'<>'game_npc_crew_market' OR
    jsonb_array_length(offer->'offers')<>12
 THEN RAISE EXCEPTION 'NPC market missing: %',offer;END IF;
 hire:=airlinerra_game.section9_hire_owned_game_crew_v1(u,a,s1,1);
 repeat_hire:=airlinerra_game.section9_hire_owned_game_crew_v1(u,a,s1,1);
 IF hire->>'newContract'<>'true' OR
  repeat_hire->>'newContract'<>'false' OR
  repeat_hire->>'crewId'<>hire->>'crewId' OR
  hire->>'ledgerPosted'<>'false' OR
  (hire->>'monthlySalaryUsd')::numeric<=0
 THEN RAISE EXCEPTION 'Crew hiring idempotency or salary failed: %, %',
 hire,repeat_hire;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_hire_owned_game_crew_v1(
   gen_random_uuid(),a,s1,2);
 EXCEPTION WHEN SQLSTATE '42501' THEN nonowner_denied:=true;END;
 IF NOT nonowner_denied THEN RAISE EXCEPTION 'Non-owner hired crew';END IF;
 PERFORM airlinerra_game.section9_plan_owned_crew_duty_v1(
  u,a,s1,(hire->>'crewId')::uuid,1,'plan');
 PERFORM airlinerra_game.section9_plan_owned_crew_duty_v1(
  u,a,s2,(hire->>'crewId')::uuid,1,'plan');
 duty:=airlinerra_game.section9_owned_crew_rest_preview_v1(
  u,a,s1,'2026-11-09',14);
 IF (duty->>'insufficientRest')::int<1 OR
    duty->>'canActivateNormalFlight'<>'false' OR
    duty->>'actualLegalDutyAndRestCertified'<>'false'
 THEN RAISE EXCEPTION 'Crew rest not flagged: %',duty;END IF;
 ops:=airlinerra_game.section9_owned_operations_with_crew_rights_v1(
  u,a,s1,'2026-11-09',14);
 IF ops->'crewRest'->>'canActivateNormalFlight'<>'false' OR
    ops->>'canActivateNormalFlight'<>'false' OR
    (ops->'crewStaffing'->>'registeredEmployeeAssignments')::int<1
 THEN RAISE EXCEPTION 'Operational composite failed closed: %',ops;END IF;
 wage:=airlinerra_game.section9_owned_game_crew_salary_preview_v1(u,a);
 IF wage->>'clockVerified'<>'false' OR
    (wage->>'monthlySalaryCommitmentUsd')::numeric<=0 OR
    wage->>'automaticPayrollEnabled'<>'false'
 THEN RAISE EXCEPTION 'Salary preview false: %',wage;END IF;
 pay:=airlinerra_game.section9_post_verified_game_crew_payroll_v1(
  a,'2000-01-01');
 IF pay->>'status'<>'blocked_unverified_game_clock' OR
    pay->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Payroll ran without trusted clock: %',pay;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_crew_payroll_days_v1
  WHERE airline_id=a) OR
  (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=a)<>prior_cash OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>prior_ledger
 THEN RAISE EXCEPTION 'Unverified game clock wrote salary or cash';END IF;
 IF has_function_privilege('authenticated',
  'airlinerra_game.section9_post_verified_game_crew_payroll_v1(uuid,date)','EXECUTE')
 OR has_function_privilege('anon',
  'airlinerra_game.section9_hire_owned_game_crew_v1(uuid,uuid,uuid,int)','EXECUTE')
 OR has_table_privilege('authenticated',
  'airlinerra_game.section9_game_crew_payroll_days_v1','INSERT')
 THEN RAISE EXCEPTION 'Payroll/crew direct SQL access leaked';END IF;
 RAISE NOTICE 'PASS: game crew offer, hire replay, ownership, duties/rest, salary and no clock means no payroll';
END $test$;
ROLLBACK;