-- Rollback acceptance: immutable, restartable plans and all-or-nothing
-- physical-flight batches. Does NOT create any genuine airline bookings.
BEGIN;
DO $tests$
DECLARE first jsonb; again jsonb; stage_result jsonb;
 j uuid; empty_j uuid; denied boolean; result jsonb;
 flight text:='11111111-1111-4111-8111-111111111111:2090-10-01:1';
 one jsonb;two jsonb;baseline int;
BEGIN
 SELECT count(*) INTO baseline FROM airlinerra_game.airline_ledger;
 first:=airlinerra_game.section9_create_hold_plan_v1(
  DATE '2090-10-01',3,repeat('a',64),2);
 j:=(first->>'planId')::uuid;
 again:=airlinerra_game.section9_create_hold_plan_v1(
  DATE '2090-10-01',3,repeat('a',64),2);
 IF (again->>'planId')::uuid<>j THEN
  RAISE EXCEPTION 'Changed replay job identity';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_create_hold_plan_v1(
   DATE '2090-10-01',3,repeat('b',64),2);
 EXCEPTION WHEN unique_violation THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Changed snapshot was accepted';END IF;
 one:=jsonb_build_object('sequence',0,'allocationKey','s9g1:'||repeat('1',64),
  'flightIds',jsonb_build_array(flight),'passengers',40,'cargoTonnes',0.25);
 two:=jsonb_build_object('sequence',1,'allocationKey','s9g1:'||repeat('2',64),
  'flightIds',jsonb_build_array(flight),'passengers',30,'cargoTonnes',0.35);
 stage_result:=airlinerra_game.section9_stage_hold_plan_chunk_v1(
  j,jsonb_build_array(one));
 IF (stage_result->>'newItems')::int<>1 THEN
  RAISE EXCEPTION 'Stage failed';END IF;
 stage_result:=airlinerra_game.section9_stage_hold_plan_chunk_v1(
  j,jsonb_build_array(one));
 IF (stage_result->>'newItems')::int<>0 THEN
  RAISE EXCEPTION 'Replay duplicated a staged allocation';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_stage_hold_plan_chunk_v1(
   j,jsonb_build_array(jsonb_set(one,'{passengers}','41'::jsonb)));
 EXCEPTION WHEN unique_violation THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Changed retry silently overwritten staged allocation';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_seal_hold_plan_v1(j);
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Incomplete manifest was sealed';END IF;
 PERFORM airlinerra_game.section9_stage_hold_plan_chunk_v1(
  j,jsonb_build_array(two));
 result:=airlinerra_game.section9_seal_hold_plan_v1(j);
 IF result->>'status'<>'ready' THEN
  RAISE EXCEPTION 'Complete manifest not ready';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_stage_hold_plan_chunk_v1(
   j,jsonb_build_array(two));
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Sealed plan was still mutable';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_apply_hold_plan_batch_v1(j,2);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Unverified flight accepted in batch';END IF;
 IF (SELECT next_allocation_seq FROM airlinerra_game.section9_capacity_hold_plans_v1
  WHERE id=j)<>0 OR
  EXISTS(SELECT 1 FROM airlinerra_game.section9_atomic_itinerary_holds_v1
   WHERE source_allocation_key IN ('s9g1:'||repeat('1',64),'s9g1:'||repeat('2',64)))
 THEN RAISE EXCEPTION 'Failed atomic batch wrote progress or capacity holds';END IF;
 result:=airlinerra_game.section9_create_hold_plan_v1(
  DATE '2090-10-10',2,repeat('c',64),0);
 empty_j:=(result->>'planId')::uuid;
 result:=airlinerra_game.section9_seal_hold_plan_v1(empty_j);
 IF result->>'status'<>'completed' OR
  (SELECT next_allocation_seq FROM airlinerra_game.section9_capacity_hold_plans_v1
   WHERE id=empty_j)<>0
 THEN RAISE EXCEPTION 'Valid empty demand day did not complete';END IF;
 result:=airlinerra_game.section9_apply_hold_plan_batch_v1(empty_j,50);
 IF result->>'status'<>'completed' OR (result->>'processed')::int<>0
 THEN RAISE EXCEPTION 'Completed empty plan replay unsafe';END IF;
 IF has_function_privilege('anon',
  'airlinerra_game.section9_apply_hold_plan_batch_v1(uuid,integer)','EXECUTE')
 OR has_function_privilege('authenticated',
  'airlinerra_game.section9_stage_hold_plan_chunk_v1(uuid,jsonb)','EXECUTE')
 OR has_table_privilege('authenticated',
  'airlinerra_game.section9_capacity_hold_plan_items_v1','SELECT')
 THEN RAISE EXCEPTION 'Browser exposed internal capacity plan';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger)<>baseline
 THEN RAISE EXCEPTION 'Airline ledger unexpectedly changed';END IF;
 RAISE NOTICE 'PASS: snapshot conflict, immutable staging, incomplete seal, transactional rollback, zero-demand complete, private access';
END $tests$;
ROLLBACK;