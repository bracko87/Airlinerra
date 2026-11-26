-- REVIEW ONLY. Purpose-scoped admission foundation; not a dispatch release.
-- No writes to commercial airport catalogue or passenger/cargo demand.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_airport_operational_profiles_v1 (
 world_id smallint NOT NULL CHECK(world_id=1),
 airport_key text NOT NULL,
 latitude_deg numeric NOT NULL CHECK(latitude_deg BETWEEN -90 AND 90),
 longitude_deg numeric NOT NULL CHECK(longitude_deg BETWEEN -180 AND 180),
 timezone_iana text NOT NULL CHECK(btrim(timezone_iana)<>''),
 runway_length_m numeric NOT NULL CHECK(runway_length_m>0),
 runway_width_m numeric NOT NULL CHECK(runway_width_m>0),
 runway_surface text NOT NULL CHECK(btrim(runway_surface)<>''),
 landing_fee_usd numeric(14,2) NOT NULL CHECK(landing_fee_usd>=0),
 departure_fee_usd numeric(14,2) NOT NULL CHECK(departure_fee_usd>=0),
 operating_restriction_reference text NOT NULL CHECK(btrim(operating_restriction_reference)<>''),
 runway_evidence_reference text NOT NULL CHECK(btrim(runway_evidence_reference)<>''),
 reviewed_at timestamptz NOT NULL,
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key)
);
ALTER TABLE airlinerra_game.aircraft_storage_airport_operational_profiles_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_airport_operational_profiles_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.aircraft_storage_airport_admission_v1(p_airport text,p_purpose text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE f record; p record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 -- This function cannot authorize a commercial movement, even at a
 -- dual-use airport. Commercial movements retain their own existing gate.
 IF p_purpose IS NULL OR p_purpose NOT IN ('storage_inbound','storage_reactivation') THEN
 RETURN jsonb_build_object('eligible',false,'reason','INVALID_STORAGE_PURPOSE');END IF;
 SELECT * INTO f FROM airlinerra_game.aircraft_storage_facilities_v1
 WHERE world_id=1 AND airport_key=p_airport AND review_state='approved';
 IF NOT FOUND THEN RETURN jsonb_build_object('eligible',false,'reason','FACILITY_NOT_APPROVED');END IF;
 IF p_purpose='storage_reactivation' AND NOT f.reactivation_allowed THEN
 RETURN jsonb_build_object('eligible',false,'reason','REACTIVATION_NOT_APPROVED');END IF;
 SELECT * INTO p FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1
 WHERE world_id=1 AND airport_key=p_airport;
 IF NOT FOUND THEN RETURN jsonb_build_object('eligible',false,'reason','OPERATIONAL_PROFILE_MISSING');END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p.timezone_iana) THEN
 RETURN jsonb_build_object('eligible',false,'reason','TIMEZONE_INVALID');END IF;
 RETURN jsonb_build_object('eligible',true,'airportKey',p_airport,'purpose',p_purpose,
 'scope',f.admission_scope,'storageCapacityUnlimited',true,'commercialAuthorityGranted',false,
 'dispatchAuthorized',false,'profile',to_jsonb(p));
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_airport_admission_v1(text,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
