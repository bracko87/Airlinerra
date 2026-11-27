-- Synthetic PPR policy; no real-world clearance or airport approval.
SAVEPOINT permission_policy;
DO $test$
DECLARE k text:='OURAIRPORTS:316427'; j jsonb; t timestamptz; day_key date; dep timestamptz; op text; d int;
BEGIN
 t:=airlinerra_game.section9_verified_world_instant_v1();
 day_key:=(t AT TIME ZONE 'UTC')::date;
 dep:=t+interval '3 hours';
 INSERT INTO airlinerra_game.storage_service_policy_v1 VALUES(1,k,'UTC',day_key-1,day_key+10,'prior_permission_required','synthetic PPR',t);
 FOREACH op IN ARRAY ARRAY['departure','arrival'] LOOP
  FOR d IN 1..7 LOOP
   INSERT INTO airlinerra_game.storage_service_windows_v1 VALUES(1,k,op,d,day_key-1,day_key+10,0,1440);
  END LOOP;
 END LOOP;
 IF airlinerra_game.storage_service_policy_snapshot_v1(k)->>'ready' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'missing policy accepted';END IF;
 INSERT INTO airlinerra_game.storage_game_permission_policy_v1 VALUES(1,k,true,120,'synthetic access','synthetic sponsor',t);
 IF airlinerra_game.storage_service_policy_snapshot_v1(k)->>'ready' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'disabled release bypass';END IF;
 UPDATE airlinerra_game.storage_game_permission_release_v1 SET enabled=true;
 j:=airlinerra_game.storage_game_permission_candidate_v1(k,'departure',t+interval '119 minutes',t+interval '119 minutes',t);
 IF j->>'status' IS DISTINCT FROM 'storage_permission_notice_insufficient' THEN RAISE EXCEPTION 'short notice accepted: %',j;END IF;
 j:=airlinerra_game.storage_game_permission_candidate_v1(k,'departure',t+interval '120 minutes',t+interval '120 minutes',t);
 IF j->>'passed' IS DISTINCT FROM 'true' OR j->>'permissionRequired' IS DISTINCT FROM 'true' OR j->>'dispatchAuthorized' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'exact notice not accepted: %',j;END IF;
 j:=airlinerra_game.storage_game_permission_candidate_v1(k,'arrival',dep+interval '1 hour',dep,t);
 IF j->>'passed' IS DISTINCT FROM 'true' OR j#>>'{reviewSnapshot,permissionPolicy,sponsor_game_policy_reference}' IS DISTINCT FROM 'synthetic sponsor' THEN RAISE EXCEPTION 'arrival permission review missing: %',j;END IF;
 IF airlinerra_game.storage_game_permission_candidate_v1(k,'arrival',dep,dep+interval '1 hour',t)->>'passed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'invalid flight chronology accepted';END IF;
 IF airlinerra_game.storage_game_permission_candidate_v1(k,'departure',dep,dep,t+interval '1 second')->>'passed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'future review time accepted';END IF;
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
 IF j->>'ready' IS DISTINCT FROM 'true' OR j#>>'{servicePolicy,permissionPolicy,minimum_notice_minutes}' IS DISTINCT FROM '120' THEN RAISE EXCEPTION 'PPR policy not bound to facility snapshot: %',j;END IF;
 UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=true;
 INSERT INTO airlinerra_game.storage_facility_final_reviews_v1 VALUES(1,k,j,'synthetic permission final review','synthetic fuel',t,NULL);
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'approved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'PPR facility approval failed: %',j;END IF;
 UPDATE airlinerra_game.storage_game_permission_policy_v1 SET minimum_notice_minutes=180 WHERE airport_key=k;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'reason' IS DISTINCT FROM 'FACILITY_FINAL_REVIEW_STALE' THEN RAISE EXCEPTION 'modified notice did not invalidate approval';END IF;
 UPDATE airlinerra_game.storage_game_permission_policy_v1 SET minimum_notice_minutes=120 WHERE airport_key=k;
 INSERT INTO airlinerra_game.storage_service_closures_v1 VALUES(1,k,(dep AT TIME ZONE 'UTC')::date,'synthetic closure');
 IF airlinerra_game.storage_game_permission_candidate_v1(k,'departure',dep,dep,t)->>'status' IS DISTINCT FROM 'storage_service_date_closed' THEN RAISE EXCEPTION 'permission overrides closure';END IF;
 RAISE NOTICE 'Game PPR policy acceptance passed: missing or disabled review, exact notice, chronology, sponsor evidence, changed policy and closure';
END $test$;
ROLLBACK TO SAVEPOINT permission_policy;
