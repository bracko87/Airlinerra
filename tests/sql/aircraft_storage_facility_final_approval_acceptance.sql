-- Disposable fixture: use the actual fuel service table definition.
CREATE TABLE airlinerra_game.aircraft_storage_fuel_services_v1(
 world_id smallint NOT NULL CHECK(world_id=1),
 airport_key text NOT NULL,
 fuel_game_family text NOT NULL CHECK(btrim(fuel_game_family)<>''),
 approval_reference text NOT NULL CHECK(btrim(approval_reference)<>''),
 PRIMARY KEY(world_id,airport_key,fuel_game_family),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_airport_operational_profiles_v1(world_id,airport_key)
);
ALTER TABLE airlinerra_game.aircraft_storage_fuel_services_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_fuel_services_v1 FROM PUBLIC,anon,authenticated,service_role;

SAVEPOINT original_facility_review;
DO $test$
DECLARE j jsonb;k text:='OURAIRPORTS:316427';commercial text:='OURAIRPORTS:26900';at_time timestamptz;
BEGIN
 at_time:=airlinerra_game.section9_verified_world_instant_v1();
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_facility_admission_not_released' THEN RAISE EXCEPTION 'admission release bypass: %',j;END IF;
 UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=true;
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_facility_final_review_missing' THEN RAISE EXCEPTION 'missing final review accepted: %',j;END IF;
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
 IF j->>'ready' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'staged profile not ready: %',j;END IF;
 INSERT INTO airlinerra_game.storage_facility_final_reviews_v1 VALUES(1,k,j,'synthetic final review','synthetic fuel review',at_time,NULL);
 UPDATE airlinerra_game.aircraft_storage_only_movement_limits_v1 SET movements_per_direction_hour=3 WHERE airport_key=k;
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_facility_final_review_stale' OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1) THEN RAISE EXCEPTION 'changed movement limits accepted: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_only_movement_limits_v1 SET movements_per_direction_hour=2 WHERE airport_key=k;
 UPDATE airlinerra_game.aircraft_storage_only_service_candidates_v1 SET fuel_evidence_status='provisional' WHERE airport_key=k;
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_facility_final_review_stale' OR j->>'readiness' IS DISTINCT FROM 'storage_facility_fuel_evidence_unverified' THEN RAISE EXCEPTION 'provisional fuel accepted: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_only_service_candidates_v1 SET fuel_evidence_status='listed' WHERE airport_key=k;
 INSERT INTO airlinerra_game.aircraft_storage_fuel_services_v1 VALUES(1,k,'TURBINE_KEROSENE_ASSUMED','conflicting fixture');
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_facility_approval_rolled_back' OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE airport_key=k AND review_state='approved') THEN RAISE EXCEPTION 'conflicting fuel approval accepted: %',j;END IF;
 DELETE FROM airlinerra_game.aircraft_storage_fuel_services_v1 WHERE airport_key=k;
 j:=airlinerra_game.approve_storage_facility_review_v1(k);
 IF j->>'approved' IS DISTINCT FROM 'true' OR j->>'dispatchAuthorized' IS DISTINCT FROM 'false'
 OR airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'eligible' IS DISTINCT FROM 'true'
 OR airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_reactivation')->>'eligible' IS DISTINCT FROM 'true'
 OR airlinerra_game.aircraft_storage_airport_admission_v1(k,'commercial')->>'eligible' IS DISTINCT FROM 'false'
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1 WHERE airport_key=k AND fuel_game_family='TURBINE_KEROSENE_ASSUMED' AND approval_reference='synthetic fuel review')
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 WHERE airport_key=k AND operationally_authorized)
 THEN RAISE EXCEPTION 'storage-only final approval failed: %',j;END IF;
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(commercial);
 IF j->>'ready' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'dual-use readiness failed: %',j;END IF;
 INSERT INTO airlinerra_game.storage_facility_final_reviews_v1 VALUES(1,commercial,j,'synthetic commercial storage review','reuse commercial fuel',at_time,NULL);
 j:=airlinerra_game.approve_storage_facility_review_v1(commercial);
 IF j->>'approved' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 WHERE airport_key=commercial AND operationally_authorized)
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1 WHERE airport_key=commercial)
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE review_state='approved')<>2
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE airport_key='OURAIRPORTS:2409' AND review_state<>'candidate')
 THEN RAISE EXCEPTION 'dual-use approval scope mismatch: %',j;END IF;
 RAISE NOTICE 'Storage facility final approval and fuel registration acceptance passed (synthetic Teruel and Alice Springs reviews)';
 -- Admission must be checked again on each search, quote and departure.
 UPDATE airlinerra_game.aircraft_storage_only_movement_limits_v1 SET movements_per_direction_hour=3 WHERE airport_key=k;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'reason' IS DISTINCT FROM 'FACILITY_FINAL_REVIEW_STALE' THEN RAISE EXCEPTION 'changed movement limit remains admitted';END IF;
 UPDATE airlinerra_game.aircraft_storage_only_movement_limits_v1 SET movements_per_direction_hour=2 WHERE airport_key=k;
 UPDATE airlinerra_game.aircraft_storage_fuel_services_v1 SET approval_reference='changed fixture' WHERE airport_key=k;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_reactivation')->>'reason' IS DISTINCT FROM 'FACILITY_FUEL_APPROVAL_MISSING' THEN RAISE EXCEPTION 'changed fuel approval remains admitted';END IF;
 UPDATE airlinerra_game.aircraft_storage_fuel_services_v1 SET approval_reference='synthetic fuel review' WHERE airport_key=k;
 UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=false;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'reason' IS DISTINCT FROM 'FACILITY_ADMISSION_NOT_RELEASED' THEN RAISE EXCEPTION 'disabled admission release ignored';END IF;
 UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=true;
 j:=airlinerra_game.revoke_storage_facility_review_v1(k,'wrong reference');
 IF j->>'revoked' IS DISTINCT FROM 'false' OR airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'eligible' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'wrong reference revoked approval: %',j;END IF;
 j:=airlinerra_game.revoke_storage_facility_review_v1(k,'synthetic final review');
 IF j->>'revoked' IS DISTINCT FROM 'true' OR j->>'historicalRecordsPreserved' IS DISTINCT FROM 'true'
 OR airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound')->>'eligible' IS DISTINCT FROM 'false'
 OR airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_reactivation')->>'eligible' IS DISTINCT FROM 'false'
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE airport_key=k AND review_state='approved' AND monthly_narrowbody_usd=8000)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1 WHERE airport_key=k)
 THEN RAISE EXCEPTION 'revocation failed or historical data destroyed: %',j;END IF;
 j:=airlinerra_game.revoke_storage_facility_review_v1(k,'synthetic final review');
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'revocation replay failed: %',j;END IF;
 j:=airlinerra_game.revoke_storage_facility_review_v1(commercial,'synthetic commercial storage review');
 IF j->>'revoked' IS DISTINCT FROM 'true' OR airlinerra_game.aircraft_storage_airport_admission_v1(commercial,'storage_inbound')->>'eligible' IS DISTINCT FROM 'false'
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 WHERE airport_key=commercial AND operationally_authorized)
 THEN RAISE EXCEPTION 'commercial rights changed on storage revocation: %',j;END IF;
 RAISE NOTICE 'Current storage admission and revocation acceptance passed; historical facility and commercial data preserved';

