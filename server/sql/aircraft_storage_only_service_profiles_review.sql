-- ROLLBACK-ONLY REVIEW. Storage-only service evidence and proposed movement rules.
-- No airport approval, commercial rights, or actual fuel supplier authorization.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_only_service_candidates_v1(
 world_id smallint NOT NULL CHECK(world_id=1),airport_key text NOT NULL,
 published_jet_fuel text NOT NULL CHECK(published_jet_fuel IN('JET A','JET A-1')),
 fuel_evidence_status text NOT NULL CHECK(fuel_evidence_status IN('listed','provisional')),
 fuel_evidence_reference text NOT NULL CHECK(btrim(fuel_evidence_reference)<>''),
 access_review_note text NOT NULL CHECK(btrim(access_review_note)<>''),
 access_evidence_reference text NOT NULL CHECK(btrim(access_evidence_reference)<>''),
 proposed_movements_per_direction_hour int NOT NULL CHECK(proposed_movements_per_direction_hour>0),
 proposed_movements_per_direction_10m int NOT NULL CHECK(proposed_movements_per_direction_10m>0 AND proposed_movements_per_direction_10m<=proposed_movements_per_direction_hour),
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_airport_candidate_data_v1(world_id,airport_key)
);
ALTER TABLE airlinerra_game.aircraft_storage_only_service_candidates_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_only_service_candidates_v1 FROM PUBLIC,anon,authenticated,service_role;
-- Movement limits are conservative game proposals: two movements/hour in
-- each direction and one per ten-minute interval. They are not parking quotas,
-- measured airport capacity or an entitlement to operate.
INSERT INTO airlinerra_game.aircraft_storage_only_service_candidates_v1 VALUES
(1,'OURAIRPORTS:316427','JET A-1','listed','https://aeropuertodeteruel.com/en/flight-operations/charges-and-handling','Coordinate airport-approved movement and verify AIP restrictions.','https://aip.enaire.es/AIP/AIP-en.html',2,1),
(1,'OURAIRPORTS:20594','JET A','listed','https://www.airnav.com/airport/MZJ','Confirm airport access, handling and storage operator arrangement.','https://www.pinal.gov/1831/Pinal-Airpark',2,1),
(1,'OURAIRPORTS:20507','JET A','listed','https://www.airnav.com/airport/KMHV/A1','Coordinate special operations and runway availability; long-runway registry discrepancy remains.','https://www.mojaveairport.com/operations/page/special-operations',2,1),
(1,'OURAIRPORTS:21315','JET A','listed','https://airnav.com/airport/KVCV/MILLION_AIR','Public-use field; additional rescue coverage and international landing rights may need coordination.','https://www.victorvilleca.gov/Government/City-Departments/Airport/For-Pilots',2,1),
(1,'OURAIRPORTS:2395','JET A-1','listed','https://cotswoldairport.com/fuel-jet-a1-and-avgas/','Prior permission mandatory; published hours and declared distances require review.','https://cotswoldairport.com/pilot-briefing/',2,1),
(1,'OURAIRPORTS:2409','JET A-1','provisional','https://airfield.directory/airfield/EGSY','Confirm fuel directly, runway width and prior permission; existing registry GPS code EGSY, ident EGDX.','https://airfield.directory/airfield/EGSY',2,1);

