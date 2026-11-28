-- Synthetic calendar only. Existing Teruel profile staged by earlier tests.
SAVEPOINT service_availability;
DO $test$
DECLARE k text:='OURAIRPORTS:316427'; j jsonb; snap jsonb; op text; d int; t timestamptz;
BEGIN
 t:=airlinerra_game.section9_verified_world_instant_v1();
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_service_policy_missing' THEN RAISE EXCEPTION 'missing policy readiness bypass: %',j;END IF;
 IF airlinerra_game.aircraft_storage_leg_airport_screen_v1(k,1,'arrival','2026-11-26 10:00+00',true)->>'passed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'missing policy screen bypass';END IF;
 INSERT INTO airlinerra_game.storage_service_policy_v1 VALUES(1,k,'UTC','2026-11-01','2027-11-01','prior_permission_required','synthetic calendar only',t);
 IF airlinerra_game.storage_service_availability_v1(k,'arrival','2026-11-26 10:00+00')->>'status' IS DISTINCT FROM 'storage_service_prior_permission_required' THEN RAISE EXCEPTION 'permission bypass';END IF;
 UPDATE airlinerra_game.storage_service_policy_v1 SET access_mode='routine_game_access' WHERE airport_key=k;
 IF airlinerra_game.storage_service_policy_snapshot_v1(k)->>'status' IS DISTINCT FROM 'storage_service_windows_incomplete' THEN RAISE EXCEPTION 'empty calendar accepted';END IF;
 FOREACH op IN ARRAY ARRAY['departure','arrival'] LOOP
  FOR d IN 1..5 LOOP
   INSERT INTO airlinerra_game.storage_service_windows_v1 VALUES(1,k,op,d,'2026-11-01','2027-03-28',480,960),(1,k,op,d,'2027-03-28','2027-11-01',390,990);
  END LOOP;
 END LOOP;
 INSERT INTO airlinerra_game.storage_service_closures_v1 VALUES(1,k,'2026-11-27','synthetic holiday');
 IF airlinerra_game.storage_service_availability_v1(k,'arrival','2026-11-26 07:59:59+00')->>'passed' IS DISTINCT FROM 'false'
 OR airlinerra_game.storage_service_availability_v1(k,'arrival','2026-11-26 08:00+00')->>'passed' IS DISTINCT FROM 'true'
 OR airlinerra_game.storage_service_availability_v1(k,'departure','2026-11-26 15:59:59+00')->>'passed' IS DISTINCT FROM 'true'
 OR airlinerra_game.storage_service_availability_v1(k,'departure','2026-11-26 16:00+00')->>'passed' IS DISTINCT FROM 'false'
 OR airlinerra_game.storage_service_availability_v1(k,'arrival','2026-11-28 10:00+00')->>'status' IS DISTINCT FROM 'storage_service_outside_hours'
 OR airlinerra_game.storage_service_availability_v1(k,'arrival','2026-11-27 10:00+00')->>'status' IS DISTINCT FROM 'storage_service_date_closed'
 OR airlinerra_game.storage_service_availability_v1(k,'arrival','2027-06-01 06:30+00')->>'passed' IS DISTINCT FROM 'true'
 OR airlinerra_game.storage_service_availability_v1(k,'arrival','2027-06-01 06:29:59+00')->>'passed' IS DISTINCT FROM 'false'
 OR airlinerra_game.storage_service_availability_v1(k,'arrival','2027-11-01 10:00+00')->>'status' IS DISTINCT FROM 'storage_service_event_outside_review'
 THEN RAISE EXCEPTION 'service calendar boundary failure';END IF;
 IF airlinerra_game.aircraft_storage_leg_airport_screen_v1(k,1,'arrival','2026-11-28 10:00+00',true)->>'status' IS DISTINCT FROM 'storage_service_outside_hours'
 OR airlinerra_game.aircraft_storage_leg_airport_screen_v1(k,1,'departure','2026-11-26 16:00+00',true)->>'status' IS DISTINCT FROM 'storage_service_outside_hours'
 THEN RAISE EXCEPTION 'actual airport screen ignores calendar';END IF;
 snap:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
 IF snap->>'ready' IS DISTINCT FROM 'true' OR snap#>>'{servicePolicy,ready}' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'review snapshot missing calendar: %',snap;END IF;
 UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=true;
 INSERT INTO airlinerra_game.storage_facility_final_reviews_v1 VALUES(1,k,snap,'synthetic schedule review','synthetic fuel',t,NULL);
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'approved' IS DISTINCT FROM 'true' OR airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'eligible' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'calendar approval failed: %',j;END IF;
 INSERT INTO airlinerra_game.storage_service_closures_v1 VALUES(1,k,'2026-11-30','synthetic closure change');
 IF airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'reason' IS DISTINCT FROM 'FACILITY_FINAL_REVIEW_STALE' THEN RAISE EXCEPTION 'changed calendar did not invalidate admission';END IF;
 DELETE FROM airlinerra_game.storage_service_closures_v1 WHERE airport_key=k AND closed_date='2026-11-30';
 UPDATE airlinerra_game.storage_service_policy_v1 SET time_basis='airport_local' WHERE airport_key=k;
 IF airlinerra_game.storage_service_availability_v1(k,'arrival','2026-11-26 07:00+00')->>'passed' IS DISTINCT FROM 'true'
 OR airlinerra_game.storage_service_availability_v1(k,'arrival','2026-11-26 06:59:59+00')->>'passed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'airport local timezone handling incorrect';END IF;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_reactivation')->>'eligible' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'changed time basis not invalidated';END IF;
 RAISE NOTICE 'Storage service calendar acceptance passed: missing evidence, permission, seasonal hours, weekdays, holidays, exact boundaries, local timezone and stale approval';
END $test$;
ROLLBACK TO SAVEPOINT service_availability;
