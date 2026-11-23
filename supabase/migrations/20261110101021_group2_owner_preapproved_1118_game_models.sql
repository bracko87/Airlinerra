-- Group 2: owner's 1,118 PRE_APPROVED expansion airports, independent from
-- the existing 3,141 World 1 approved/playable-roster airports.
-- Game-data models reuse the Group 1 category medians and Section 8 policies.
-- This is NOT a grant of real commercial aviation rights, not an airport
-- activation, and it does not change Group 1 / World 1 / flight releases.

CREATE TABLE airlinerra_game.airport_group2_game_profiles_v1 (
 airport_key text PRIMARY KEY REFERENCES airlinerra.airport_registry(airport_key),
 group_code text NOT NULL DEFAULT 'GROUP_2_OWNER_PREAPPROVED_1118'
  CHECK(group_code='GROUP_2_OWNER_PREAPPROVED_1118'),
 review_sequence integer NOT NULL UNIQUE,
 owner_category text NOT NULL CHECK(owner_category IN
   ('Local','Regional','Medium','Large','Major Hub','Mega Hub')),
 game_traffic_type text NOT NULL CHECK(game_traffic_type IN ('Passenger','Cargo','Both')),
 owner_decision text NOT NULL CHECK(owner_decision='PRE_APPROVED'),
 preapproved_at timestamptz NOT NULL,
 identity_source text NOT NULL DEFAULT 'airlinerra.airport_registry',
 game_airport_name text NOT NULL,
 source_municipality text,
 game_locality_display text NOT NULL,
 country_iso text NOT NULL CHECK(country_iso ~ '^[A-Z]{2}$'),
 region_code text,
 source_ident text,
 source_gps_code text,
 game_lookup_code text NOT NULL UNIQUE CHECK(game_lookup_code LIKE 'G2-%'),
 latitude_deg numeric NOT NULL CHECK(latitude_deg BETWEEN -90 AND 90),
 longitude_deg numeric NOT NULL CHECK(longitude_deg BETWEEN -180 AND 180),
 timezone_iana text NOT NULL,
 timezone_game_basis text NOT NULL CHECK(timezone_game_basis IN
   ('NEAREST_SAME_COUNTRY_GAME_ESTIMATE','UA_COUNTRY_GAME_ESTIMATE')),
 timezone_neighbor_distance_km numeric,
 game_elevation_ft numeric NOT NULL,
 elevation_game_basis text NOT NULL,
 runway_registry_qualified_length_m numeric NOT NULL CHECK(runway_registry_qualified_length_m>=1200),
 runway_registry_qualified_surface text NOT NULL,
 longest_detail_length_m numeric,
 detail_runway_width_m numeric,
 game_runway_width_m numeric NOT NULL CHECK(game_runway_width_m>0),
 runway_width_game_basis text NOT NULL,
 detailed_runway_observation_count integer NOT NULL CHECK(detailed_runway_observation_count>=0),
 game_terminal_count integer NOT NULL CHECK(game_terminal_count>=0),
 game_terminal_stands integer NOT NULL CHECK(game_terminal_stands>=0),
 game_remote_stands integer NOT NULL CHECK(game_remote_stands>=0),
 game_cargo_stands integer NOT NULL CHECK(game_cargo_stands>=0),
 game_terminal_slot_per_10m integer NOT NULL CHECK(game_terminal_slot_per_10m>=0),
 game_remote_slot_per_10m integer NOT NULL CHECK(game_remote_slot_per_10m>=0),
 game_cargo_slot_per_10m integer NOT NULL CHECK(game_cargo_slot_per_10m>=0),
 game_nighttime_ban boolean,
 game_noise_restrictions boolean,
 game_restriction_basis text NOT NULL DEFAULT 'UNSOURCED_NO_OPERATIONAL_CLEARANCE'
    CHECK(game_restriction_basis='UNSOURCED_NO_OPERATIONAL_CLEARANCE'),
 game_daily_outbound_passengers integer NOT NULL CHECK(game_daily_outbound_passengers>=0),
 game_daily_outbound_cargo_tonnes numeric(12,3) NOT NULL CHECK(game_daily_outbound_cargo_tonnes>=0),
 game_season_profile text NOT NULL DEFAULT 'neutral_unverified_game_default_v1',
 game_landing_fee_usd integer NOT NULL CHECK(game_landing_fee_usd>0),
 game_parking_per_day_usd integer NOT NULL CHECK(game_parking_per_day_usd>0),
 game_departing_pax_fee_usd integer NOT NULL CHECK(game_departing_pax_fee_usd>0),
 game_airport_background text NOT NULL DEFAULT 'standard'
     CHECK(game_airport_background='standard'),
 background_verified boolean NOT NULL DEFAULT false CHECK(background_verified=false),
 pricing_model_version text NOT NULL DEFAULT 'group2_group1_category_median_game_v1',
 game_data_status text NOT NULL DEFAULT 'MODEL_PREPARED' CHECK(game_data_status='MODEL_PREPARED'),
 commercial_access_verified boolean NOT NULL DEFAULT false
     CHECK(commercial_access_verified=false),
 commercial_playable boolean NOT NULL DEFAULT false CHECK(commercial_playable=false),
 source_note text NOT NULL DEFAULT
  'Owner PRE_APPROVED for GROUP 2 game-data model ONLY. Coordinates/runway from historical registry; stand, traffic, elevation, timezone when inferred, demand and fee amounts are GAME estimates. Curfew/noise unknown. No real commercial authorization.',
 prepared_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((game_traffic_type='Cargo' AND game_daily_outbound_passengers=0)
    OR (game_traffic_type<>'Cargo')),
 CHECK((game_traffic_type='Passenger' AND game_daily_outbound_cargo_tonnes=0)
    OR (game_traffic_type<>'Passenger')),
 CHECK(game_terminal_stands+game_remote_stands+game_cargo_stands>0),
 CHECK((game_traffic_type='Cargo' AND game_cargo_stands>0)
       OR game_traffic_type<>'Cargo')
);
ALTER TABLE airlinerra_game.airport_group2_game_profiles_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_game_profiles_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.airport_group2_game_profiles_v1 IS
 'All 1,118 owner-preapproved Group 2 airports, modeled as separate game-data cohort; NOT in 3,141 World 1 commercial roster. Do not mistake source unknowns or game estimates for verified aviation data.';

