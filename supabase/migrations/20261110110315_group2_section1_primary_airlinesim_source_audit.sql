-- Section 1 ONLY — Group2 identity/geography source fallback.
-- No changes to Sections2-8, live airport roster, flight engines or airline finances.
-- Third-party AirlineSim references are game comparisons, NOT factual
-- aviation approval or canonical authority-verified airport data.
CREATE TABLE airlinerra_game.airport_group2_section1_source_candidates_v1 (
 candidate_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 airport_key text NOT NULL REFERENCES
  airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 identity_field text NOT NULL CHECK(identity_field IN
  ('served_city','iata_reference','icao_reference','gps_reference',
   'time_zone_reference','elevation_reference')),
 proposed_value text NOT NULL CHECK(length(btrim(proposed_value)) BETWEEN 2 AND 100),
 source_kind text NOT NULL CHECK(source_kind IN
  ('OFFICIAL_AIRPORT_OPERATOR','OFFICIAL_AUTHORITY',
   'AIRLINESIM_THIRD_PARTY_SIMULATION')),
 publisher text NOT NULL CHECK(length(btrim(publisher))>=7),
 source_url text NOT NULL CHECK(source_url ~ '^https://[^[:space:]]{8,}$'
  AND length(source_url)<=2048),
 source_page_date date,
 observed_on date NOT NULL DEFAULT DATE '2026-11-10',
 statement_context text NOT NULL CHECK(length(btrim(statement_context)) BETWEEN 35 AND 1500),
 review_status text NOT NULL CHECK(review_status IN
  ('PRIMARY_SOURCE_CANDIDATE_NEEDS_INDEPENDENT_REVIEW',
   'SIMULATION_COMPARISON_ONLY')),
 independently_authority_verified boolean NOT NULL DEFAULT false
  CHECK(independently_authority_verified=false),
 may_replace_game_profile boolean NOT NULL DEFAULT false
  CHECK(may_replace_game_profile=false),
 operational_or_commercial_authority boolean NOT NULL DEFAULT false
  CHECK(operational_or_commercial_authority=false),
 imported_on timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airport_key,identity_field,source_url),
 CHECK(
 (source_kind='AIRLINESIM_THIRD_PARTY_SIMULATION'
    AND review_status='SIMULATION_COMPARISON_ONLY'
    AND identity_field IN ('iata_reference','icao_reference'))
 OR (source_kind<>'AIRLINESIM_THIRD_PARTY_SIMULATION'
    AND review_status='PRIMARY_SOURCE_CANDIDATE_NEEDS_INDEPENDENT_REVIEW')
 ),
 CHECK(identity_field NOT IN('icao_reference','iata_reference')
  OR proposed_value ~ '^[A-Z0-9]{3,4}$')
);
ALTER TABLE airlinerra_game.airport_group2_section1_source_candidates_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section1_source_candidates_v1
 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER section1_source_candidates_immutable
 BEFORE UPDATE OR DELETE ON airlinerra_game.airport_group2_section1_source_candidates_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
COMMENT ON TABLE airlinerra_game.airport_group2_section1_source_candidates_v1 IS
 'Append-only section1 candidate-only research. AirlineSim data is third-party game comparison (not real aviation authority), limited to small public code comparisons. Operator sources are still pending independent approval. None of this changes canonical group2 fields or flight status.';

INSERT INTO airlinerra_game.airport_group2_section1_source_candidates_v1
(airport_key,identity_field,proposed_value,source_kind,publisher,
 source_url,statement_context,review_status)
VALUES
('OURAIRPORTS:26916','served_city','Ballarat',
 'OFFICIAL_AIRPORT_OPERATOR','City of Ballarat',
 'https://www.ballarat.vic.gov.au/Airport',
 'Airport operator identifies Ballarat Airport ICAO YBLT as seven kilometres northwest of Ballarat CBD in the Mitchell Park suburb. Proposed game served-city Ballarat is not a substitute for exact local administrative municipality.',
 'PRIMARY_SOURCE_CANDIDATE_NEEDS_INDEPENDENT_REVIEW'),
('OURAIRPORTS:27866','served_city','Onslow',
 'OFFICIAL_AIRPORT_OPERATOR','Shire of Ashburton',
 'https://www.ashburton.wa.gov.au/community/shire-facilities/onslow-airport.aspx',
 'Airport operator identifies Onslow Airport around three kilometres south of Onslow town. Source also describes security controlled passenger aerodrome, but this Section1 proposal does not grant any commercial flight permission.',
 'PRIMARY_SOURCE_CANDIDATE_NEEDS_INDEPENDENT_REVIEW'),
