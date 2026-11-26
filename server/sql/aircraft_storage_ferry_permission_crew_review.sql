-- ROLLBACK-ONLY REVIEW. Ferry permission and crew duty preflight.
-- No new purchasable licence, commercial route allocation or crew reservation.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_ferry_permissions_v1(
 world_id smallint NOT NULL CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 purpose text NOT NULL CHECK(purpose IN('storage_inbound','storage_reactivation')),
 origin_airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 destination_airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 valid_from_game_date date NOT NULL,valid_through_game_date date NOT NULL,
 approval_reference text NOT NULL CHECK(btrim(approval_reference)<>''),
 approved_at timestamptz NOT NULL,revoked_at timestamptz,
 PRIMARY KEY(world_id,airline_id,purpose,origin_airport_key,destination_airport_key,valid_from_game_date),
 CHECK(origin_airport_key<>destination_airport_key AND valid_through_game_date>=valid_from_game_date AND (revoked_at IS NULL OR revoked_at>=approved_at))
);
ALTER TABLE airlinerra_game.aircraft_storage_ferry_permissions_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_ferry_permissions_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.aircraft_storage_ferry_licence_screen_v1(p_airline uuid,p_purpose text,p_origin text,p_destination text,p_dep timestamptz,p_arr timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE f record; permission record; day1 date;day2 date;now_utc timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_purpose IS NULL OR p_purpose NOT IN('storage_inbound','storage_reactivation') OR p_origin IS NULL OR p_destination IS NULL OR p_origin=p_destination OR p_dep IS NULL OR p_arr IS NULL OR NOT isfinite(p_dep) OR NOT isfinite(p_arr) OR p_arr<=p_dep THEN RETURN jsonb_build_object('allowed',false,'decision','INVALID_STORAGE_FERRY');END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL THEN RETURN jsonb_build_object('allowed',false,'decision','STORAGE_CLOCK_UNVERIFIED');END IF;
 day1:=(p_dep AT TIME ZONE 'Europe/Berlin')::date;day2:=(p_arr AT TIME ZONE 'Europe/Berlin')::date;
 IF airlinerra_game.section9_canonical_aoc_covers_v1(p_airline,day1,day2-day1) IS DISTINCT FROM true THEN RETURN jsonb_build_object('allowed',false,'decision','VALID_LICENCE_1_REQUIRED');END IF;
 SELECT * INTO f FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=CASE WHEN p_purpose='storage_inbound' THEN p_destination ELSE p_origin END AND review_state='approved';
 IF NOT FOUND OR airlinerra_game.aircraft_storage_airport_admission_v1(f.airport_key,p_purpose)->>'eligible' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('allowed',false,'decision','STORAGE_FACILITY_NOT_APPROVED');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 WHERE world_id=1 AND airport_key=CASE WHEN p_purpose='storage_inbound' THEN p_origin ELSE p_destination END AND operationally_authorized AND dispatch_eligible_by_airport_admission) THEN RETURN jsonb_build_object('allowed',false,'decision','COMMERCIAL_ENDPOINT_NOT_AUTHORIZED');END IF;
 IF f.admission_scope='existing_commercial' THEN RETURN airlinerra_game.section9_game_route_licence_scope_v1(p_airline,p_origin,p_destination,day1,day2-day1);END IF;
 SELECT * INTO permission FROM airlinerra_game.aircraft_storage_ferry_permissions_v1
 WHERE world_id=1 AND airline_id=p_airline AND purpose=p_purpose AND origin_airport_key=p_origin AND destination_airport_key=p_destination
 AND valid_from_game_date<=day1 AND valid_through_game_date>=day2 AND approved_at<=now_utc AND revoked_at IS NULL
 ORDER BY valid_from_game_date DESC LIMIT 1;
 IF NOT FOUND THEN RETURN jsonb_build_object('allowed',false,'decision','STORAGE_FERRY_LICENCE_REVIEW_REQUIRED');END IF;
 RETURN jsonb_build_object('allowed',true,'decision','STORAGE_FERRY_PERMISSION_VERIFIED','permissionReference',permission.approval_reference,'commercialAuthorityGranted',false,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_ferry_licence_screen_v1(uuid,text,text,text,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.aircraft_storage_crew_requirements_v1(p_configuration bigint,p_origin text,p_destination text,p_dep timestamptz,p_arr timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE model record; rotation jsonb; pilots integer;now_utc timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO model FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=p_configuration;
 IF NOT FOUND OR nullif(btrim(model.qualification_group),'') IS NULL OR model.minimum_cabin_crew IS NULL OR model.minimum_cabin_crew<0 OR model.maximum_cabin_crew<model.minimum_cabin_crew THEN RETURN jsonb_build_object('allowed',false,'decision','STORAGE_CREW_MODEL_UNVERIFIED');END IF;
 rotation:=airlinerra_game.section9_crew_rotation_window_v2(jsonb_build_array(jsonb_build_object('originAirportKey',p_origin,'destinationAirportKey',p_destination,'departureUtc',p_dep,'arrivalUtc',p_arr)));
 IF rotation->>'status' IS DISTINCT FROM 'rotation_preview' THEN RETURN jsonb_build_object('allowed',false,'decision','STORAGE_CREW_DUTY_WINDOW_BLOCKED','rotation',rotation);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR (rotation->>'dutyStartUtc')::timestamptz<now_utc THEN RETURN jsonb_build_object('allowed',false,'decision','STORAGE_CREW_REPORTING_WINDOW_PASSED','rotation',rotation);END IF;
 pilots:=CASE WHEN p_arr-p_dep>interval '6 hours' THEN 4 ELSE 2 END;
 RETURN jsonb_build_object('allowed',false,'decision','STORAGE_FERRY_CREW_RESERVATION_REQUIRED','requirementsVerified',true,
 'qualificationGroup',model.qualification_group,'captainsRequired',pilots/2,'firstOfficersRequired',pilots/2,'pilotsRequired',pilots,
 'minimumCabinCrew',model.minimum_cabin_crew,'rotation',rotation,'crewReserved',false,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_crew_requirements_v1(bigint,text,text,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
