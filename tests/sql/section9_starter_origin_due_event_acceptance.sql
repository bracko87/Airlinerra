-- Regression: starter-aircraft location evidence, due-only candidate source,
-- and rejection of future-dated operated flight movements.
-- This test never activates flights or writes durable game records.
BEGIN;
DO $check$
DECLARE
 sample record; proof jsonb; missing jsonb; candidates jsonb;
 original_movements bigint; final_movements bigint;
BEGIN
 SELECT count(*) INTO original_movements
 FROM airlinerra_game.section9_operated_flight_movements_v1;

 SELECT airline_id,aircraft_inventory_id INTO sample
 FROM airlinerra_game.initial_aircraft_allocations_v1
 WHERE world_id=1 AND source_kind='original_airline_starter_allocation'
 LIMIT 1;

 IF FOUND THEN
  proof:=airlinerra_game.section9_starter_origin_evidence_v1(
    sample.airline_id,sample.aircraft_inventory_id,
    (clock_timestamp() AT TIME ZONE 'Europe/Berlin')::date);
  IF proof->>'verified' IS DISTINCT FROM 'true'
     OR proof->>'readOnly' IS DISTINCT FROM 'true'
     OR proof->>'notAnAcquisitionInspection' IS DISTINCT FROM 'true'
     OR proof->>'movementRecorded' IS DISTINCT FROM 'false'
  THEN RAISE EXCEPTION 'SECTION9_STARTER_ORIGIN_CONTRACT_FAILED';END IF;

  candidates:=airlinerra_game.section9_due_operation_candidates_v1(
    sample.airline_id,sample.aircraft_inventory_id,
    (clock_timestamp() AT TIME ZONE 'UTC')::date);
  IF candidates->>'readOnly' IS DISTINCT FROM 'true'
     OR candidates->>'movementRecorded' IS DISTINCT FROM 'false'
     OR candidates->>'requiresTrustedOperationDecision'
       IS DISTINCT FROM 'true'
     OR jsonb_typeof(candidates->'dueEvents') IS DISTINCT FROM 'array'
  THEN RAISE EXCEPTION 'SECTION9_DUE_EVENTS_CONTRACT_FAILED';END IF;
 END IF;

 missing:=airlinerra_game.section9_starter_origin_evidence_v1(
  '00000000-0000-4000-8000-000000000001'::uuid,
  '00000000-0000-4000-8000-000000000002'::uuid,
  (clock_timestamp() AT TIME ZONE 'Europe/Berlin')::date);
 IF missing->>'verified' IS DISTINCT FROM 'false'
    OR missing->>'movementRecorded' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION 'SECTION9_UNKNOWN_STARTER_IMPROPERLY_VERIFIED';END IF;

 BEGIN
  PERFORM airlinerra_game.section9_record_signed_operated_flight_movement_v1(
   '00000000-0000-4000-8000-000000000001'::uuid,
   '00000000-0000-4000-8000-000000000002'::uuid,
   1,(clock_timestamp() AT TIME ZONE 'UTC')::date,1,
   'departed',clock_timestamp()+interval '1 day',
   'future-operation-time-regression',repeat('a',64));
  RAISE EXCEPTION 'SECTION9_FUTURE_EVENT_NOT_BLOCKED';
 EXCEPTION WHEN insufficient_privilege THEN
  IF SQLERRM<>'SECTION9_FUTURE_OPERATED_MOVEMENT_FORBIDDEN'
  THEN RAISE;END IF;
 END;

 SELECT count(*) INTO final_movements
 FROM airlinerra_game.section9_operated_flight_movements_v1;
 IF final_movements<>original_movements
 THEN RAISE EXCEPTION 'SECTION9_TEST_CHANGED_MOVEMENTS';END IF;
END $check$;
ROLLBACK;
