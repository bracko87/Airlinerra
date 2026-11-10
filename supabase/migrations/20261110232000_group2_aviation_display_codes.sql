-- Group 2 aviation display codes. Never replace internal airport IDs.
-- Source gps_code is NOT automatically a verified ICAO assignment.
DO $pre$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 WHERE source_group='GROUP_2')<>3354
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE source_gps_code ~ '^[A-Z]{4}$')<>1116
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE source_gps_code IS NULL)<>2
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE game_lookup_code NOT LIKE 'G2-%')<>0
 THEN RAISE EXCEPTION 'GROUP2_CODE_REMAP_PREFLIGHT_CHANGED';END IF;
END $pre$;

CREATE TABLE airlinerra_game.airport_group2_aviation_display_codes_v1(
 airport_key text PRIMARY KEY REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 display_code text NOT NULL CHECK(display_code ~ '^[A-Z]{4}$'),
 code_kind text NOT NULL CHECK(code_kind IN ('ICAO_CONFIRMED','SOURCE_GPS_CODE_NOT_ICAO_VERIFIED','EXTERNAL_REPORTED_ICAO_NEEDS_AUTHORITY_CHECK')),
 original_internal_lookup_code text NOT NULL CHECK(original_internal_lookup_code LIKE 'G2-%'),
 code_source_url text,
 checked_at timestamptz NOT NULL DEFAULT now(),
 ICAO_authority_verified boolean NOT NULL DEFAULT false,
 CHECK(code_kind <> 'SOURCE_GPS_CODE_NOT_ICAO_VERIFIED' OR ICAO_authority_verified=false),
 CHECK(ICAO_authority_verified=false OR code_kind='ICAO_CONFIRMED'),
 UNIQUE(display_code),
 UNIQUE(original_internal_lookup_code)
);
ALTER TABLE airlinerra_game.airport_group2_aviation_display_codes_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_aviation_display_codes_v1 FROM PUBLIC,anon,authenticated;

INSERT INTO airlinerra_game.airport_group2_aviation_display_codes_v1
 (airport_key,display_code,code_kind,original_internal_lookup_code,code_source_url,ICAO_authority_verified)
SELECT g.airport_key,
 CASE
  WHEN g.airport_key='OURAIRPORTS:5774' THEN 'SACT'
  WHEN g.airport_key='OURAIRPORTS:6478' THEN 'UKKK'
  ELSE g.source_gps_code END,
 CASE
  WHEN g.airport_key IN ('OURAIRPORTS:1649','OURAIRPORTS:31795','OURAIRPORTS:6478') THEN 'ICAO_CONFIRMED'
  WHEN g.airport_key='OURAIRPORTS:5774' THEN 'EXTERNAL_REPORTED_ICAO_NEEDS_AUTHORITY_CHECK'
  ELSE 'SOURCE_GPS_CODE_NOT_ICAO_VERIFIED' END,
 g.game_lookup_code,
 CASE g.airport_key
  WHEN 'OURAIRPORTS:1649' THEN 'https://aerodromponikve.rs/?lang=en'
  WHEN 'OURAIRPORTS:31795' THEN 'https://kuiport.al/en/article/43/Facts-of-KFZ'
  WHEN 'OURAIRPORTS:6478' THEN 'https://centreforaviation.com/data/profiles/airports/kyiv-igor-sikorsky-international-airport-iev'
  WHEN 'OURAIRPORTS:5774' THEN 'https://airportexpert.com/airports/ar/f/sact'
  ELSE 'https://ourairports.com/help/data-dictionary.html' END,
 g.airport_key IN ('OURAIRPORTS:1649','OURAIRPORTS:31795')
FROM airlinerra_game.airport_group2_game_profiles_v1 g;

-- All worlds display the same aviation code while keeping the immutable airport key.
UPDATE airlinerra_game.airport_location_eligibility_v1 l
SET airport_code=d.display_code
FROM airlinerra_game.airport_group2_aviation_display_codes_v1 d
WHERE l.airport_key=d.airport_key AND l.source_group='GROUP_2'
 AND l.airport_code IS DISTINCT FROM d.display_code;

CREATE VIEW airlinerra_game.airport_group2_aviation_code_audit_v1
WITH (security_invoker=true) AS
SELECT count(*)::int AS group2_count,
 count(*) FILTER(WHERE d.display_code ~ '^[A-Z]{4}$')::int AS four_letter_display_codes,
 count(DISTINCT d.display_code)::int AS distinct_codes,
 count(*) FILTER(WHERE d.code_kind='ICAO_CONFIRMED')::int AS sourced_icao_identifications,
 count(*) FILTER(WHERE d.code_kind='SOURCE_GPS_CODE_NOT_ICAO_VERIFIED')::int AS gps_identifiers_pending_icao_check,
 count(*) FILTER(WHERE d.code_kind='EXTERNAL_REPORTED_ICAO_NEEDS_AUTHORITY_CHECK')::int AS external_reported_pending_authority,
 (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 l
  JOIN airlinerra_game.airport_group2_aviation_display_codes_v1 codes USING(airport_key)
  WHERE l.source_group='GROUP_2' AND l.airport_code=codes.display_code)::int AS world_rows_correct
FROM airlinerra_game.airport_group2_aviation_display_codes_v1 d;
REVOKE ALL ON airlinerra_game.airport_group2_aviation_code_audit_v1 FROM PUBLIC,anon,authenticated;

DO $post$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_aviation_display_codes_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_aviation_display_codes_v1 WHERE display_code !~ '^[A-Z]{4}$')
 OR (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 l
  JOIN airlinerra_game.airport_group2_aviation_display_codes_v1 d USING(airport_key)
  WHERE l.source_group='GROUP_2' AND l.airport_code=d.display_code)<>3354
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_location_eligibility_v1
  WHERE world_id=1 AND airport_key='OURAIRPORTS:1649' AND airport_code='LYUZ')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_location_eligibility_v1
  WHERE world_id=1 AND airport_key='OURAIRPORTS:31795' AND airport_code='LAKU')
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'GROUP2_AVIATION_CODE_REMAP_POSTCHECK_FAILED';END IF;
END $post$;