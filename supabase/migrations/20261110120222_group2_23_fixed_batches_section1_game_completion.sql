-- Section1 Group2 game-data closure: 1118 airports in 23 immutable batches.
-- Mirrors Group1 game_complete_estimated, NOT independent source certification.
DO $preflight$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_source_research_queue_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_cases_v1)<>50
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1)<>5
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION1_GAME_PREFLIGHT_CHANGED';END IF;
END $preflight$;

CREATE TABLE airlinerra_game.airport_group2_fixed_batch_members_v1 (
 airport_key text PRIMARY KEY REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 batch_number smallint NOT NULL CHECK(batch_number BETWEEN 1 AND 23),
 case_number smallint NOT NULL CHECK(case_number BETWEEN 1 AND 50),
 original_research_priority smallint NOT NULL CHECK(original_research_priority BETWEEN 0 AND 4),
 snapshot_review_sequence integer NOT NULL UNIQUE,
 assigned_on date NOT NULL DEFAULT DATE '2026-11-10',
 UNIQUE(batch_number,case_number)
);
ALTER TABLE airlinerra_game.airport_group2_fixed_batch_members_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_fixed_batch_members_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_fixed_batch_members_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_fixed_batch_members_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
COMMENT ON TABLE airlinerra_game.airport_group2_fixed_batch_members_v1 IS
 'Immutable Group2 batch membership: first 22 groups contain 50, final batch23 has 18. Existing Batch1 case numbers preserved. Used for later Sections2-8 as well.';

INSERT INTO airlinerra_game.airport_group2_fixed_batch_members_v1
(airport_key,batch_number,case_number,original_research_priority,snapshot_review_sequence)
SELECT airport_key,review_batch_50,((cohort_review_order-1)%50+1)::smallint,
 priority_tier,review_sequence
FROM airlinerra_game.airport_group2_source_research_queue_v1;

-- Five Australian state civil-time discrepancies: game profile read model
-- only. Immutable source approximations and flight release gates unchanged.
CREATE TABLE airlinerra_game.airport_group2_section1_game_timezone_overrides_v1 (
 airport_key text PRIMARY KEY REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 original_game_timezone_iana text NOT NULL,
 resolved_game_timezone_iana text NOT NULL,
 game_basis text NOT NULL DEFAULT 'AU_STATE_TIME_RULE_GAME_CORRECTION'
  CHECK(game_basis='AU_STATE_TIME_RULE_GAME_CORRECTION'),
 government_source_url text NOT NULL CHECK(government_source_url LIKE 'https://%'),
 applied_to_section1_game_model_on date NOT NULL DEFAULT DATE '2026-11-10',
 independently_airport_verified boolean NOT NULL DEFAULT false CHECK(independently_airport_verified=false),
 allowed_for_live_flights boolean NOT NULL DEFAULT false CHECK(allowed_for_live_flights=false),
 CHECK(original_game_timezone_iana<>resolved_game_timezone_iana)
);
ALTER TABLE airlinerra_game.airport_group2_section1_game_timezone_overrides_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section1_game_timezone_overrides_v1
 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section1_game_timezone_overrides_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section1_game_timezone_overrides_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
INSERT INTO airlinerra_game.airport_group2_section1_game_timezone_overrides_v1
 (airport_key,original_game_timezone_iana,resolved_game_timezone_iana,government_source_url)
SELECT airport_key,source_game_timezone_iana,authority_expected_timezone_iana,
 'https://www.rba.gov.au/schedules-events/daylight-saving.html'
FROM airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1;

