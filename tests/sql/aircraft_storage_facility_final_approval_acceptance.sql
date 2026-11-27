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
