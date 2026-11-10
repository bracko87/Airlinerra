-- Group2 1,118 owner-preapproved airport cohort: rollback-only acceptance.
-- This suite reads only and must not add airports to World1 or change money.
BEGIN;
DO $check$
DECLARE counts integer;section_no integer;view_name text;view_rows integer;
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_candidate_preapproval_pool
  WHERE decision_status='PRE_APPROVED' AND reviewed_by='OWNER_CHECKLIST')<>1118
 THEN RAISE EXCEPTION 'GROUP2_OWNER_SET_CHANGED';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_source_runways_v1)<>1828
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_data_section_acceptance_v1)<>8
 THEN RAISE EXCEPTION 'GROUP2_ROSTER_RUNWAYS_OR_SECTIONS_MISSING';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE owner_category='Local')<>754
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE owner_category='Regional')<>338
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE owner_category='Medium')<>26
 THEN RAISE EXCEPTION 'GROUP2_OWNER_CATEGORIES_NOT_PRESERVED';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE game_traffic_type='Passenger')<>953
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE game_traffic_type='Cargo')<>43
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE game_traffic_type='Both')<>122
 THEN RAISE EXCEPTION 'GROUP2_OWNER_TRAFFIC_TYPES_CHANGED';END IF;
 IF EXISTS(
 SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 g
 FULL JOIN airlinerra.airport_candidate_preapproval_pool c
 ON c.airport_key=g.airport_key
 WHERE g.airport_key IS NULL OR c.airport_key IS NULL OR
   g.owner_category IS DISTINCT FROM c.approved_category OR
   g.game_traffic_type IS DISTINCT FROM c.traffic_type
 )
 THEN RAISE EXCEPTION 'GROUP2_NOT_EXACT_OWNER_PREAPPROVAL_SNAPSHOT';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
     WHERE source_municipality IS NULL OR btrim(source_municipality)='')<>41
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
     WHERE runway_width_game_basis='CATEGORY_MEDIAN_GAME_WIDTH_ESTIMATE')<>20
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
     WHERE detailed_runway_observation_count=0)<>9
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
     WHERE timezone_game_basis='UA_COUNTRY_GAME_ESTIMATE')<>11
 THEN RAISE EXCEPTION 'GROUP2_GAPS_INACCURATELY_PROMOTED_TO_VERIFIED';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
    WHERE country_iso !~ '^[A-Z]{2}$' OR game_airport_name IS NULL
    OR latitude_deg IS NULL OR longitude_deg IS NULL
    OR timezone_iana IS NULL OR game_lookup_code IS NULL
    OR runway_registry_qualified_length_m<1200
    OR game_runway_width_m<=0
    OR game_terminal_stands+game_remote_stands+game_cargo_stands<=0
    OR game_landing_fee_usd<=0 OR game_parking_per_day_usd<=0
    OR game_departing_pax_fee_usd<=0)<>0
 THEN RAISE EXCEPTION 'GROUP2_REQUIRED_GAME_MODEL_FIELDS_MISSING';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
  WHERE game_nighttime_ban IS NOT NULL OR game_noise_restrictions IS NOT NULL
   OR commercial_playable OR commercial_access_verified
   OR background_verified OR game_airport_background<>'standard')
 THEN RAISE EXCEPTION 'GROUP2_SOURCE_UNKNOWN_MISREPRESENTED_AS_REAL_CLEARANCE';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE game_traffic_type='Cargo' AND
     (game_daily_outbound_passengers<>0 OR game_cargo_stands=0))<>0
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE game_traffic_type='Passenger' AND
     (game_daily_outbound_cargo_tonnes<>0 OR game_cargo_stands<>0))<>0
 THEN RAISE EXCEPTION 'GROUP2_TRAFFIC_MODEL_INCONSISTENT';END IF;
 FOR section_no IN 1..8 LOOP
  view_name:='airport_group2_section'||section_no||'_'||
   (ARRAY['identity','classification','runways','facilities',
         'restrictions','capacity','demand','economics'])[section_no]||'_v1';
  EXECUTE format('SELECT count(*) FROM airlinerra_game.%I',view_name)
    INTO view_rows;
  IF view_rows<>1118 THEN
   RAISE EXCEPTION 'GROUP2_SECTION_VIEW_%_NOT_1118: %',
      section_no,view_rows;END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section8_economics_v1
  WHERE terminal_stand_multiplier<=remote_stand_multiplier OR
     cargo_handling_per_tonne_usd<=0 OR
     game_landing_fee_usd<=0)
 THEN RAISE EXCEPTION 'GROUP2_PRICE_OR_STAND_RULES_MISSING';END IF;
 IF has_table_privilege('anon','airlinerra_game.airport_group2_game_profiles_v1','SELECT')
 OR has_table_privilege('authenticated','airlinerra_game.airport_group2_game_profiles_v1','INSERT')
 OR has_table_privilege('authenticated','airlinerra_game.airport_group2_source_runways_v1','SELECT')
 OR has_table_privilege('anon','airlinerra_game.airport_group2_game_data_section_acceptance_v1','SELECT')
 THEN RAISE EXCEPTION 'GROUP2_PRIVATE_AIRPORT_SOURCE_DATA_EXPOSED';END IF;
 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports a
  JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
  WHERE a.world_id=1)
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 OR EXISTS(SELECT 1 FROM airlinerra.airport_candidate_preapproval_pool
      WHERE promoted_at IS NOT NULL)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1)
 THEN RAISE EXCEPTION 'GROUP1_PRESERVATION_OR_OPERATIONAL_GATE_VIOLATION';END IF;
 RAISE NOTICE 'PASS Group2 1118: Sections1-8 modelled, 1828 source runways, 41 municipality gaps, 20 width estimates, 9 missing detailed observations, 11 UA timezone assumptions; Group1=3141 unchanged; 0 playable/real licence or flights';
END $check$;
ROLLBACK;
