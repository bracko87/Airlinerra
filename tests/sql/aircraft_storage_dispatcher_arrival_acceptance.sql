-- Continue the actual dispatcher runtime fixture after its successful handoff departure.
-- Dependency writers remain synthetic; this checks dispatcher arrival control flow.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1() RETURNS jsonb LANGUAGE sql AS $$SELECT '{"authoritativeGameHourAvailable":true,"gameHourUtc":"2026-11-27T13:00:00Z"}'::jsonb$$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(uuid,uuid,date) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('status','verified_operational_candidates_only','candidates',jsonb_agg(jsonb_build_object('scheduleId',schedule_id,'scheduleVersion',schedule_version,'flightLocalDate',flight_local_date,'weeklyEntry',weekly_entry,'phase','arrived','scheduledEventUtc',arrival_utc,'eventId','SYNTHETIC-ARRIVAL-0001'))) FROM airlinerra_game.section9_dated_flight_occurrences_v1$$;
CREATE FUNCTION airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(text) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO airlinerra_game.test_dispatch_effects VALUES('usage');RETURN '{"status":"arrived_airframe_usage_recorded_once","usageApplied":true,"ledgerPosted":false}'::jsonb;END$$;
CREATE FUNCTION airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(text,text) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO airlinerra_game.test_dispatch_effects VALUES('burn');RETURN '{"status":"signed_game_arrival_fuel_burn_recorded_once","fuelBurnRecorded":true,"ledgerPosted":false}'::jsonb;END$$;
CREATE FUNCTION airlinerra_game.section9_complete_bound_crew_arrival_v1(uuid,text,text) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO airlinerra_game.test_dispatch_effects VALUES('crew_arrival');IF EXISTS(SELECT 1 FROM airlinerra_game.test_dispatch_mode WHERE mode='arrival_failed') THEN RETURN '{"status":"fixture_rejected","crewRosterBound":false}'::jsonb;END IF;RETURN '{"status":"pilot_experience_credited","crewRosterBound":true}'::jsonb;END$$;
CREATE FUNCTION airlinerra_game.section9_capture_actual_turnaround_v1(uuid,text,text) RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN INSERT INTO airlinerra_game.test_dispatch_effects VALUES('turnaround');RETURN '{"status":"fixture_turnaround_recorded"}'::jsonb;END$$;
DO $test$
DECLARE j jsonb;before_count int;
BEGIN
 IF current_database()<>'airlinerra_disposable' THEN RAISE EXCEPTION 'disposable database required';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE phase='departed')<>1 THEN RAISE EXCEPTION 'handoff departure fixture missing';END IF;
 INSERT INTO airlinerra_game.storage_commercial_departure_crew_evidence_v1 SELECT o.airline_id,m.flight_occurrence_id FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date||':'||o.weekly_entry WHERE m.phase='departed';
 UPDATE airlinerra_game.storage_commercial_binding_release_v1 SET enabled=false;
 UPDATE airlinerra_game.section9_delayed_crew_approval_release_v1 SET automatic_dispatch_event_isolation_enabled=true,automatic_normal_crew_enforcement_enabled=false;
 UPDATE airlinerra_game.test_dispatch_mode SET mode='arrival_failed';
 SELECT count(*) INTO before_count FROM airlinerra_game.test_dispatch_effects;
 j:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
 IF j->>'arrivalsRecorded' IS DISTINCT FROM '0' OR j#>>'{blockerCounts,SECTION9_NORMAL_CREW_ARRIVAL_ATOMIC_ROLLBACK}' IS DISTINCT FROM '1'
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>1 OR (SELECT count(*) FROM airlinerra_game.test_dispatch_effects)<>before_count THEN RAISE EXCEPTION 'storage arrival failure escaped rollback: %',j;END IF;
 RAISE NOTICE 'PASS actual dispatcher storage-bound arrival failure rolls back synthetic movement, fuel burn and crew effects';
 UPDATE airlinerra_game.test_dispatch_mode SET mode='arrival_ok';
 j:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
 IF j->>'arrivalsRecorded' IS DISTINCT FROM '1' OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE phase='arrived')<>1
 OR (SELECT count(*) FROM airlinerra_game.test_dispatch_effects)<>before_count+4
 OR (SELECT count(*) FROM airlinerra_game.test_dispatch_effects WHERE kind IN('usage','burn','crew_arrival','turnaround'))<>4 THEN RAISE EXCEPTION 'storage arrival continuity failed: %',j;END IF;
 j:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
 IF j->>'arrivalsRecorded' IS DISTINCT FROM '0' OR (SELECT count(*) FROM airlinerra_game.test_dispatch_effects)<>before_count+4 THEN RAISE EXCEPTION 'arrival replay duplicated effects: %',j;END IF;
 RAISE NOTICE 'PASS actual dispatcher storage-bound arrival after binding release disabled, with exactly-once synthetic effects';
END $test$;
