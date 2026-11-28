-- ROLLBACK-ONLY REVIEW. Current admission requires an unrevoked exact review.
-- Do not delete facility or fuel rows: existing storage and signed movement
-- accounting depend on their historical identities. This is a new-flight gate.
BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.aircraft_storage_airport_admission_v1(p_airport text,p_purpose text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE f record;p record;r record;j jsonb;v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_purpose IS NULL OR p_purpose NOT IN ('storage_inbound','storage_reactivation') THEN RETURN jsonb_build_object('eligible',false,'reason','INVALID_STORAGE_PURPOSE');END IF;
 SELECT * INTO f FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=p_airport AND review_state='approved';
 IF NOT FOUND THEN RETURN jsonb_build_object('eligible',false,'reason','FACILITY_NOT_APPROVED');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_facility_admission_release_v1 WHERE world_id=1 AND enabled) THEN RETURN jsonb_build_object('eligible',false,'reason','FACILITY_ADMISSION_NOT_RELEASED');END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT * INTO r FROM airlinerra_game.storage_facility_final_reviews_v1 WHERE world_id=1 AND airport_key=p_airport;
 IF NOT FOUND OR v_now IS NULL OR NOT isfinite(v_now) OR r.reviewed_at>v_now OR r.revoked_at IS NOT NULL OR f.evidence_reference IS DISTINCT FROM r.approval_reference OR f.relocation_release_reference IS DISTINCT FROM r.approval_reference THEN RETURN jsonb_build_object('eligible',false,'reason','FACILITY_FINAL_REVIEW_INVALID');END IF;
 IF p_purpose='storage_reactivation' AND NOT f.reactivation_allowed THEN RETURN jsonb_build_object('eligible',false,'reason','REACTIVATION_NOT_APPROVED');END IF;
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(p_airport);
 IF j->>'ready' IS DISTINCT FROM 'true' OR j IS DISTINCT FROM r.reviewed_snapshot THEN RETURN jsonb_build_object('eligible',false,'reason','FACILITY_FINAL_REVIEW_STALE');END IF;
 IF f.admission_scope='relocation_only' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1 WHERE world_id=1 AND airport_key=p_airport AND fuel_game_family='TURBINE_KEROSENE_ASSUMED' AND approval_reference=r.fuel_review_reference) THEN RETURN jsonb_build_object('eligible',false,'reason','FACILITY_FUEL_APPROVAL_MISSING');END IF;
 SELECT * INTO p FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 WHERE world_id=1 AND airport_key=p_airport;
 IF NOT FOUND THEN RETURN jsonb_build_object('eligible',false,'reason','OPERATIONAL_PROFILE_MISSING');END IF;
 RETURN jsonb_build_object('eligible',true,'airportKey',p_airport,'purpose',p_purpose,'scope',f.admission_scope,'storageCapacityUnlimited',true,'commercialAuthorityGranted',false,'dispatchAuthorized',false,'profile',to_jsonb(p));
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_airport_admission_v1(text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.revoke_storage_facility_review_v1(p_airport text,p_expected_reference text)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=p_airport FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_facility_unknown','revoked',false);END IF;
 SELECT * INTO r FROM airlinerra_game.storage_facility_final_reviews_v1 WHERE world_id=1 AND airport_key=p_airport FOR UPDATE;
 IF NOT FOUND OR p_expected_reference IS NULL OR r.approval_reference IS DISTINCT FROM p_expected_reference THEN RETURN jsonb_build_object('status','storage_facility_revocation_conflict','revoked',false);END IF;
 IF r.revoked_at IS NOT NULL THEN RETURN jsonb_build_object('status','storage_facility_already_revoked','revoked',true,'replayed',true,'historicalRecordsPreserved',true);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR NOT isfinite(v_now) OR v_now<r.reviewed_at THEN RETURN jsonb_build_object('status','storage_facility_clock_unverified','revoked',false);END IF;
 UPDATE airlinerra_game.storage_facility_final_reviews_v1 SET revoked_at=v_now WHERE world_id=1 AND airport_key=p_airport;
 RETURN jsonb_build_object('status','storage_facility_review_revoked','revoked',true,'replayed',false,'historicalRecordsPreserved',true,'commercialRightsChanged',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.revoke_storage_facility_review_v1(text,text) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