CREATE TABLE airlinerra_game.airport_group2_source_runways_v1 (
 observation_id bigint PRIMARY KEY,
 airport_key text NOT NULL REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 source_runway_id text,
 runway_ident text,
 source_length_m numeric,
 source_width_m numeric,
 surface_reported text,
 reported_operational_status text,
 evidence_origin text,
 source_url text,
 source_effective_date date
);
ALTER TABLE airlinerra_game.airport_group2_source_runways_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_source_runways_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.airport_group2_source_runways_v1 IS
 'Complete available Group 2 source runway observations. Missing source widths, short observations, or absent observation rows are not invented. Game fallback runway is separately identified on airport profile.';

-- Lock the original Group 1 roster; this remains a separate cohort.
DO $preflight$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_candidate_preapproval_pool
       WHERE decision_status='PRE_APPROVED' AND reviewed_by='OWNER_CHECKLIST')<>1118
    OR (SELECT count(DISTINCT airport_key)
        FROM airlinerra.airport_candidate_preapproval_pool)<>1118
    OR EXISTS(SELECT 1 FROM airlinerra.airport_candidate_preapproval_pool c
       JOIN airlinerra_game.approved_game_airports a ON a.airport_key=c.airport_key
       WHERE a.world_id=1)
    OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
    OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SOURCE_SET_OR_GROUP1_ROSTER_CHANGED'; END IF;
END $preflight$;