END $test$;

ROLLBACK TO SAVEPOINT original_facility_review;
-- Phase 1: each dual-use facility must obtain its own exact review before
-- admission. These are disposable audited-game-row fixtures, not live approvals.
DO $phase1$
DECLARE k text; j jsonb; a jsonb; snapshot jsonb; source_before jsonb; source_after jsonb;
 n integer:=0; t timestamptz; ref text;
BEGIN
 t:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT jsonb_build_array(
  (SELECT jsonb_agg(to_jsonb(u) ORDER BY airport_key) FROM airlinerra_game.airport_unified_operations_v1 u),
  (SELECT jsonb_agg(to_jsonb(u) ORDER BY airport_key) FROM airlinerra_game.section8_airport_operating_tariffs_v1 u),
  (SELECT jsonb_agg(to_jsonb(u) ORDER BY airport_key) FROM airlinerra_game.section6_airport_slot_capacity_v1 u),
  (SELECT jsonb_agg(to_jsonb(u) ORDER BY airport_key) FROM airlinerra_game.airport_facilities u)
 ) INTO source_before;
 UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=true;
 FOREACH k IN ARRAY ARRAY['OURAIRPORTS:26900','OURAIRPORTS:4073','OURAIRPORTS:3856'] LOOP
  j:=airlinerra_game.approve_storage_facility_review_v1(k);
  IF j->>'status' IS DISTINCT FROM 'storage_facility_final_review_missing' THEN RAISE EXCEPTION 'phase1 missing review bypass %: %',k,j;END IF;
  snapshot:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
  IF snapshot->>'ready' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'phase1 not ready %: %',k,snapshot;END IF;
  ref:='isolated phase1 fixture '||k;
  INSERT INTO airlinerra_game.storage_facility_final_reviews_v1 VALUES(1,k,snapshot,ref,'reuse existing game fuel',t,NULL);
  j:=airlinerra_game.approve_storage_facility_review_v1(k);
  IF j->>'approved' IS DISTINCT FROM 'true' OR j->>'dispatchAuthorized' IS DISTINCT FROM 'false' OR j->>'commercialAuthorityGranted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'phase1 approval %: %',k,j;END IF;
  FOREACH a IN ARRAY ARRAY[airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound'),airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_reactivation')] LOOP
   IF a->>'eligible' IS DISTINCT FROM 'true' OR a->>'storageCapacityUnlimited' IS DISTINCT FROM 'true' OR a->>'scope' IS DISTINCT FROM 'existing_commercial' THEN RAISE EXCEPTION 'phase1 admission %: %',k,a;END IF;
  END LOOP;
  n:=n+1;
  IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE review_state='approved')<>n THEN RAISE EXCEPTION 'phase1 unintended approval %',k;END IF;
  RAISE NOTICE 'Phase 1 individual storage admission passed: %',k;
 END LOOP;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1) THEN RAISE EXCEPTION 'phase1 duplicated commercial fuel';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 f WHERE f.airport_key NOT IN('OURAIRPORTS:26900','OURAIRPORTS:4073','OURAIRPORTS:3856') AND (f.review_state='approved' OR airlinerra_game.aircraft_storage_airport_admission_v1(f.airport_key,'storage_inbound')->>'eligible' IS DISTINCT FROM 'false')) THEN RAISE EXCEPTION 'phase1 other airport admitted';END IF;
 SELECT jsonb_build_array(
  (SELECT jsonb_agg(to_jsonb(u) ORDER BY airport_key) FROM airlinerra_game.airport_unified_operations_v1 u),
  (SELECT jsonb_agg(to_jsonb(u) ORDER BY airport_key) FROM airlinerra_game.section8_airport_operating_tariffs_v1 u),
  (SELECT jsonb_agg(to_jsonb(u) ORDER BY airport_key) FROM airlinerra_game.section6_airport_slot_capacity_v1 u),
  (SELECT jsonb_agg(to_jsonb(u) ORDER BY airport_key) FROM airlinerra_game.airport_facilities u)
 ) INTO source_after;
 IF source_before IS DISTINCT FROM source_after THEN RAISE EXCEPTION 'phase1 commercial source mutated';END IF;
 RAISE NOTICE 'Phase 1 all three individual approvals, unlimited storage, unchanged commercial data and isolated scope passed';