('OURAIRPORTS:26969','served_city','Dalby',
 'OFFICIAL_AIRPORT_OPERATOR','Western Downs Regional Council',
 'https://www.wdrc.qld.gov.au/Services-Payments/Aerodromes-Aircraft-Landing-Areas',
 'Council identifies Dalby Aerodrome YDAY 1.2 kilometres north of Dalby town centre. It calls the field non-certified ALA; locality is a Section1 candidate only, not a passenger airline clearance.',
 'PRIMARY_SOURCE_CANDIDATE_NEEDS_INDEPENDENT_REVIEW'),
('OURAIRPORTS:27866','iata_reference','ONS',
 'AIRLINESIM_THIRD_PARTY_SIMULATION','AirlineSim by simulogics',
 'https://paine.airlinesim.aero/action/info/county?id=10',
 'Public third-party simulation airport listing associates Onslow with ONS and ICAO YOLW. Comparison helps cross-check code spelling; not official IATA registry or current operating authority.',
 'SIMULATION_COMPARISON_ONLY'),
('OURAIRPORTS:27866','icao_reference','YOLW',
 'AIRLINESIM_THIRD_PARTY_SIMULATION','AirlineSim by simulogics',
 'https://paine.airlinesim.aero/action/info/county?id=10',
 'Public AirlineSim game world page lists Onslow YOLW and ONS. Same ICAO as existing Airlinerra source identifier; does not establish official active airport information.',
 'SIMULATION_COMPARISON_ONLY'),
('OURAIRPORTS:27069','iata_reference','WME',
 'AIRLINESIM_THIRD_PARTY_SIMULATION','AirlineSim by simulogics',
 'https://paine.airlinesim.aero/action/info/county?id=10',
 'AirlineSim public game listing associates Mount Keith with IATA WME and ICAO YMNE. Proposed code comparison only; not a sourced municipality or commercial operating permission.',
 'SIMULATION_COMPARISON_ONLY'),
('OURAIRPORTS:27069','icao_reference','YMNE',
 'AIRLINESIM_THIRD_PARTY_SIMULATION','AirlineSim by simulogics',
 'https://paine.airlinesim.aero/action/info/county?id=10',
 'AirlineSim public game listing names Mount Keith YMNE, WME; Airlinerra source already records YMNE. No import of AirlineSim demand or airport-size game parameters.',
 'SIMULATION_COMPARISON_ONLY'),
('OURAIRPORTS:27152','iata_reference','TEF',
 'AIRLINESIM_THIRD_PARTY_SIMULATION','AirlineSim by simulogics',
 'https://paine.airlinesim.aero/action/info/county?id=10',
 'AirlineSim public game listing names Telfer with IATA TEF and ICAO YTEF. Comparison only; an IATA code cannot fill a missing source municipality.',
 'SIMULATION_COMPARISON_ONLY'),
('OURAIRPORTS:27152','icao_reference','YTEF',
 'AIRLINESIM_THIRD_PARTY_SIMULATION','AirlineSim by simulogics',
 'https://paine.airlinesim.aero/action/info/county?id=10',
 'AirlineSim publicly lists Telfer YTEF and TEF; Airlinerra source already records YTEF. This is secondary game-only reference and not authority validation.',
 'SIMULATION_COMPARISON_ONLY');

CREATE VIEW airlinerra_game.airport_group2_section1_identity_quality_v1
 WITH (security_invoker=true) AS