-- Reuse Group 1 medians in SAME category, not same airport's data.
-- Store all game estimate outputs frozen and auditable per airport.
WITH templates AS (
 SELECT p.provisional_category AS category,
  greatest(1,round(percentile_cont(.5) WITHIN GROUP(ORDER BY f.terminal_count)))::integer terminal_count,
  greatest(1,round(percentile_cont(.5) WITHIN GROUP(ORDER BY s.terminal_stands)))::integer terminal_stands,
  greatest(0,round(percentile_cont(.5) WITHIN GROUP(ORDER BY s.remote_stands)))::integer remote_stands,
  greatest(0,round(percentile_cont(.5) WITHIN GROUP(ORDER BY s.cargo_stands)))::integer cargo_stands,
  greatest(1,round(percentile_cont(.5) WITHIN GROUP(ORDER BY s.terminal_per_direction_10m)))::integer terminal_slots,
  greatest(0,round(percentile_cont(.5) WITHIN GROUP(ORDER BY s.remote_per_direction_10m)))::integer remote_slots,
  greatest(0,round(percentile_cont(.5) WITHIN GROUP(ORDER BY s.cargo_per_direction_10m)))::integer cargo_slots,
  greatest(1,round(percentile_cont(.5) WITHIN GROUP(ORDER BY b.avg_daily_outbound_passengers)))::integer daily_pax,
  round((percentile_cont(.5) WITHIN GROUP(ORDER BY b.avg_daily_outbound_cargo_tonnes))::numeric,3) daily_cargo,
  greatest(1,round(percentile_cont(.5) WITHIN GROUP(ORDER BY g.landing_fee_usd)))::integer landing_fee,
  greatest(1,round(percentile_cont(.5) WITHIN GROUP(ORDER BY g.parking_per_day_usd)))::integer parking_fee,
  greatest(1,round(percentile_cont(.5) WITHIN GROUP(ORDER BY g.departing_passenger_fee_usd)))::integer pax_fee,
  round((percentile_cont(.5) WITHIN GROUP(ORDER BY ri.width_m))::numeric,1) runway_width
 FROM airlinerra_game.airport_reference_profiles p
 JOIN airlinerra_game.airport_facilities f USING(world_id,airport_key)
 JOIN airlinerra_game.section6_airport_slot_capacity_v1 s USING(world_id,airport_key)
 JOIN airlinerra_game.airport_daily_traffic_pool_baselines b USING(world_id,airport_key)
 JOIN airlinerra_game.airport_game_fees g USING(world_id,airport_key)
 JOIN airlinerra_game.airport_runway_inventory ri USING(world_id,airport_key)
 WHERE p.world_id=1
 GROUP BY p.provisional_category
), source AS (
 SELECT c.*,r.airport_name,r.country_iso,r.region_code,r.municipality,
 r.source_ident,r.source_gps_code,r.latitude_deg,r.longitude_deg,
 r.longest_qualifying_runway_m,r.longest_qualifying_surface,
 t.*,
 best.length_m best_runway_length,best.width_m best_runway_width,
 coalesce(obs.n,0) n_observations,
 nearest.timezone_iana nearest_timezone,
 nearest.game_elevation_ft nearest_elevation,
 nearest.km nearest_distance,
 (ascii(substr(md5(c.airport_key),1,1)) % 21 -10) AS game_variation
 FROM airlinerra.airport_candidate_preapproval_pool c
 JOIN airlinerra.airport_registry r USING(airport_key)
 JOIN templates t ON t.category=c.approved_category
 LEFT JOIN LATERAL (
  SELECT ro.length_m,ro.width_m
  FROM airlinerra.airport_runway_observations ro
  WHERE ro.airport_key=c.airport_key
  ORDER BY ro.length_m DESC NULLS LAST,ro.source_runway_id
  LIMIT 1
 ) best ON true
 LEFT JOIN LATERAL (
  SELECT count(*)::integer AS n FROM airlinerra.airport_runway_observations ro
  WHERE ro.airport_key=c.airport_key
 ) obs ON true
 LEFT JOIN LATERAL (
  SELECT ap.timezone_iana,ap.game_elevation_ft,
   round(sqrt(
     power((ap.latitude_deg-r.latitude_deg)::double precision*111.2,2)+
     power((ap.longitude_deg-r.longitude_deg)::double precision*
       111.2*cos(radians(r.latitude_deg::double precision)),2)
   )::numeric,1) km
  FROM airlinerra_game.airport_reference_profiles ap
  WHERE ap.world_id=1 AND ap.country_iso=r.country_iso
    AND ap.timezone_iana IS NOT NULL
    AND ap.latitude_deg IS NOT NULL AND ap.longitude_deg IS NOT NULL
  ORDER BY power(ap.latitude_deg-r.latitude_deg,2)+
    power((ap.longitude_deg-r.longitude_deg)*
      cos(radians(r.latitude_deg::double precision)),2)
  LIMIT 1
 ) nearest ON true
 WHERE c.decision_status='PRE_APPROVED' AND c.reviewed_by='OWNER_CHECKLIST'
)
INSERT INTO airlinerra_game.airport_group2_game_profiles_v1(
 airport_key,review_sequence,owner_category,game_traffic_type,owner_decision,
 preapproved_at,game_airport_name,source_municipality,game_locality_display,
 country_iso,region_code,source_ident,source_gps_code,game_lookup_code,
 latitude_deg,longitude_deg,timezone_iana,timezone_game_basis,
 timezone_neighbor_distance_km,game_elevation_ft,elevation_game_basis,
 runway_registry_qualified_length_m,runway_registry_qualified_surface,
 longest_detail_length_m,detail_runway_width_m,game_runway_width_m,
 runway_width_game_basis,detailed_runway_observation_count,
 game_terminal_count,game_terminal_stands,game_remote_stands,game_cargo_stands,
 game_terminal_slot_per_10m,game_remote_slot_per_10m,game_cargo_slot_per_10m,
 game_nighttime_ban,game_noise_restrictions,
 game_daily_outbound_passengers,game_daily_outbound_cargo_tonnes,
 game_landing_fee_usd,game_parking_per_day_usd,game_departing_pax_fee_usd
)
SELECT
 airport_key,review_sequence,approved_category,traffic_type,decision_status,
 preapproved_at,airport_name,municipality,coalesce(nullif(btrim(municipality),''),airport_name),
 country_iso,region_code,source_ident,source_gps_code,
 'G2-'||split_part(airport_key,':',2),
 latitude_deg,longitude_deg,coalesce(nearest_timezone,'Europe/Kyiv'),
 CASE WHEN nearest_timezone IS NOT NULL THEN 'NEAREST_SAME_COUNTRY_GAME_ESTIMATE'
   ELSE 'UA_COUNTRY_GAME_ESTIMATE' END,
 nearest_distance,coalesce(nearest_elevation,0),
 CASE WHEN nearest_elevation IS NULL THEN 'UNSOURCED_GAME_ZERO_FALLBACK'
   ELSE 'NEAREST_SAME_COUNTRY_GAME_ESTIMATE' END,
 longest_qualifying_runway_m,longest_qualifying_surface,
 best_runway_length,best_runway_width,
 coalesce(nullif(best_runway_width,0),runway_width),
 CASE WHEN best_runway_width>0 THEN 'SOURCE_REPORTED_DETAIL_UNVERIFIED'
  ELSE 'CATEGORY_MEDIAN_GAME_WIDTH_ESTIMATE' END,n_observations,
 CASE WHEN traffic_type='Cargo' THEN 0 ELSE terminal_count END,
 CASE WHEN traffic_type='Cargo' THEN 0 ELSE terminal_stands END,
 CASE WHEN traffic_type='Cargo' THEN 0 ELSE remote_stands END,
 CASE WHEN traffic_type='Passenger' THEN 0 ELSE greatest(1,cargo_stands) END,
 CASE WHEN traffic_type='Cargo' THEN 0 ELSE terminal_slots END,
 CASE WHEN traffic_type='Cargo' THEN 0 ELSE remote_slots END,
 CASE WHEN traffic_type='Passenger' THEN 0 ELSE greatest(1,cargo_slots) END,
 NULL::boolean,NULL::boolean,
 CASE WHEN traffic_type='Cargo' THEN 0
 ELSE greatest(1,round(daily_pax*(1+game_variation/100.0)))::integer END,
 CASE WHEN traffic_type='Passenger' THEN 0
 ELSE round(daily_cargo*(1+game_variation/100.0),3) END,
 greatest(1,round(landing_fee*(1+game_variation/100.0)))::integer,
 greatest(1,round(parking_fee*(1+game_variation/100.0)))::integer,
 greatest(1,round(pax_fee*(1+game_variation/100.0)))::integer
