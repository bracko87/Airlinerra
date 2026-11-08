BEGIN;
DO $test$
DECLARE target_day date; d date;j jsonb; claimed jsonb; jid uuid; token uuid;
 data jsonb; pax integer; denied_overbook boolean:=false;
 denied_activation boolean:=false;
 prior_ledger bigint;
BEGIN
 SELECT count(*) INTO prior_ledger FROM airlinerra_game.airline_ledger;
 FOR target_day IN SELECT unnest(ARRAY[DATE '2090-03-12',DATE '2091-03-12'])
 LOOP
  FOR d IN SELECT generate_series(target_day-1,target_day+1,interval '1 day')::date
  LOOP
   j:=airlinerra_game.section9_enqueue_forecast_day_v1(1::smallint,d);
   claimed:=airlinerra_game.section9_claim_forecast_v1();
   jid:=(claimed->>'jobId')::uuid;token:=(claimed->>'leaseToken')::uuid;
   IF jid IS DISTINCT FROM (j->>'jobId')::uuid THEN
    RAISE EXCEPTION 'Unexpected forecast claim on %',d;END IF;
   IF d<target_day+1 THEN
    pax:=CASE WHEN d=target_day-1 THEN 70
     WHEN target_day=DATE '2090-03-12' THEN 40 ELSE 20 END;
    data:=jsonb_build_object(
      'flightId','11111111-1111-4111-8111-111111111111:'||
        target_day::text||':1',
      'scheduleId','11111111-1111-4111-8111-111111111111',
      'airlineId','22222222-2222-4222-8222-222222222222',
      'marketDate',target_day,'weeklyEntry',1,
      'scheduleVersion',1,'commercialPlanVersion',1,
      'capacitySource','verified_activated_schedule',
      'verificationSource','rollback-only-fixture',
      'passengerSeats',100,'passengers',pax,
      'directPassengers',pax,'connectingPassengers',0,
      'cargoCapacityTonnes',2.0,'cargoTonnes',0,
      'ticketRevenueUsd',pax*100,'cargoRevenueUsd',0,
      'departureUtc',target_day::text||'T10:00:00Z',
      'arrivalUtc',target_day::text||'T12:00:00Z');
    PERFORM airlinerra_game.section9_stage_forecast_chunk_v1(
      jid,token,'flight',0,jsonb_build_array(data));
    PERFORM airlinerra_game.section9_complete_forecast_v1(jid,token,1,0);
   ELSE
    PERFORM airlinerra_game.section9_complete_forecast_v1(jid,token,0,0);
   END IF;
   PERFORM airlinerra_game.section9_materialize_completed_flights_v1(jid);
  END LOOP;
  IF target_day=DATE '2090-03-12' THEN
   BEGIN
    PERFORM airlinerra_game.section9_prepare_verified_settlement_batch_v1(
      1::smallint,target_day,NULL,100);
   EXCEPTION WHEN SQLSTATE '22023' THEN denied_overbook:=true;END;
   IF NOT denied_overbook THEN
    RAISE EXCEPTION 'Overbooked shared flight was accepted';END IF;
  ELSE
   BEGIN
    PERFORM airlinerra_game.section9_prepare_verified_settlement_batch_v1(
      1::smallint,target_day,NULL,100);
   EXCEPTION WHEN SQLSTATE '42501' THEN denied_activation:=true;END;
   IF NOT denied_activation THEN
    RAISE EXCEPTION 'Unactivated flight settlement was accepted';END IF;
  END IF;
 END LOOP;
 IF (SELECT count(*) FROM airlinerra_game.section9_prepared_occurrence_settlements_v1)>0 OR
    (SELECT count(*) FROM airlinerra_game.section9_unposted_revenue_intents_v1)>0 THEN
  RAISE EXCEPTION 'Unsafe settlement proof persisted';
 END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger)<>prior_ledger THEN
  RAISE EXCEPTION 'Real airline ledger was mutated';
 END IF;
 IF has_table_privilege('anon',
    'airlinerra_game.section9_prepared_occurrence_settlements_v1','INSERT') OR
    has_function_privilege('authenticated',
    'airlinerra_game.section9_prepare_verified_settlement_batch_v1(smallint,date,text,integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Public settlement authority leaked';END IF;
 RAISE NOTICE 'PASS: overbooking blocked, unactivated flights blocked, no income credited, private access';
END $test$;
ROLLBACK;