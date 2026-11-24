-- Synthetic minimal airport tables to test the exact forward-only view
-- migration without production data or any separate paid Supabase branch.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('airlinerra_game') IS NOT NULL
 THEN RAISE EXCEPTION 'AIRPORT_RESTRICTION_TEST_MUST_USE_CLEAN_DISPOSABLE_POSTGRES';END IF;
END $guard$;
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon')
 THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated')
 THEN CREATE ROLE authenticated NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role')
 THEN CREATE ROLE service_role NOLOGIN; END IF;
END $roles$;
CREATE SCHEMA airlinerra_game;
CREATE TABLE airlinerra_game.airport_sections1_8_combined_catalog_v1(
 world_id smallint NOT NULL,airport_key text NOT NULL,
 source_group text NOT NULL,airport_name text NOT NULL,
 game_lookup_code text NOT NULL,country_iso text,game_category text,
 latitude_deg numeric,longitude_deg numeric,timezone_iana text,
 game_runway_length_m numeric,game_terminal_count integer,
 game_terminal_stands integer,game_remote_stands integer,
 game_cargo_stands integer,game_terminal_slot_per_10m integer,
 game_remote_slot_per_10m integer,game_cargo_slot_per_10m integer,
 game_nighttime_ban boolean,game_noise_restrictions boolean,
 restriction_basis text,game_daily_outbound_passengers integer,
 game_daily_outbound_cargo_tonnes numeric,game_season_profile text,
 game_landing_fee_usd numeric,game_parking_per_day_usd numeric,
 game_departing_pax_fee_usd numeric,game_data_status text,
 PRIMARY KEY(world_id,airport_key)
);
CREATE TABLE airlinerra_game.section5_airport_simplified_game_rules_v1(
 world_id smallint NOT NULL,airport_key text NOT NULL,
 nighttime_ban boolean NOT NULL,noise_restrictions boolean NOT NULL,
 permitted_noise_chapters smallint[] NOT NULL,
 simplified_nighttime_window text,source_status text,
 PRIMARY KEY(world_id,airport_key)
);
CREATE TABLE airlinerra_game.airport_group2_admission_readiness_v1(
 airport_key text PRIMARY KEY,ready_for_owner_release_review boolean,
 documented_commercial_prohibition boolean,readiness_status text,
 unresolved_gates text[]);
CREATE TABLE airlinerra_game.airport_group2_operational_releases_v1(
 world_id smallint,airport_key text,release_status text,
 PRIMARY KEY(world_id,airport_key));
CREATE TABLE airlinerra_game.airport_group2_simulation_admissions_v1(
 world_id smallint,airport_key text,admission_scope text,
 PRIMARY KEY(world_id,airport_key));
CREATE TABLE airlinerra_game.airport_reference_profiles(
 world_id smallint,airport_key text,game_municipality text,
 PRIMARY KEY(world_id,airport_key));
CREATE TABLE airlinerra_game.airport_group2_game_profiles_v1(
 airport_key text PRIMARY KEY,game_locality_display text);
-- Source rows remain unchanged by the migration. These cases explicitly
-- exercise both catalog/simplified disagreements, including MUC.
INSERT INTO airlinerra_game.airport_sections1_8_combined_catalog_v1(
 world_id,airport_key,source_group,airport_name,game_lookup_code,country_iso,
 game_runway_length_m,game_nighttime_ban,game_noise_restrictions,
 restriction_basis,game_data_status)
 VALUES
 (1,'MUC','GROUP_1','Munich','MUC','DE',3999.9,true,false,'CATALOG_NIGHT_OBSERVED','game_complete_estimated'),
 (1,'BEG','GROUP_1','Belgrade','BEG','RS',3500,false,false,'NO_GENERAL_GAME_BAN','game_complete_estimated'),
 (1,'MISSING_NIGHT','GROUP_1','Night missing in catalog','NMS','DE',3000,false,false,'CATALOG_CLEAR','game_complete_estimated'),
 (1,'CATALOG_NIGHT','GROUP_1','Night only in catalog','NCL','DE',3000,true,false,'CATALOG_NIGHT_VERIFIED','game_complete_estimated'),
 (1,'MISSING_NOISE','GROUP_1','Noise missing in catalog','NOS','DE',3000,false,false,'CATALOG_CLEAR','game_complete_estimated'),
 (1,'GROUP2_READY','GROUP_2','Approved Group2','G2A','DE',2000,false,false,'GAME_ESTIMATE','game_complete_estimated'),
 (1,'GROUP2_PROHIBITED','GROUP_2','Unapproved Group2','G2N','DE',2000,false,false,'DOCUMENTED_PROHIBITION','game_complete_estimated'),
 (1,'NO_SIMPLIFIED','GROUP_1','No simplified','NON','DE',2000,true,true,'CATALOG_SOURCE_ONLY','game_complete_estimated');
