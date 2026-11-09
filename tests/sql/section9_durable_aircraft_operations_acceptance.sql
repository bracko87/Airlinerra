-- Rollback-only durable aircraft operations queue / stale worker acceptance.
-- Creates no permanent aircraft, schedules, game-clock release or movements.
BEGIN;
DO $test$
DECLARE a uuid;owner_id uuid;aircraft uuid;job uuid;tomorrow uuid;
 result jsonb;token1 uuid;token2 uuid;bad uuid:=gen_random_uuid();
 before_jobs bigint;before_movements bigint;before_positions bigint;
 before_ledger bigint;recovered integer;
BEGIN
 IF has_table_privilege('anon',
  'airlinerra_game.section9_aircraft_day_operations_jobs_v1','SELECT')
 OR has_table_privilege('authenticated',
  'airlinerra_game.section9_aircraft_day_operations_jobs_v1','INSERT')
 OR has_function_privilege('authenticated',
  'airlinerra_game.section9_claim_aircraft_operations_v1()','EXECUTE')
 OR has_function_privilege('anon',
  'airlinerra_game.section9_record_leased_operated_flight_movement_v1(uuid,uuid,uuid,uuid,integer,date,integer,text,timestamptz,text,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Browser role could use private operation queue';END IF;
 SELECT count(*) INTO before_jobs FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1;
 SELECT count(*) INTO before_movements FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO before_positions FROM airlinerra_game.section9_aircraft_current_position_v1;
 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;
 result:=airlinerra_game.section9_enqueue_aircraft_operations_batch_v1(
   DATE '2000-01-03',NULL,100);
 IF result->>'status'<>'blocked_unverified_world_or_game_day'
 THEN RAISE EXCEPTION 'Unopened world unexpectedly enqueued operations';END IF;
 SELECT id,owner_player_id INTO a,owner_id FROM airlinerra_game.airlines
  WHERE world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'Requires one known World 1 test airline';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'S9-JOB-ROLLBACK','owned','in_service')
 RETURNING id INTO aircraft;
 UPDATE public.airlinerra_game_worlds SET state='active',
  opens_at=clock_timestamp()-interval '7 days' WHERE id=1;
 UPDATE airlinerra_game.holding_world_clock_v1
 SET clock_source='authoritative_game_engine',
  confirmed_game_date=DATE '2000-01-04',
  engine_proof_ref='ROLLBACK_SIGNED_OPERATIONS_20000104',
  last_verified_at=clock_timestamp() WHERE world_id=1;
 INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1(
  world_id,game_date,engine_event_id,event_hmac_sha256,dispatch_kind)
 VALUES(1,DATE '2000-01-03','rollback-job-20000103',
        repeat('a',64),'no_verified_flights'),
       (1,DATE '2000-01-04','rollback-job-20000104',
        repeat('b',64),'no_verified_flights');
 result:=airlinerra_game.section9_enqueue_aircraft_operations_batch_v1(
   DATE '2000-01-03',NULL,100);
 IF result->>'status'<>'aircraft_operation_jobs_enqueued'
 OR result->>'jobsEnqueued'<>'0'
 THEN RAISE EXCEPTION 'Draft-only schedules unexpectedly entered queue: %',result;END IF;
 -- Fixture jobs are inserted exclusively inside this transaction.
 INSERT INTO airlinerra_game.section9_aircraft_day_operations_jobs_v1(
  airline_id,aircraft_inventory_id,game_date)
 VALUES(a,aircraft,DATE '2000-01-03') RETURNING id INTO job;
 INSERT INTO airlinerra_game.section9_aircraft_day_operations_jobs_v1(
  airline_id,aircraft_inventory_id,game_date)
 VALUES(a,aircraft,DATE '2000-01-04') RETURNING id INTO tomorrow;
 result:=airlinerra_game.section9_claim_aircraft_operations_v1();
 IF result->>'status'<>'claimed'
 OR (result->>'jobId')::uuid<>job
 OR (result->>'attempt')::integer<>1
 THEN RAISE EXCEPTION 'Oldest aircraft date not claimed first: %',result;END IF;
 token1:=(result->>'leaseToken')::uuid;
 result:=airlinerra_game.section9_claim_aircraft_operations_v1();
 IF result IS NOT NULL THEN RAISE EXCEPTION 'Second day of aircraft claimed while first running';END IF;
 BEGIN
  PERFORM airlinerra_game.section9_heartbeat_aircraft_operations_v1(job,bad);
  RAISE EXCEPTION 'Wrong lease heartbeat accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN
  PERFORM airlinerra_game.section9_record_leased_operated_flight_movement_v1(
   job,bad,a,gen_random_uuid(),1,DATE '2000-01-03',1,'departed',
   '2000-01-03T10:00:00Z','rollback-deny-stale-lease',repeat('a',64));
  RAISE EXCEPTION 'Invalid lease wrote movement';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN
  PERFORM airlinerra_game.section9_complete_aircraft_operations_v1(job,token1,0,0);
  RAISE EXCEPTION 'Job completed without a verified activated schedule';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 UPDATE airlinerra_game.section9_aircraft_day_operations_jobs_v1
 SET lease_until=clock_timestamp()-interval '1 second' WHERE id=job;
 recovered:=airlinerra_game.section9_recover_expired_aircraft_jobs_v1(50);
 IF recovered<>1 THEN RAISE EXCEPTION 'Expected exactly one reclaimed stale lease';END IF;
 BEGIN
  PERFORM airlinerra_game.section9_heartbeat_aircraft_operations_v1(job,token1);
  RAISE EXCEPTION 'Expired worker renewed a reclaimed lease';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 UPDATE airlinerra_game.section9_aircraft_day_operations_jobs_v1
 SET next_attempt_at=clock_timestamp()-interval '1 minute' WHERE id=job;
 result:=airlinerra_game.section9_claim_aircraft_operations_v1();
 IF (result->>'jobId')::uuid IS DISTINCT FROM job
 OR (result->>'attempt')::integer<>2
 THEN RAISE EXCEPTION 'Recovered older job was not claimed before next day: %',result;END IF;
 token2:=(result->>'leaseToken')::uuid;
 BEGIN
  PERFORM airlinerra_game.section9_record_leased_operated_flight_movement_v1(
   job,token1,a,gen_random_uuid(),1,DATE '2000-01-03',1,'departed',
   '2000-01-03T10:00:00Z','rollback-stale-retry-deny',repeat('c',64));
  RAISE EXCEPTION 'Superseded lease was accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 result:=airlinerra_game.section9_fail_aircraft_operations_v1(
  job,token2,'OPERATION_DECISION_MISSING');
 IF result->>'status'<>'queued' OR result->>'attempt'<>'2'
 THEN RAISE EXCEPTION 'Recoverable engine failure not queued: %',result;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)
  <>before_movements OR
  (SELECT count(*) FROM airlinerra_game.section9_aircraft_current_position_v1)
  <>before_positions OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_ledger
 THEN RAISE EXCEPTION 'Queue wrote movements, positions or money';END IF;
 RAISE NOTICE 'PASS: private queue, clock gate, draft exclusion, chronology, single running aircraft, fencing, expiry recovery, retry';
END $test$;
ROLLBACK;