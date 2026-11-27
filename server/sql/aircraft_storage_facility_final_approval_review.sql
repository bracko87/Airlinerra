-- ROLLBACK-ONLY REVIEW. Candidate-to-approved facility transition.
-- Requires private per-facility review, no automatic commercial rights.
BEGIN;
CREATE TABLE airlinerra_game.storage_facility_admission_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.storage_facility_admission_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.storage_facility_final_reviews_v1(
 world_id smallint NOT NULL CHECK(world_id=1),airport_key text NOT NULL,
 reviewed_snapshot jsonb NOT NULL CHECK(jsonb_typeof(reviewed_snapshot)='object'),
 approval_reference text NOT NULL CHECK(btrim(approval_reference)<>''),
 fuel_review_reference text NOT NULL CHECK(btrim(fuel_review_reference)<>''),
 reviewed_at timestamptz NOT NULL,revoked_at timestamptz,
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key),
 CHECK(revoked_at IS NULL OR revoked_at>=reviewed_at)
);
ALTER TABLE airlinerra_game.storage_facility_admission_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.storage_facility_final_reviews_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_facility_admission_release_v1,airlinerra_game.storage_facility_final_reviews_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.storage_facility_readiness_snapshot_v1(p_airport text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE f record;p record;c record;s record;r record;l record;t record;now_utc timestamptz;scope_evidence jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR NOT isfinite(now_utc) THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_clock_unverified');END IF;
 SELECT * INTO f FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=p_airport;
 IF NOT FOUND OR f.review_state NOT IN('candidate','approved') OR f.monthly_regional_usd IS DISTINCT FROM 4000::numeric OR f.monthly_narrowbody_usd IS DISTINCT FROM 8000::numeric OR f.monthly_widebody_usd IS DISTINCT FROM 15000::numeric THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_price_or_state_invalid');END IF;
 SELECT * INTO c FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 WHERE world_id=1 AND airport_key=p_airport AND scope=f.admission_scope;
 IF NOT FOUND THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_not_in_reviewed_catalogue');END IF;
 SELECT * INTO p FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 WHERE world_id=1 AND airport_key=p_airport;
 IF NOT FOUND OR p.reviewed_at>now_utc OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p.timezone_iana) THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_profile_missing');END IF;
 IF f.admission_scope='existing_commercial' THEN
  SELECT to_jsonb(u) AS admission,to_jsonb(cap) AS slots,to_jsonb(tar) AS tariff,to_jsonb(ap) AS geography,fac.fuel_available,w.source_runway_id,w.length_m,w.width_m,w.surface_reported,w.verification,
   tar.landing_base_for_reference_aircraft_usd AS landing,tar.departure_movement_fraction AS fraction
  INTO s FROM airlinerra_game.airport_unified_operations_v1 u
  JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=u.world_id AND ap.airport_key=u.airport_key
  JOIN airlinerra_game.section6_airport_slot_capacity_v1 cap ON cap.world_id=u.world_id AND cap.airport_key=u.airport_key
  JOIN airlinerra_game.section8_airport_operating_tariffs_v1 tar ON tar.world_id=u.world_id AND tar.airport_key=u.airport_key
  JOIN airlinerra_game.airport_facilities fac ON fac.world_id=u.world_id AND fac.airport_key=u.airport_key
  JOIN LATERAL (SELECT x.* FROM airlinerra_game.airport_runway_inventory x WHERE x.world_id=u.world_id AND x.airport_key=u.airport_key ORDER BY x.length_m DESC NULLS LAST,x.source_runway_id LIMIT 1) w ON true
  WHERE u.world_id=1 AND u.airport_key=p_airport AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission
   AND cap.remote_stands>0 AND cap.remote_per_direction_10m>0 AND tar.evidence_class='GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF' AND fac.fuel_available IS TRUE
   AND ap.latitude_deg=p.latitude_deg AND ap.longitude_deg=p.longitude_deg AND ap.timezone_iana=p.timezone_iana;
  IF NOT FOUND OR s.length_m IS DISTINCT FROM p.runway_length_m OR s.width_m IS DISTINCT FROM p.runway_width_m OR s.surface_reported IS DISTINCT FROM p.runway_surface
   OR s.landing IS DISTINCT FROM p.landing_fee_usd OR round(s.landing*s.fraction,2) IS DISTINCT FROM p.departure_fee_usd
  THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_commercial_source_changed');END IF;
  scope_evidence:=to_jsonb(s);
 ELSE
  IF EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 WHERE world_id=1 AND airport_key=p_airport AND operationally_authorized) THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_scope_changed');END IF;
  SELECT * INTO s FROM airlinerra_game.aircraft_storage_only_service_candidates_v1 WHERE world_id=1 AND airport_key=p_airport;
  IF NOT FOUND OR s.fuel_evidence_status IS DISTINCT FROM 'listed' THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_fuel_evidence_unverified');END IF;
  SELECT * INTO r FROM airlinerra_game.aircraft_storage_only_profile_reviews_v1 WHERE world_id=1 AND airport_key=p_airport;
  IF NOT FOUND OR r.reviewed_at>now_utc OR r.reviewed_runway_length_m IS DISTINCT FROM p.runway_length_m OR r.reviewed_runway_width_m IS DISTINCT FROM p.runway_width_m OR r.reviewed_surface IS DISTINCT FROM p.runway_surface
  OR p.latitude_deg IS DISTINCT FROM c.latitude_deg OR p.longitude_deg IS DISTINCT FROM c.longitude_deg OR p.timezone_iana IS DISTINCT FROM c.timezone_iana
  OR r.reviewed_runway_length_m>coalesce(c.conservative_game_runway_m,c.physical_runway_m) OR c.physical_width_m IS NULL OR r.reviewed_runway_width_m>c.physical_width_m
  OR p.landing_fee_usd IS DISTINCT FROM c.proposed_landing_usd OR p.departure_fee_usd IS DISTINCT FROM round(c.proposed_landing_usd*c.proposed_departure_fraction,2)
  OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_only_airport_rules_v1 x WHERE x.world_id=1 AND x.airport_key=p_airport AND x.runway_elevation_factor=r.runway_elevation_factor AND x.minimum_usable_runway_width_m=r.minimum_usable_runway_width_m AND x.nighttime_ban=r.nighttime_ban AND x.curfew_start_local IS NOT DISTINCT FROM r.curfew_start_local AND x.curfew_end_local IS NOT DISTINCT FROM r.curfew_end_local AND x.noise_restrictions=r.noise_restrictions AND x.permitted_noise_chapters IS NOT DISTINCT FROM r.permitted_noise_chapters AND x.rule_reference=r.restriction_review_reference)
  THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_operating_review_changed');END IF;
  SELECT * INTO l FROM airlinerra_game.aircraft_storage_only_movement_limits_v1 WHERE world_id=1 AND airport_key=p_airport;
  IF NOT FOUND OR l.movements_per_direction_hour IS DISTINCT FROM s.proposed_movements_per_direction_hour OR l.movements_per_direction_10m IS DISTINCT FROM s.proposed_movements_per_direction_10m THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_movement_limits_changed');END IF;
  SELECT * INTO t FROM airlinerra_game.aircraft_storage_relocation_tariffs_v1 WHERE world_id=1 AND airport_key=p_airport;
  IF NOT FOUND OR t.remote_parking_per_day_usd IS DISTINCT FROM c.proposed_parking_daily_usd OR t.departure_ground_handling_usd IS DISTINCT FROM round(c.proposed_landing_usd*c.proposed_handling_fraction,2) OR t.terminal_navigation_usd IS DISTINCT FROM c.proposed_navigation_usd THEN RETURN jsonb_build_object('ready',false,'status','storage_facility_tariff_changed');END IF;
  scope_evidence:=jsonb_build_object('service',to_jsonb(s),'review',to_jsonb(r),'movement',to_jsonb(l),'tariff',to_jsonb(t));
 END IF;
 RETURN jsonb_build_object('ready',true,'status','storage_facility_review_ready','candidate',to_jsonb(c),'profile',to_jsonb(p),'scopeEvidence',scope_evidence,'commercialAuthorityGranted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_facility_readiness_snapshot_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.approve_storage_facility_review_v1(p_airport text)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE f record;r record;j jsonb;now_utc timestamptz;fuel_ref text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_facility_admission_release_v1 WHERE world_id=1 AND enabled) THEN RETURN jsonb_build_object('status','storage_facility_admission_not_released','approved',false);END IF;
 SELECT * INTO f FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=p_airport FOR UPDATE;
 IF NOT FOUND OR f.review_state IS DISTINCT FROM 'candidate' THEN RETURN jsonb_build_object('status','storage_facility_not_candidate','approved',false);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT * INTO r FROM airlinerra_game.storage_facility_final_reviews_v1 WHERE world_id=1 AND airport_key=p_airport FOR UPDATE;
 IF NOT FOUND OR now_utc IS NULL OR r.reviewed_at>now_utc OR r.revoked_at IS NOT NULL THEN RETURN jsonb_build_object('status','storage_facility_final_review_missing','approved',false);END IF;
 j:=airlinerra_game.storage_facility_readiness_snapshot_v1(p_airport);
 IF j->>'ready' IS DISTINCT FROM 'true' OR j IS DISTINCT FROM r.reviewed_snapshot THEN RETURN jsonb_build_object('status','storage_facility_final_review_stale','approved',false,'readiness',j->>'status');END IF;
 IF f.admission_scope='relocation_only' THEN
  -- Existing universal gameplay fuel family, not a real aircraft certification.
  fuel_ref:=r.fuel_review_reference;
  INSERT INTO airlinerra_game.aircraft_storage_fuel_services_v1(world_id,airport_key,fuel_game_family,approval_reference)
  VALUES(1,p_airport,'TURBINE_KEROSENE_ASSUMED',fuel_ref)
  ON CONFLICT(world_id,airport_key,fuel_game_family) DO NOTHING;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_fuel_services_v1 WHERE world_id=1 AND airport_key=p_airport AND fuel_game_family='TURBINE_KEROSENE_ASSUMED' AND approval_reference=fuel_ref) THEN RAISE EXCEPTION USING ERRCODE='PZ007';END IF;
 END IF;
 UPDATE airlinerra_game.aircraft_storage_facilities_v1 SET review_state='approved',reactivation_allowed=true,
 evidence_reference=r.approval_reference,relocation_release_reference=r.approval_reference,reviewed_at=now_utc WHERE world_id=1 AND airport_key=p_airport;
 RETURN jsonb_build_object('status','storage_facility_review_approved','approved',true,'airportKey',p_airport,'storageCapacityUnlimited',true,'commercialAuthorityGranted',false,'dispatchAuthorized',false);
EXCEPTION WHEN SQLSTATE 'PZ007' OR unique_violation OR check_violation OR foreign_key_violation THEN RETURN jsonb_build_object('status','storage_facility_approval_rolled_back','approved',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.approve_storage_facility_review_v1(text) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