FROM source;

INSERT INTO airlinerra_game.airport_group2_source_runways_v1 (
 observation_id,airport_key,source_runway_id,runway_ident,source_length_m,
 source_width_m,surface_reported,reported_operational_status,
 evidence_origin,source_url,source_effective_date
)
SELECT ro.id,ro.airport_key,ro.source_runway_id,ro.runway_ident,ro.length_m,
 ro.width_m,ro.surface,ro.reported_operational_status,ro.evidence_origin,
 ro.source_url,ro.source_effective_date
FROM airlinerra.airport_runway_observations ro
JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key);

-- Named separate section interfaces, all private and read-only. Same
-- development *categories* as Group 1, with distinct Group 2 provenance.
CREATE VIEW airlinerra_game.airport_group2_section1_identity_v1
 WITH (security_invoker=true) AS
SELECT airport_key,game_airport_name,source_municipality,game_locality_display,
country_iso,region_code,source_ident,source_gps_code,game_lookup_code,
latitude_deg,longitude_deg,timezone_iana,timezone_game_basis,
timezone_neighbor_distance_km,game_elevation_ft,elevation_game_basis,
owner_category AS game_category,commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1;
CREATE VIEW airlinerra_game.airport_group2_section2_classification_v1
 WITH (security_invoker=true) AS
