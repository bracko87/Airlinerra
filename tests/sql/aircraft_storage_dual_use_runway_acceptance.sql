-- Disposable audit fixture; no production runway status changes.
SAVEPOINT dual_use_runway;
ALTER TABLE airlinerra_game.airport_runway_inventory ADD COLUMN operational_status text DEFAULT 'unknown';
DO $test$
DECLARE k text:='OURAIRPORTS:4073'; j jsonb; t timestamptz;
BEGIN
 t:=airlinerra_game.section9_verified_world_instant_v1();
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_dual_use_runway_review_missing' THEN RAISE EXCEPTION 'missing dual-use runway review bypass: %',j;END IF;
 INSERT INTO airlinerra_game.storage_dual_use_runway_reviews_v1 VALUES(1,k,'235930',3000,2330,'synthetic conservative runway review',t);
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_dual_use_runway_unverified' THEN RAISE EXCEPTION 'unknown runway status bypass: %',j;END IF;
 UPDATE airlinerra_game.airport_runway_inventory SET operational_status='operational' WHERE airport_key=k;
 UPDATE airlinerra_game.storage_dual_use_runway_reviews_v1 SET landing_limit_m=3001 WHERE airport_key=k;
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_dual_use_runway_unverified' THEN RAISE EXCEPTION 'oversized declared runway accepted: %',j;END IF;
 UPDATE airlinerra_game.storage_dual_use_runway_reviews_v1 SET landing_limit_m=2330 WHERE airport_key=k;
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
 IF j->>'ready' IS DISTINCT FROM 'true' OR j#>>'{dualUseRunway,review,landing_limit_m}' IS DISTINCT FROM '2330' THEN RAISE EXCEPTION 'conservative review absent: %',j;END IF;
 UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=true;
 INSERT INTO airlinerra_game.storage_facility_final_reviews_v1 VALUES(1,k,j,'synthetic dual-use final review','reuse commercial fuel',t,NULL);
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'approved' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'reviewed airport not approved: %',j;END IF;
 UPDATE airlinerra_game.storage_dual_use_runway_reviews_v1 SET landing_limit_m=2329 WHERE airport_key=k;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'reason' IS DISTINCT FROM 'FACILITY_FINAL_REVIEW_STALE' THEN RAISE EXCEPTION 'changed limit not invalidated';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 WHERE airport_key=k AND operationally_authorized) THEN RAISE EXCEPTION 'commercial rights changed';END IF;
 RAISE NOTICE 'Dual-use runway review acceptance passed: missing evidence, unknown runway, excessive length and stale approval blocked';
END $test$;
ROLLBACK TO SAVEPOINT dual_use_runway;
RELEASE SAVEPOINT dual_use_runway;