END $phase1$;
ROLLBACK TO SAVEPOINT original_facility_review;

-- Phase 2: exercise both dedicated storage airports without treating synthetic
-- operational inputs as verified real-world restrictions or granting live rights.
SAVEPOINT phase2_facility_review;
DO $phase2$
DECLARE k text; j jsonb; a jsonb; t timestamptz; n integer:=0; ref text;
BEGIN
 t:=airlinerra_game.section9_verified_world_instant_v1();
 k:='OURAIRPORTS:21315';
 j:=airlinerra_game.stage_storage_only_operational_profile_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_profile_review_required' THEN RAISE EXCEPTION 'Victorville unreviewed staging: %',j;END IF;
 INSERT INTO airlinerra_game.aircraft_storage_only_profile_reviews_v1 VALUES(1,k,3979,45.72,'CON',1.2,30,false,NULL,NULL,false,NULL,true,'synthetic runway','synthetic restrictions','synthetic access',t);
 j:=airlinerra_game.stage_storage_only_operational_profile_v1(k);
 IF j->>'status' IS DISTINCT FROM 'storage_profile_review_mismatch' THEN RAISE EXCEPTION 'Victorville overstated runway accepted: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_only_profile_reviews_v1 SET reviewed_runway_length_m=3978 WHERE airport_key=k;
 j:=airlinerra_game.stage_storage_only_operational_profile_v1(k);
 IF j->>'staged' IS DISTINCT FROM 'true' OR j->>'storageCapacityUnlimited' IS DISTINCT FROM 'true' OR j->>'storageAdmissionChanged' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Victorville staging: %',j;END IF;
 UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=true;
 FOREACH k IN ARRAY ARRAY['OURAIRPORTS:316427','OURAIRPORTS:21315'] LOOP
  j:=airlinerra_game.approve_storage_facility_review_v1(k);
  IF j->>'status' IS DISTINCT FROM 'storage_facility_final_review_missing' THEN RAISE EXCEPTION 'phase2 missing review bypass %: %',k,j;END IF;
  j:=airlinerra_game.storage_facility_readiness_snapshot_v1(k);
  IF j->>'ready' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'phase2 readiness %: %',k,j;END IF;
  ref:='synthetic phase2 '||k;
  INSERT INTO airlinerra_game.storage_facility_final_reviews_v1 VALUES(1,k,j,ref,ref||' fuel',t,NULL);
  j:=airlinerra_game.approve_storage_facility_review_v1(k);
  IF j->>'approved' IS DISTINCT FROM 'true' OR j->>'commercialAuthorityGranted' IS DISTINCT FROM 'false' OR j->>'dispatchAuthorized' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'phase2 approval %: %',k,j;END IF;
  FOREACH a IN ARRAY ARRAY[airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_inbound'),airlinerra_game.aircraft_storage_airport_admission_v1(k,'storage_reactivation')] LOOP
   IF a->>'eligible' IS DISTINCT FROM 'true' OR a->>'scope' IS DISTINCT FROM 'relocation_only' OR a->>'storageCapacityUnlimited' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'phase2 admission %: %',k,a;END IF;
  END LOOP;
  IF airlinerra_game.aircraft_storage_airport_admission_v1(k,'commercial')->>'eligible' IS DISTINCT FROM 'false'
  OR EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 WHERE airport_key=k AND operationally_authorized)
  OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1 WHERE airport_key=k AND fuel_game_family='TURBINE_KEROSENE_ASSUMED' AND approval_reference=ref||' fuel') THEN RAISE EXCEPTION 'phase2 scope/fuel %',k;END IF;
  n:=n+1;
  IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE review_state='approved')<>n THEN RAISE EXCEPTION 'phase2 unrelated facility approved';END IF;
  RAISE NOTICE 'Phase 2 individual storage-only admission passed: % (synthetic operational review)',k;
 END LOOP;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_fuel_services_v1)<>2 THEN RAISE EXCEPTION 'phase2 unexpected fuel scope';END IF;
 RAISE NOTICE 'Phase 2 both dedicated storage airports passed; no commercial rights or capacity quotas';
END $phase2$;
ROLLBACK TO SAVEPOINT phase2_facility_review;