SELECT airport_key,review_sequence,owner_category AS game_category,
owner_decision,preapproved_at,game_traffic_type,commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1;
CREATE VIEW airlinerra_game.airport_group2_section3_runways_v1
 WITH (security_invoker=true) AS
SELECT airport_key,runway_registry_qualified_length_m,
runway_registry_qualified_surface,longest_detail_length_m,
detail_runway_width_m,game_runway_width_m,runway_width_game_basis,
detailed_runway_observation_count,commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1;
CREATE VIEW airlinerra_game.airport_group2_section4_facilities_v1
 WITH (security_invoker=true) AS
SELECT airport_key,game_terminal_count,game_terminal_stands,
game_remote_stands,game_cargo_stands,game_traffic_type,
'CATEGORY_MEDIAN_GAME_ESTIMATE_NOT_VERIFIED_FACILITY'::text facility_basis,
commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1;
CREATE VIEW airlinerra_game.airport_group2_section5_restrictions_v1
 WITH (security_invoker=true) AS
SELECT airport_key,game_nighttime_ban,game_noise_restrictions,
game_restriction_basis,
'NOT_VERIFIED_FOR_DISPATCH'::text dispatch_restrictions_status,
commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1;
CREATE VIEW airlinerra_game.airport_group2_section6_capacity_v1
 WITH (security_invoker=true) AS
SELECT airport_key,game_terminal_stands,game_remote_stands,game_cargo_stands,
game_terminal_slot_per_10m,game_remote_slot_per_10m,
game_cargo_slot_per_10m,
'GROUP1_CATEGORY_MEDIAN_GAME_NOT_COORDINATOR_SLOTS'::text capacity_basis,
commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1;
CREATE VIEW airlinerra_game.airport_group2_section7_demand_v1
 WITH (security_invoker=true) AS
SELECT airport_key,game_traffic_type,game_daily_outbound_passengers,
game_daily_outbound_cargo_tonnes,game_season_profile,
'GROUP1_CATEGORY_MEDIAN_NEUTRAL_SEASON_GAME_ESTIMATE'::text model_basis,
commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1;
CREATE VIEW airlinerra_game.airport_group2_section8_economics_v1
 WITH (security_invoker=true) AS
SELECT g.airport_key,g.owner_category AS game_category,
g.game_airport_background,g.background_verified,
g.game_landing_fee_usd,g.game_parking_per_day_usd,
g.game_departing_pax_fee_usd,
p.terminal_stand_multiplier,p.remote_stand_multiplier,
p.cargo_stand_multiplier,p.terminal_navigation_unit_usd,
p.cargo_handling_per_tonne_usd,p.ground_handling_fraction,
p.security_per_departing_passenger_usd,
p.international_processing_per_departing_passenger_usd,
'GROUP1_CATEGORY_MEDIAN_GAME_RATE_NOT_REAL_TARIFF'::text pricing_basis,
g.commercial_playable
FROM airlinerra_game.airport_group2_game_profiles_v1 g
JOIN airlinerra_game.section8_fee_category_policy_v1 p
 ON p.world_id=1 AND p.airport_category=g.owner_category;

DO $security$
DECLARE name text;
BEGIN
 FOR name IN SELECT unnest(ARRAY[
 'airport_group2_section1_identity_v1','airport_group2_section2_classification_v1',
 'airport_group2_section3_runways_v1','airport_group2_section4_facilities_v1',
 'airport_group2_section5_restrictions_v1','airport_group2_section6_capacity_v1',
 'airport_group2_section7_demand_v1','airport_group2_section8_economics_v1'
 ]) LOOP
  EXECUTE format('REVOKE ALL ON airlinerra_game.%I FROM PUBLIC,anon,authenticated',name);
 END LOOP;