CREATE VIEW airlinerra_game.airport_group2_section1_game_registry_v1
 WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,g.airport_key,g.game_airport_name,
 g.owner_category AS game_category,g.game_traffic_type,
 g.country_iso,g.region_code,g.latitude_deg,g.longitude_deg,
 g.source_ident AS original_source_ident,g.source_gps_code,
 g.game_lookup_code AS game_navigation_code,
 coalesce(nullif(btrim(g.source_municipality),''),
   city.proposed_value,nullif(btrim(g.game_locality_display),''),
   g.game_airport_name) AS game_locality_label,
 CASE
 WHEN nullif(btrim(g.source_municipality),'') IS NOT NULL
  THEN 'ORIGINAL_REGISTRY_LOCALITY_UNVERIFIED'
 WHEN city.proposed_value IS NOT NULL
  THEN 'OFFICIAL_OPERATOR_SERVED_CITY_CANDIDATE_UNVERIFIED'
 ELSE 'AIRPORT_NAME_GAME_FALLBACK_NOT_REAL_MUNICIPALITY'
 END AS game_locality_basis,
 (nullif(btrim(g.source_municipality),'') IS NULL) AS source_municipality_missing,
 (nullif(btrim(g.source_gps_code),'') IS NULL) AS source_gps_code_missing,
 coalesce(t.resolved_game_timezone_iana,g.timezone_iana) AS game_timezone_iana,
 CASE WHEN t.airport_key IS NOT NULL THEN t.game_basis ELSE g.timezone_game_basis
 END AS game_timezone_basis,
 (t.airport_key IS NOT NULL) AS state_rule_game_timezone_corrected,
 g.game_elevation_ft,g.elevation_game_basis,
 (g.elevation_game_basis='UNSOURCED_GAME_ZERO_FALLBACK') AS zero_elevation_fallback,
 (nullif(btrim(g.game_airport_name),'') IS NOT NULL
  AND g.country_iso ~ '^[A-Z]{2}$'
  AND g.latitude_deg BETWEEN -90 AND 90
  AND g.longitude_deg BETWEEN -180 AND 180
  AND nullif(btrim(g.game_lookup_code),'') IS NOT NULL
  AND nullif(btrim(coalesce(nullif(btrim(g.source_municipality),''),
    city.proposed_value,g.game_locality_display,g.game_airport_name)),'') IS NOT NULL
  AND coalesce(t.resolved_game_timezone_iana,g.timezone_iana) IS NOT NULL
  AND EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names tz
    WHERE tz.name=coalesce(t.resolved_game_timezone_iana,g.timezone_iana))
  AND g.game_elevation_ft IS NOT NULL) AS section1_game_data_complete,
 false AS independently_source_verified,
 false AS commercially_admitted,
 false AS live_flight_authorized
FROM airlinerra_game.airport_group2_game_profiles_v1 g
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key)
LEFT JOIN airlinerra_game.airport_group2_section1_game_timezone_overrides_v1 t
 USING(airport_key)
LEFT JOIN LATERAL (
 SELECT s.proposed_value
 FROM airlinerra_game.airport_group2_section1_source_candidates_v1 s
 WHERE s.airport_key=g.airport_key AND s.identity_field='served_city'
 AND s.source_kind IN('OFFICIAL_AIRPORT_OPERATOR','OFFICIAL_AUTHORITY')
 AND s.review_status='PRIMARY_SOURCE_CANDIDATE_NEEDS_INDEPENDENT_REVIEW'
 ORDER BY s.candidate_id DESC LIMIT 1
) city ON true;
REVOKE ALL ON airlinerra_game.airport_group2_section1_game_registry_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.airport_group2_section1_game_registry_v1 IS
 'Complete game-data model for Group2. Missing real sources: 41 municipalities, 2 GPS, 11 zero-elevation game fallbacks. 24 served-city candidates NOT verified, 17 airport-label fallbacks. None of these grant commercial airport/airline rights.';

-- Ensure existing Section1 game interface reads the corrected game timezone,
-- while keeping exact column order and source municipality unchanged.
CREATE OR REPLACE VIEW airlinerra_game.airport_group2_section1_identity_v1
 WITH (security_invoker=true) AS
SELECT g.airport_key,g.game_airport_name,g.source_municipality,
 g.game_locality_display,g.country_iso,g.region_code,g.source_ident,
 g.source_gps_code,g.game_lookup_code,g.latitude_deg,g.longitude_deg,
 coalesce(t.resolved_game_timezone_iana,g.timezone_iana) AS timezone_iana,
 CASE WHEN t.airport_key IS NOT NULL THEN t.game_basis ELSE g.timezone_game_basis
 END AS timezone_game_basis,
 g.timezone_neighbor_distance_km,g.game_elevation_ft,g.elevation_game_basis,
 g.owner_category AS game_category,g.commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1 g
LEFT JOIN airlinerra_game.airport_group2_section1_game_timezone_overrides_v1 t
 USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section1_identity_v1
 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section1_batch_completion_v1
 WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER(WHERE section1_game_data_complete)::integer AS game_complete,
 count(*) FILTER(WHERE source_municipality_missing)::integer AS source_municipality_missing,
 count(*) FILTER(WHERE game_locality_basis='OFFICIAL_OPERATOR_SERVED_CITY_CANDIDATE_UNVERIFIED')::integer AS unverified_official_city_candidates,
 count(*) FILTER(WHERE game_locality_basis='AIRPORT_NAME_GAME_FALLBACK_NOT_REAL_MUNICIPALITY')::integer AS airport_name_fallbacks,
 count(*) FILTER(WHERE source_gps_code_missing)::integer AS missing_source_gps,
 count(*) FILTER(WHERE state_rule_game_timezone_corrected)::integer AS corrected_game_timezones,
 count(*) FILTER(WHERE zero_elevation_fallback)::integer AS zero_elevation_game_fallbacks,
 CASE WHEN count(*)=count(*) FILTER(WHERE section1_game_data_complete)
  THEN 'game_complete_estimated' ELSE 'game_incomplete' END AS game_data_result,
 false AS independent_source_verification_complete,
 false AS live_airport_operations_enabled
