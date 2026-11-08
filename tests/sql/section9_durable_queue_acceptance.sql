-- Rollback-only Section 9 durable queue acceptance.
-- No active airline, money, flight schedule, or real game date is modified.
BEGIN;
DO $checks$
DECLARE first_job uuid; stale_token uuid; next_token uuid;
 c jsonb; i int; did_fail boolean; test_day date:=DATE '2090-03-12';
BEGIN
 PERFORM airlinerra_game.section9_enqueue_forecast_day_v1(1::smallint,test_day);
 c:=airlinerra_game.section9_claim_forecast_v1();
 first_job:=(c->>'jobId')::uuid;stale_token:=(c->>'leaseToken')::uuid;
 IF (c->>'attempt')::int<>1 THEN RAISE EXCEPTION 'First claim failed: %',c;END IF;
 IF airlinerra_game.section9_claim_forecast_v1() IS NOT NULL THEN
  RAISE EXCEPTION 'Duplicate live work claim';END IF;
 PERFORM airlinerra_game.section9_stage_forecast_chunk_v1(first_job,stale_token,'flight',0,
  '[{"flightId":"f1","passengers":100,"cargoTonnes":1.25}]'::jsonb);
 PERFORM airlinerra_game.section9_stage_forecast_chunk_v1(first_job,stale_token,'market',0,
  '[{"marketId":"A-B","demand":100,"allocated":100}]'::jsonb);
 did_fail:=false;
 BEGIN
  PERFORM airlinerra_game.section9_complete_forecast_v1(first_job,stale_token,2,1);
 EXCEPTION WHEN SQLSTATE '22023' THEN did_fail:=true;END;
 IF NOT did_fail THEN RAISE EXCEPTION 'Incomplete result was accepted';END IF;
 PERFORM airlinerra_game.section9_extend_forecast_lease_v1(first_job,stale_token);
 c:=airlinerra_game.section9_complete_forecast_v1(first_job,stale_token,1,1);
 IF c->>'status'<>'completed' THEN RAISE EXCEPTION 'Finalize failed';END IF;
 did_fail:=false;
 BEGIN
  PERFORM airlinerra_game.section9_stage_forecast_chunk_v1(first_job,stale_token,
   'flight',1,'[{"flightId":"f2","passengers":0,"cargoTonnes":0}]'::jsonb);
 EXCEPTION WHEN SQLSTATE '42501' THEN did_fail:=true;END;
 IF NOT did_fail THEN RAISE EXCEPTION 'Completed worker not fenced';END IF;

 -- Exhaust five worker leases on another date, verifying no sixth claim.
 PERFORM airlinerra_game.section9_enqueue_forecast_day_v1(1::smallint,test_day+1);
 FOR i IN 1..5 LOOP
  c:=airlinerra_game.section9_claim_forecast_v1();
  IF c IS NULL OR (c->>'attempt')::int<>i THEN
   RAISE EXCEPTION 'Incorrect retry attempt %: %',i,c;END IF;
  IF i=1 THEN stale_token:=(c->>'leaseToken')::uuid;
  ELSE
   did_fail:=false;
   BEGIN
    PERFORM airlinerra_game.section9_extend_forecast_lease_v1(
     (c->>'jobId')::uuid,stale_token);
   EXCEPTION WHEN SQLSTATE '42501' THEN did_fail:=true;END;
   IF NOT did_fail THEN RAISE EXCEPTION 'Expired previous token was accepted';END IF;
  END IF;
  UPDATE airlinerra_game.section9_demand_jobs_v1
   SET lease_until=clock_timestamp()-interval '1 second'
   WHERE id=(c->>'jobId')::uuid;
 END LOOP;
 IF airlinerra_game.section9_claim_forecast_v1() IS NOT NULL THEN
  RAISE EXCEPTION 'Sixth processing attempt was accepted';END IF;
 IF (SELECT status FROM airlinerra_game.section9_demand_jobs_v1
     WHERE game_date=test_day+1) <> 'failed' THEN
  RAISE EXCEPTION 'Exhausted job not marked failed';END IF;
 IF has_function_privilege('anon',
    'airlinerra_game.section9_claim_forecast_v1()','EXECUTE')
 OR has_function_privilege('authenticated',
    'airlinerra_game.section9_claim_forecast_v1()','EXECUTE')
 OR has_table_privilege('authenticated',
    'airlinerra_game.section9_demand_job_chunks_v1','SELECT') THEN
  RAISE EXCEPTION 'Public read/claim privilege leaked';END IF;
 RAISE NOTICE 'SECTION9 PASS: claims, chunk validation, expiry fencing, five-attempt failure and private security';
END $checks$;
ROLLBACK;
