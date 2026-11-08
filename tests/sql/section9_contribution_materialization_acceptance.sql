BEGIN;
DO $test$
DECLARE j jsonb; claimed jsonb; jid uuid; tok uuid; row jsonb; materialized jsonb; denied boolean:=false;
 BEGIN
  j:=airlinerra_game.section9_enqueue_forecast_day_v1(1::smallint,DATE '2090-03-12');
  claimed:=airlinerra_game.section9_claim_forecast_v1();
  jid:=(claimed->>'jobId')::uuid;tok:=(claimed->>'leaseToken')::uuid;
  IF jid IS DISTINCT FROM (j->>'jobId')::uuid THEN RAISE EXCEPTION 'Wrong job claim';END IF;
  row:=jsonb_build_object(
    'flightId','11111111-1111-4111-8111-111111111111:2090-03-12:1',
    'scheduleId','11111111-1111-4111-8111-111111111111',
    'airlineId','22222222-2222-4222-8222-222222222222',
    'marketDate','2090-03-12','weeklyEntry',1,
    'scheduleVersion',1,'commercialPlanVersion',1,
    'capacitySource','verified_activated_schedule',
    'verificationSource','rollback-only-fixture',
    'passengerSeats',100,'passengers',55,
    'cargoCapacityTonnes',2.500,'cargoTonnes',1.500,
    'ticketRevenueUsd',5555.25,'cargoRevenueUsd',1500.50);
  PERFORM airlinerra_game.section9_stage_forecast_chunk_v1(
    jid,tok,'flight',0,jsonb_build_array(row));
  PERFORM airlinerra_game.section9_complete_forecast_v1(jid,tok,1,0);
  materialized:=airlinerra_game.section9_materialize_completed_flights_v1(jid);
  IF materialized->>'status'<>'materialized' OR
   (materialized->>'storedRows')::int<>1 OR
   (materialized->>'insertedNow')::int<>1
  THEN RAISE EXCEPTION 'First materialization failed: %',materialized;END IF;
  materialized:=airlinerra_game.section9_materialize_completed_flights_v1(jid);
  IF (materialized->>'insertedNow')::int<>0 THEN
    RAISE EXCEPTION 'Materialization not idempotent: %',materialized;END IF;
  IF (SELECT count(*) FROM airlinerra_game.section9_completed_flight_contributions_v1
      WHERE job_id=jid)<>1 THEN RAISE EXCEPTION 'Unexpected duplicate flight contribution';END IF;
  IF (SELECT passengers FROM airlinerra_game.section9_completed_flight_contributions_v1
      WHERE job_id=jid)<>55 THEN RAISE EXCEPTION 'Wrong passenger quantity';END IF;

  PERFORM airlinerra_game.section9_enqueue_forecast_day_v1(1::smallint,DATE '2090-03-13');
  claimed:=airlinerra_game.section9_claim_forecast_v1();
  jid:=(claimed->>'jobId')::uuid;tok:=(claimed->>'leaseToken')::uuid;
  row:=jsonb_set(row,'{capacitySource}','"browser_spoofed"'::jsonb);
  PERFORM airlinerra_game.section9_stage_forecast_chunk_v1(
    jid,tok,'flight',0,jsonb_build_array(row));
  PERFORM airlinerra_game.section9_complete_forecast_v1(jid,tok,1,0);
  BEGIN
   PERFORM airlinerra_game.section9_materialize_completed_flights_v1(jid);
  EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
  IF NOT denied THEN RAISE EXCEPTION 'Unverified row was accepted';END IF;

  IF has_table_privilege('anon',
    'airlinerra_game.section9_completed_flight_contributions_v1','SELECT') OR
   has_function_privilege('authenticated',
    'airlinerra_game.section9_materialize_completed_flights_v1(uuid)','EXECUTE')
  THEN RAISE EXCEPTION 'Public contribution privilege';END IF;
  RAISE NOTICE 'PASS: materialization idempotent, one physical row, unverified source denied, privileges private';
 END $test$;
ROLLBACK;