END $security$;

CREATE TABLE airlinerra_game.airport_group2_game_data_section_acceptance_v1 (
 group_code text NOT NULL DEFAULT 'GROUP_2_OWNER_PREAPPROVED_1118',
 category_number smallint NOT NULL CHECK(category_number BETWEEN 1 AND 8),
 game_profile_rows integer NOT NULL CHECK(game_profile_rows=1118),
 game_model_status text NOT NULL CHECK(game_model_status IN
   ('GAME_MODEL_PREPARED_ESTIMATED','SOURCE_RESEARCH_NEEDED_BEFORE_LIVE_FLIGHTS')),
 source_verified_complete boolean NOT NULL DEFAULT false CHECK(source_verified_complete=false),
 real_world_commercial_authority boolean NOT NULL DEFAULT false CHECK(real_world_commercial_authority=false),
 playable_release_enabled boolean NOT NULL DEFAULT false CHECK(playable_release_enabled=false),
 notes text NOT NULL,
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10',
 PRIMARY KEY(group_code,category_number),
 CHECK(group_code='GROUP_2_OWNER_PREAPPROVED_1118')
);
ALTER TABLE airlinerra_game.airport_group2_game_data_section_acceptance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_game_data_section_acceptance_v1
 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.airport_group2_game_data_section_acceptance_v1
 (category_number,game_profile_rows,game_model_status,notes)
VALUES
 (1,1118,'GAME_MODEL_PREPARED_ESTIMATED',
  'All 1,118 source IDs/coordinates/country and owner game category captured; 41 missing source municipalities use airport-name DISPLAY fallback only. Timezones estimated from same-country Group1 nearest; Ukraine 11 uses labeled Europe/Kyiv game assumption. Elevation game estimates, never aviation claims.'),
 (2,1118,'GAME_MODEL_PREPARED_ESTIMATED',
  'Owner preapproved 754 Local, 338 Regional, 26 Medium; passenger/cargo/both intention preserved. No final commercial authority asserted.'),
 (3,1118,'GAME_MODEL_PREPARED_ESTIMATED',
  'All source qualifying runway lengths/surfaces preserved, detailed runway observations copied separately. Source width unknown on 20, 9 no detailed runway rows, 9 have registry/detail length shortfall; game width fallback clearly marked.'),
 (4,1118,'GAME_MODEL_PREPARED_ESTIMATED',
  'Category-derived game terminal/remote/cargo stands and support for passenger/cargo types; not verified physical facilities.'),
 (5,1118,'SOURCE_RESEARCH_NEEDED_BEFORE_LIVE_FLIGHTS',
  'Night noise, curfews, civil-access and current operational restrictions are UNKNOWN; NULL, never assumed to be unrestricted. Block all flight activation.'),
 (6,1118,'GAME_MODEL_PREPARED_ESTIMATED',
  'Slot/capacity game estimates derived from existing Group1 median; no published coordinated slots or airport capacity certifications.'),
 (7,1118,'GAME_MODEL_PREPARED_ESTIMATED',
  'Passenger/cargo baseline game estimates from Group1 category median and owner traffic-type intention; default neutral monthly seasonal 100%, not factual statistics.'),
 (8,1118,'GAME_MODEL_PREPARED_ESTIMATED',
  'Airport fee baselines from existing agreed Group1 category median with bounded deterministic game variation; existing Section8 stand/cargo/ATC policy reused, no double tourism premium without evidence. No airline charges.');

DO $accept$
DECLARE total integer;
BEGIN
 SELECT count(*) INTO total FROM airlinerra_game.airport_group2_game_profiles_v1;
 IF total<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_source_runways_v1)<>1828
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE commercial_playable)<>0
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_data_section_acceptance_v1)<>8
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section8_economics_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
     WHERE timezone_iana IS NULL OR game_runway_width_m<=0
       OR game_landing_fee_usd<=0)<>0
 THEN RAISE EXCEPTION 'GROUP2_FULL_GAME_DATA_COHORT_ACCEPTANCE_FAILED'; END IF;
END $accept$;