WITH candidate_summary AS (
 SELECT airport_key,
 count(*) FILTER(WHERE source_kind<>'AIRLINESIM_THIRD_PARTY_SIMULATION')::integer
  primary_source_candidate_count,
 count(*) FILTER(WHERE source_kind='AIRLINESIM_THIRD_PARTY_SIMULATION')::integer
  airlinesim_comparison_count,
 count(*) FILTER(WHERE identity_field='served_city'
   AND source_kind<>'AIRLINESIM_THIRD_PARTY_SIMULATION')::integer
  served_city_primary_candidates,
 count(*) FILTER(WHERE independently_authority_verified)::integer approved_candidates
 FROM airlinerra_game.airport_group2_section1_source_candidates_v1
 GROUP BY airport_key
)
SELECT g.airport_key,g.game_airport_name,g.country_iso,g.source_ident,g.source_gps_code,
 g.source_municipality,g.game_locality_display,g.game_lookup_code,
 g.latitude_deg,g.longitude_deg,g.timezone_iana,g.timezone_game_basis,
 g.game_elevation_ft,g.elevation_game_basis,
 (g.source_municipality IS NULL OR btrim(g.source_municipality)='') AS source_municipality_missing,
 (g.source_gps_code IS NULL OR btrim(g.source_gps_code)='') AS source_gps_code_missing,
 (g.timezone_game_basis<>'AUTHORITY_VERIFIED') AS time_zone_not_authority_verified,
 (g.elevation_game_basis='UNSOURCED_GAME_ZERO_FALLBACK') AS elevation_zero_fallback,
 coalesce(c.primary_source_candidate_count,0) AS primary_source_candidate_count,
 coalesce(c.airlinesim_comparison_count,0) AS airlinesim_comparison_count,
 coalesce(c.served_city_primary_candidates,0) AS served_city_primary_candidates,
 coalesce(c.approved_candidates,0) AS approved_candidates,
 CASE
 WHEN g.source_municipality IS NULL OR btrim(g.source_municipality)=''
 THEN CASE WHEN coalesce(c.served_city_primary_candidates,0)>0
  THEN 'MISSING_SOURCE_MUNICIPALITY_PRIMARY_CANDIDATE_REVIEW'
  ELSE 'MISSING_SOURCE_MUNICIPALITY_RESEARCH_REQUIRED' END
 WHEN g.source_gps_code IS NULL OR btrim(g.source_gps_code)=''
 THEN 'MISSING_GPS_REFERENCE_REVIEW'
 WHEN g.timezone_game_basis='UA_COUNTRY_GAME_ESTIMATE'
 THEN 'COUNTRY_TIMEZONE_FALLBACK_REVIEW'
 ELSE 'GAME_TIMEZONE_ESTIMATE_REQUIRES_SOURCE_VERIFICATION'
 END AS next_section1_action,
 false AS section1_authority_verified,
 false AS usable_as_real_aviation_clearance
FROM airlinerra_game.airport_group2_game_profiles_v1 g
LEFT JOIN candidate_summary c USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section1_identity_quality_v1
 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section1_progress_v1
 WITH (security_invoker=true) AS
SELECT
 count(*)::integer game_identity_profiles,
 count(*) FILTER(WHERE source_municipality_missing)::integer source_municipalities_missing,
 count(*) FILTER(WHERE source_municipality_missing
   AND served_city_primary_candidates>0)::integer missing_city_with_primary_candidate,
 count(*) FILTER(WHERE source_municipality_missing
   AND served_city_primary_candidates=0)::integer missing_city_without_primary_candidate,
 count(*) FILTER(WHERE source_gps_code_missing)::integer source_gps_codes_missing,
 count(*) FILTER(WHERE time_zone_not_authority_verified)::integer game_timezones_not_authority_verified,
 count(*) FILTER(WHERE elevation_zero_fallback)::integer game_zero_elevation_fallbacks,
 count(*) FILTER(WHERE primary_source_candidate_count>0)::integer airports_with_primary_source_candidates,
 count(*) FILTER(WHERE airlinesim_comparison_count>0)::integer airports_with_airlinesim_comparisons,
 coalesce(sum(primary_source_candidate_count),0)::integer primary_source_candidates,
 coalesce(sum(airlinesim_comparison_count),0)::integer airlinesim_field_comparisons,
 count(*) FILTER(WHERE section1_authority_verified)::integer authority_verified_section1_airports
FROM airlinerra_game.airport_group2_section1_identity_quality_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section1_progress_v1 FROM PUBLIC,anon,authenticated;

COMMENT ON VIEW airlinerra_game.airport_group2_section1_identity_quality_v1 IS
 'Section1-only source completeness and provenance, not a real-world airport certification. Group2 source municipality remains null until independent review. AirlineSim reference cannot satisfy an authority source gate.';

DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_identity_quality_v1)<>1118
 OR (SELECT source_municipalities_missing
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>41
 OR (SELECT missing_city_with_primary_candidate
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>3
 OR (SELECT missing_city_without_primary_candidate
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>38
 OR (SELECT source_gps_codes_missing
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>2
 OR (SELECT game_timezones_not_authority_verified
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>1118
 OR (SELECT game_zero_elevation_fallbacks
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>11
 OR (SELECT airlinesim_field_comparisons
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>6
 OR (SELECT primary_source_candidates
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>3
 OR (SELECT authority_verified_section1_airports
     FROM airlinerra_game.airport_group2_section1_progress_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_review_evidence_events_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION1_SOURCE_FALLBACK_ACCEPTANCE_FAILED';END IF;
END $verify$;