FROM airlinerra_game.airport_group2_section1_game_registry_v1
GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section1_batch_completion_v1
 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.airport_group2_section1_batch_acceptance_v1 (
 batch_number smallint PRIMARY KEY CHECK(batch_number BETWEEN 1 AND 23),
 airports integer NOT NULL CHECK(airports BETWEEN 1 AND 50),
 complete_game_profiles integer NOT NULL CHECK(complete_game_profiles=airports),
 game_data_result text NOT NULL DEFAULT 'game_complete_estimated'
   CHECK(game_data_result='game_complete_estimated'),
 original_source_municipalities_missing integer NOT NULL CHECK(original_source_municipalities_missing>=0),
 game_airport_name_locality_fallbacks integer NOT NULL CHECK(game_airport_name_locality_fallbacks>=0),
 original_gps_codes_missing integer NOT NULL CHECK(original_gps_codes_missing>=0),
 game_timezones_corrected integer NOT NULL CHECK(game_timezones_corrected>=0),
 zero_elevation_fallbacks integer NOT NULL CHECK(zero_elevation_fallbacks>=0),
 independently_source_verified boolean NOT NULL DEFAULT false CHECK(independently_source_verified=false),
 operationally_authorized boolean NOT NULL DEFAULT false CHECK(operationally_authorized=false),
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10'
);
ALTER TABLE airlinerra_game.airport_group2_section1_batch_acceptance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section1_batch_acceptance_v1
 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section1_batch_acceptance_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section1_batch_acceptance_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
INSERT INTO airlinerra_game.airport_group2_section1_batch_acceptance_v1
(batch_number,airports,complete_game_profiles,original_source_municipalities_missing,
 game_airport_name_locality_fallbacks,original_gps_codes_missing,
 game_timezones_corrected,zero_elevation_fallbacks)
SELECT batch_number,airports,game_complete,source_municipality_missing,
 airport_name_fallbacks,missing_source_gps,corrected_game_timezones,zero_elevation_game_fallbacks
FROM airlinerra_game.airport_group2_section1_batch_completion_v1
WHERE game_data_result='game_complete_estimated';

CREATE VIEW airlinerra_game.airport_group2_section1_overall_status_v1
 WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(complete_game_profiles),0)::integer AS game_complete_airports,
 coalesce(sum(original_source_municipalities_missing),0)::integer AS missing_source_municipalities,
 coalesce(sum(game_airport_name_locality_fallbacks),0)::integer AS airport_name_locality_fallbacks,
 coalesce(sum(original_gps_codes_missing),0)::integer AS missing_source_gps_codes,
 coalesce(sum(game_timezones_corrected),0)::integer AS game_timezones_corrected,
 coalesce(sum(zero_elevation_fallbacks),0)::integer AS zero_elevation_fallbacks,
 CASE WHEN count(*)=23 AND coalesce(sum(airports),0)=1118
 AND coalesce(sum(complete_game_profiles),0)=1118
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END AS game_data_result,
 false AS source_verified_complete,
 false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section1_batch_acceptance_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section1_overall_status_v1
 FROM PUBLIC,anon,authenticated;

DO $assert$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1
     WHERE section1_game_data_complete)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_batch_acceptance_v1)<>23
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_batch_completion_v1
      WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))<>0
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section1_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT missing_source_municipalities FROM
     airlinerra_game.airport_group2_section1_overall_status_v1)<>41
 OR (SELECT airport_name_locality_fallbacks FROM
     airlinerra_game.airport_group2_section1_overall_status_v1)<>17
 OR (SELECT missing_source_gps_codes FROM
     airlinerra_game.airport_group2_section1_overall_status_v1)<>2
 OR (SELECT game_timezones_corrected FROM
     airlinerra_game.airport_group2_section1_overall_status_v1)<>5
 OR (SELECT zero_elevation_fallbacks FROM
     airlinerra_game.airport_group2_section1_overall_status_v1)<>11
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_review_evidence_events_v1)<>0
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION1_BATCH_GAME_ACCEPTANCE_FAILED';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_game_registry_v1
  WHERE independently_source_verified OR commercially_admitted OR live_flight_authorized)
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
  WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'GROUP2_SECTION1_GAME_ACCEPTANCE_RELEASED_FLIGHTS';END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.airport_group2_batch1_desk_cases_v1 a
  JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key)
  WHERE b.batch_number<>1 OR b.case_number<>a.case_number)
 THEN RAISE EXCEPTION 'GROUP2_BATCH1_ORIGINAL_ORDER_CHANGED';END IF;
END $assert$;