INSERT INTO airlinerra_game.section5_airport_simplified_game_rules_v1
 (world_id,airport_key,nighttime_ban,noise_restrictions,
 permitted_noise_chapters,simplified_nighttime_window,source_status)
VALUES
 (1,'MUC',true,true,ARRAY[3,4]::smallint[],'0:01 and 5:59','AIRLINESIM_PAGE_OBSERVED'),
 (1,'BEG',false,false,ARRAY[]::smallint[],NULL,'AIRLINESIM_PAGE_OBSERVED'),
 (1,'MISSING_NIGHT',true,false,ARRAY[]::smallint[],'0:01 and 5:59','AIRLINESIM_PAGE_OBSERVED'),
 (1,'CATALOG_NIGHT',false,false,ARRAY[]::smallint[],NULL,'AIRLINESIM_PAGE_OBSERVED'),
 (1,'MISSING_NOISE',false,true,ARRAY[3,4]::smallint[],NULL,'AIRLINESIM_PAGE_OBSERVED'),
 (1,'GROUP2_READY',false,false,ARRAY[]::smallint[],NULL,'GAME_DEFAULT_NOT_CHECKED'),
 (1,'GROUP2_PROHIBITED',false,false,ARRAY[]::smallint[],NULL,'GAME_DEFAULT_NOT_CHECKED');
INSERT INTO airlinerra_game.airport_group2_admission_readiness_v1
 VALUES('GROUP2_READY',true,false,'ADMISSION_REVIEW_READY',ARRAY[]::text[]),
 ('GROUP2_PROHIBITED',true,true,'DOCUMENTED_PROHIBITION',
 ARRAY['documented_commercial_prohibition']::text[]);
INSERT INTO airlinerra_game.airport_group2_operational_releases_v1
 VALUES(1,'GROUP2_READY','approved'),(1,'GROUP2_PROHIBITED','approved');
INSERT INTO airlinerra_game.airport_group2_simulation_admissions_v1
 VALUES(1,'GROUP2_READY','GAME_SIMULATION_ONLY'),(1,'GROUP2_PROHIBITED','GAME_SIMULATION_ONLY');
INSERT INTO airlinerra_game.airport_reference_profiles
 SELECT world_id,airport_key,'Test municipality'
 FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 WHERE source_group='GROUP_1';
INSERT INTO airlinerra_game.airport_group2_game_profiles_v1
 VALUES('GROUP2_READY','Test Group2'),('GROUP2_PROHIBITED','Test Forbidden Group2');
-- The real Section 5 simplified GAME leg screen is installed separately,
-- unchanged from migration. Its airport-policy and certification sources are
-- explicitly synthetic and NEVER imply an official aircraft certificate.
CREATE TABLE airlinerra_game.section5_airport_operating_policy_v1(
 world_id smallint,airport_key text,timezone_iana text,
 PRIMARY KEY(world_id,airport_key));
INSERT INTO airlinerra_game.section5_airport_operating_policy_v1
 SELECT world_id,airport_key,
 CASE WHEN airport_key='MUC' THEN 'Europe/Berlin'
      WHEN airport_key='BEG' THEN 'Europe/Belgrade'
      ELSE 'UTC' END
 FROM airlinerra_game.airport_sections1_8_combined_catalog_v1;
CREATE TABLE airlinerra_game.section5_icao_aircraft_certification_v2(
 configuration_id bigint PRIMARY KEY, official_icao_chapter smallint,
 noise_certificate_status text);
INSERT INTO airlinerra_game.section5_icao_aircraft_certification_v2 VALUES
 (16,NULL,'CERTIFICATE_NOT_VERIFIED');
-- Before/after immutable source-value fingerprint.
CREATE TABLE airlinerra_game.fixture_airport_source_hashes AS
 SELECT 'catalog'::text AS source,md5(string_agg(to_jsonb(t)::text,'|' ORDER BY airport_key)) AS digest
 FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 t
 UNION ALL
 SELECT 'simplified',md5(string_agg(to_jsonb(t)::text,'|' ORDER BY airport_key))
 FROM airlinerra_game.section5_airport_simplified_game_rules_v1 t;