-- Explicit reviewed game operational inputs, never silently assume zero
-- restrictions or a runway factor of 1. The proposed movement limits are
-- copied only after the reviewer accepts them for game use.
CREATE TABLE airlinerra_game.aircraft_storage_only_profile_reviews_v1(
 world_id smallint NOT NULL CHECK(world_id=1),airport_key text NOT NULL,
 reviewed_runway_length_m numeric NOT NULL CHECK(reviewed_runway_length_m>0),
 reviewed_runway_width_m numeric NOT NULL CHECK(reviewed_runway_width_m>0),
 reviewed_surface text NOT NULL CHECK(upper(reviewed_surface) IN('ASP','ASPHALT','CON','CONCRETE','ASPHALT/CONCRETE','CONCRETE/ASPHALT','BITUMEN')),
 runway_elevation_factor numeric NOT NULL CHECK(runway_elevation_factor>=1),
 minimum_usable_runway_width_m numeric NOT NULL CHECK(minimum_usable_runway_width_m>0 AND minimum_usable_runway_width_m<=reviewed_runway_width_m),
 nighttime_ban boolean NOT NULL,curfew_start_local time,curfew_end_local time,
 noise_restrictions boolean NOT NULL,permitted_noise_chapters smallint[],
 movement_limits_accepted boolean NOT NULL CHECK(movement_limits_accepted),
 runway_review_reference text NOT NULL CHECK(btrim(runway_review_reference)<>''),
 restriction_review_reference text NOT NULL CHECK(btrim(restriction_review_reference)<>''),
 access_review_reference text NOT NULL CHECK(btrim(access_review_reference)<>''),
 reviewed_at timestamptz NOT NULL,
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_only_service_candidates_v1(world_id,airport_key),
 CHECK((nighttime_ban AND curfew_start_local IS NOT NULL AND curfew_end_local IS NOT NULL AND curfew_start_local<>curfew_end_local) OR (NOT nighttime_ban AND curfew_start_local IS NULL AND curfew_end_local IS NULL)),
 CHECK((noise_restrictions AND permitted_noise_chapters IS NOT NULL AND cardinality(permitted_noise_chapters)>0 AND array_position(permitted_noise_chapters,NULL) IS NULL) OR (NOT noise_restrictions AND permitted_noise_chapters IS NULL))
);
ALTER TABLE airlinerra_game.aircraft_storage_only_profile_reviews_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_only_profile_reviews_v1 FROM PUBLIC,anon,authenticated,service_role;
-- Deliberately no seeded profile reviews: missing evidence cannot become
-- a passed review by default. Store a validated profile transactionally.
CREATE FUNCTION airlinerra_game.stage_storage_only_operational_profile_v1(p_airport text)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE f record;c record;r record;s record;v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL THEN RETURN jsonb_build_object('status','storage_profile_clock_unverified','staged',false);END IF;
 SELECT * INTO f FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=p_airport FOR UPDATE;
 IF NOT FOUND OR f.admission_scope IS DISTINCT FROM 'relocation_only' OR f.review_state IS DISTINCT FROM 'candidate' OR f.monthly_regional_usd IS DISTINCT FROM 4000::numeric OR f.monthly_narrowbody_usd IS DISTINCT FROM 8000::numeric OR f.monthly_widebody_usd IS DISTINCT FROM 15000::numeric THEN RETURN jsonb_build_object('status','storage_profile_candidate_invalid','staged',false);END IF;
 SELECT * INTO c FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1 WHERE world_id=1 AND airport_key=p_airport AND scope='relocation_only';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_profile_candidate_missing','staged',false);END IF;
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_only_service_candidates_v1 WHERE world_id=1 AND airport_key=p_airport;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_service_evidence_missing','staged',false);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_only_profile_reviews_v1 WHERE world_id=1 AND airport_key=p_airport;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_profile_review_required','staged',false);END IF;
 IF r.reviewed_at>v_now OR r.reviewed_runway_length_m>coalesce(c.conservative_game_runway_m,c.physical_runway_m)
 OR c.physical_width_m IS NULL OR r.reviewed_runway_width_m>c.physical_width_m OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=c.timezone_iana)
 THEN RETURN jsonb_build_object('status','storage_profile_review_mismatch','staged',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 WHERE world_id=1 AND airport_key=p_airport AND operationally_authorized) THEN RETURN jsonb_build_object('status','storage_profile_commercial_scope_changed','staged',false);END IF;
 BEGIN
 INSERT INTO airlinerra_game.aircraft_storage_airport_operational_profiles_v1 VALUES(1,p_airport,c.latitude_deg,c.longitude_deg,c.timezone_iana,r.reviewed_runway_length_m,r.reviewed_runway_width_m,r.reviewed_surface,c.proposed_landing_usd,round(c.proposed_landing_usd*c.proposed_departure_fraction,2),r.restriction_review_reference||' | '||r.access_review_reference,r.runway_review_reference,r.reviewed_at);
 INSERT INTO airlinerra_game.aircraft_storage_only_airport_rules_v1 VALUES(1,p_airport,r.runway_elevation_factor,r.minimum_usable_runway_width_m,r.nighttime_ban,r.curfew_start_local,r.curfew_end_local,r.noise_restrictions,r.permitted_noise_chapters,r.restriction_review_reference,r.reviewed_at);
 INSERT INTO airlinerra_game.aircraft_storage_relocation_tariffs_v1 VALUES(1,p_airport,c.proposed_parking_daily_usd,round(c.proposed_landing_usd*c.proposed_handling_fraction,2),c.proposed_navigation_usd,'storage-game-tariff-proposal-v1');
 INSERT INTO airlinerra_game.aircraft_storage_only_movement_limits_v1 VALUES(1,p_airport,s.proposed_movements_per_direction_hour,s.proposed_movements_per_direction_10m,'game movement limits | '||r.access_review_reference);
 EXCEPTION WHEN unique_violation OR check_violation OR foreign_key_violation THEN
  RETURN jsonb_build_object('status','storage_profile_staging_conflict','staged',false);
 END;
 RETURN jsonb_build_object('status','storage_only_profile_staged','staged',true,'airportKey',p_airport,'storageCapacityUnlimited',true,'storageAdmissionChanged',false,'commercialAuthorityGranted',false,'fuelSupplierAuthorized',false,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.stage_storage_only_operational_profile_v1(text) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
