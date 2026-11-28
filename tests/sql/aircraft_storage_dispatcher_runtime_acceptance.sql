-- Actual dispatcher control flow with explicitly synthetic dependency writers.
DO $test$
DECLARE mode_key text;j jsonb;n int;binding_kind text;
BEGIN
 IF current_database()<>'airlinerra_disposable' THEN RAISE EXCEPTION 'disposable database required';END IF;
 FOREACH mode_key IN ARRAY ARRAY['ordinary','custody','delayed','downstream','no_atomic','binding_failed','handoff'] LOOP
  TRUNCATE airlinerra_game.section9_operated_flight_movements_v1,airlinerra_game.test_dispatch_effects,airlinerra_game.section9_delayed_crew_approvals_v1;
  UPDATE airlinerra_game.section9_dated_flight_occurrences_v1 SET booking_status='open';
  UPDATE airlinerra_game.test_dispatch_mode SET mode=mode_key;
  UPDATE airlinerra_game.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=(mode_key<>'no_atomic');
  IF mode_key='delayed' THEN
   INSERT INTO airlinerra_game.section9_delayed_crew_approvals_v1 SELECT id,airline_id FROM airlinerra_game.section9_dated_flight_occurrences_v1;
  END IF;
  j:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
  IF j->>'candidatesChecked' IS DISTINCT FROM '1' THEN RAISE EXCEPTION 'candidate not exercised: % %',mode_key,j;END IF;
  SELECT count(*) INTO n FROM airlinerra_game.section9_operated_flight_movements_v1;
  IF mode_key IN('ordinary','handoff') THEN
   binding_kind:=CASE WHEN mode_key='ordinary' THEN 'legacy' ELSE 'storage' END;
   IF j->>'departuresRecorded' IS DISTINCT FROM '1' OR n<>1
    OR (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1)<>'closed'
    OR (SELECT count(*) FROM airlinerra_game.test_dispatch_effects WHERE kind=binding_kind)<>1
    OR (SELECT count(*) FROM airlinerra_game.test_dispatch_effects)<>3
   THEN RAISE EXCEPTION 'successful dispatcher case failed: % %',mode_key,j;END IF;
   j:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
   IF j->>'departuresRecorded' IS DISTINCT FROM '0' OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>1 THEN RAISE EXCEPTION 'departure replay duplicated: %',j;END IF;
  ELSE
   IF j->>'departuresRecorded' IS DISTINCT FROM '0' OR j->>'blocked' IS DISTINCT FROM '1' OR n<>0
    OR (SELECT booking_status FROM airlinerra_game.section9_dated_flight_occurrences_v1)<>'open'
    OR EXISTS(SELECT 1 FROM airlinerra_game.test_dispatch_effects WHERE kind IN('legacy','storage','receipt'))
    OR (mode_key<>'no_atomic' AND EXISTS(SELECT 1 FROM airlinerra_game.test_dispatch_effects))
   THEN RAISE EXCEPTION 'blocked dispatcher case escaped rollback: % %',mode_key,j;END IF;
   IF mode_key IN('delayed','downstream','no_atomic') AND j#>>'{blockerCounts,STORAGE_HANDOFF_REQUIRES_EXCLUSIVE_ATOMIC_BINDING}' IS DISTINCT FROM '1' THEN RAISE EXCEPTION 'exclusive binding conflict not reported: %',j;END IF;
   IF mode_key='custody' AND j#>>'{blockerCounts,STORAGE_COMMERCIAL_CREW_CUSTODY_CONFLICT}' IS DISTINCT FROM '1' THEN RAISE EXCEPTION 'custody conflict not reported: %',j;END IF;
   IF mode_key='binding_failed' AND j#>>'{blockerCounts,DISPATCH_EVENT_ATOMIC_ROLLBACK_23514}' IS DISTINCT FROM '1' THEN RAISE EXCEPTION 'binding rollback not reported: %',j;END IF;
  END IF;
  RAISE NOTICE 'PASS actual dispatcher runtime branch % with synthetic dependency writers',mode_key;
 END LOOP;
END $test$;
