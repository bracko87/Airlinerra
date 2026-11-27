-- ROLLBACK-ONLY REVIEW. Stage dual-use storage profiles from the existing game
-- airport data, without modifying commercial rights, tariffs, fuel or slots.
-- Historical runway inputs remain game data, not real-world certified distances.
BEGIN;
CREATE FUNCTION airlinerra_game.stage_existing_commercial_storage_profiles_v1()
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE c record; s record; n integer:=0;v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR NOT isfinite(v_now) THEN RETURN jsonb_build_object('status','storage_profile_clock_unverified','staged',false);END IF;
 FOR c IN SELECT f.* FROM airlinerra_game.aircraft_storage_facilities_v1 f
 WHERE f.world_id=1 AND f.airport_key IN('OURAIRPORTS:26900','OURAIRPORTS:3856','OURAIRPORTS:4073')
 ORDER BY f.airport_key FOR UPDATE LOOP
  IF c.admission_scope IS DISTINCT FROM 'existing_commercial' OR c.review_state IS DISTINCT FROM 'candidate'
  OR c.monthly_regional_usd IS DISTINCT FROM 4000::numeric OR c.monthly_narrowbody_usd IS DISTINCT FROM 8000::numeric OR c.monthly_widebody_usd IS DISTINCT FROM 15000::numeric
  THEN RAISE EXCEPTION USING ERRCODE='PZ006',MESSAGE='storage_profile_candidate_changed';END IF;
  SELECT p.latitude_deg,p.longitude_deg,p.timezone_iana,w.length_m,w.width_m,w.surface_reported,w.source_runway_id,w.verification,
    t.landing_base_for_reference_aircraft_usd AS landing,t.departure_movement_fraction AS dep_fraction,t.price_model_version,
    cap.remote_stands,cap.remote_per_direction_10m,f.fuel_available
  INTO STRICT s
  FROM airlinerra_game.airport_unified_operations_v1 u
  JOIN airlinerra_game.airport_reference_profiles p ON p.world_id=u.world_id AND p.airport_key=u.airport_key
  JOIN LATERAL (SELECT x.* FROM airlinerra_game.airport_runway_inventory x WHERE x.world_id=u.world_id AND x.airport_key=u.airport_key ORDER BY x.length_m DESC NULLS LAST,x.source_runway_id LIMIT 1) w ON true
  JOIN airlinerra_game.section8_airport_operating_tariffs_v1 t ON t.world_id=u.world_id AND t.airport_key=u.airport_key
  JOIN airlinerra_game.section6_airport_slot_capacity_v1 cap ON cap.world_id=u.world_id AND cap.airport_key=u.airport_key
  JOIN airlinerra_game.airport_facilities f ON f.world_id=u.world_id AND f.airport_key=u.airport_key
  WHERE u.world_id=1 AND u.airport_key=c.airport_key AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission
  AND t.evidence_class='GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF';
  IF s.latitude_deg IS NULL OR s.longitude_deg IS NULL OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=s.timezone_iana)
   OR s.length_m IS NULL OR s.length_m<=0 OR s.width_m IS NULL OR s.width_m<=0
   OR s.surface_reported IS NULL OR upper(s.surface_reported) NOT IN('ASP','ASPHALT','CON','CONCRETE','ASPHALT/CONCRETE','CONCRETE/ASPHALT','BITUMEN')
   OR s.source_runway_id IS NULL OR s.landing IS NULL OR s.landing<0 OR s.dep_fraction IS NULL OR s.dep_fraction<0 OR s.dep_fraction>1
   OR s.remote_stands IS NULL OR s.remote_stands<=0 OR s.remote_per_direction_10m IS NULL OR s.remote_per_direction_10m<=0 OR s.fuel_available IS DISTINCT FROM true
  THEN RAISE EXCEPTION USING ERRCODE='PZ006',MESSAGE='storage_profile_source_incomplete';END IF;
  INSERT INTO airlinerra_game.aircraft_storage_airport_operational_profiles_v1(world_id,airport_key,latitude_deg,longitude_deg,timezone_iana,runway_length_m,runway_width_m,runway_surface,landing_fee_usd,departure_fee_usd,operating_restriction_reference,runway_evidence_reference,reviewed_at)
  VALUES(1,c.airport_key,s.latitude_deg,s.longitude_deg,s.timezone_iana,s.length_m,s.width_m,s.surface_reported,s.landing,round(s.landing*s.dep_fraction,2),
   'existing commercial game screens; tariff '||s.price_model_version,'existing game runway '||s.source_runway_id||'; '||coalesce(s.verification,'unknown'),v_now)
  ON CONFLICT(world_id,airport_key) DO NOTHING;
  -- Refuse to silently overwrite another review. Exact source fields must match.
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 p WHERE p.world_id=1 AND p.airport_key=c.airport_key
   AND p.latitude_deg=s.latitude_deg AND p.longitude_deg=s.longitude_deg AND p.timezone_iana=s.timezone_iana AND p.runway_length_m=s.length_m AND p.runway_width_m=s.width_m AND p.runway_surface=s.surface_reported AND p.landing_fee_usd=s.landing AND p.departure_fee_usd=round(s.landing*s.dep_fraction,2))
  THEN RAISE EXCEPTION USING ERRCODE='PZ006',MESSAGE='storage_profile_existing_review_conflict';END IF;
  n:=n+1;
 END LOOP;
 IF n<>3 THEN RAISE EXCEPTION USING ERRCODE='PZ006',MESSAGE='storage_profile_expected_three';END IF;
 RETURN jsonb_build_object('status','commercial_storage_profiles_staged','staged',true,'profileCount',n,'commercialRightsChanged',false,'storageAdmissionChanged',false,'dispatchAuthorized',false);
EXCEPTION WHEN SQLSTATE 'PZ006' OR no_data_found OR too_many_rows OR check_violation THEN
 RETURN jsonb_build_object('status','commercial_storage_profiles_rolled_back','staged',false,'profileCount',0,'commercialRightsChanged',false,'storageAdmissionChanged',false,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.stage_existing_commercial_storage_profiles_v1() FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
