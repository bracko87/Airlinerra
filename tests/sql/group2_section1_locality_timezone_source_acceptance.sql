-- Group2 Section1: independent source quality/regression. All tests rollback.
BEGIN;
DO $accept$
DECLARE b integer;test_key text;old_elev numeric;new_elev numeric; block_flag boolean;
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1)<>37
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1
  WHERE source_kind='AIRLINESIM_THIRD_PARTY_SIMULATION')<>6
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1
  WHERE source_kind<>'AIRLINESIM_THIRD_PARTY_SIMULATION')<>31
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1
  WHERE identity_field='served_city' AND source_kind<>'AIRLINESIM_THIRD_PARTY_SIMULATION')<>24
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1
  WHERE identity_field='elevation_reference' AND source_kind<>'AIRLINESIM_THIRD_PARTY_SIMULATION')<>7
 THEN RAISE EXCEPTION 'GROUP2_S1_PUBLIC_SOURCE_COUNT_WRONG';END IF;

 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_identity_quality_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_identity_quality_v1
  WHERE source_municipality_missing)<>41
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_identity_quality_v1
  WHERE source_municipality_missing AND served_city_primary_candidates>0)<>24
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_identity_quality_v1
  WHERE source_municipality_missing AND served_city_primary_candidates=0)<>17
 OR (SELECT source_gps_codes_missing
  FROM airlinerra_game.airport_group2_section1_progress_v1)<>2
 OR (SELECT game_timezones_not_authority_verified
  FROM airlinerra_game.airport_group2_section1_progress_v1)<>1118
 THEN RAISE EXCEPTION 'GROUP2_S1_STILL_UNRESOLVED_GAPS_WERE_LOST';END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_source_candidates_v1 s
  WHERE s.independently_authority_verified OR s.may_replace_game_profile
   OR s.operational_or_commercial_authority)
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_source_candidates_v1 s
  WHERE s.source_kind='AIRLINESIM_THIRD_PARTY_SIMULATION'
   AND (s.review_status<>'SIMULATION_COMPARISON_ONLY'
      OR s.identity_field NOT IN('iata_reference','icao_reference')))
 THEN RAISE EXCEPTION 'GROUP2_S1_SIMULATION_SOURCE_PROMOTED';END IF;

 IF EXISTS(
 SELECT 1 FROM airlinerra_game.airport_group2_section1_source_candidates_v1 c
 JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
 WHERE c.identity_field='served_city' AND g.source_municipality IS NOT NULL)
 THEN RAISE EXCEPTION 'GROUP2_S1_UNREVIEWED_CITY_WROTE_SOURCE_MUNICIPALITY';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1)<>5
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_timezone_discrepancy_v1)<>5
 THEN RAISE EXCEPTION 'GROUP2_S1_TIMEZONE_ANOMALIES_NOT_PRESERVED';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1 t
 JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
 WHERE t.source_game_timezone_iana IS DISTINCT FROM g.timezone_iana
  OR t.applied_to_canonical_game_profile
  OR t.authority_verified_for_flight_schedule)
 THEN RAISE EXCEPTION 'GROUP2_S1_TIMEZONE_ESTIMATE_REPLACED_BY_CANDIDATE';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_timezone_discrepancy_v1
 WHERE current_vs_expected_offset_minutes_on_nov10<>0 OR
       current_vs_expected_offset_minutes_on_jun10<>0)<>5
 THEN RAISE EXCEPTION 'GROUP2_S1_5_MATERIAL_TIMEZONE_ERRORS_NOT_DETECTED';END IF;
 IF (SELECT current_vs_expected_offset_minutes_on_nov10 FROM
    airlinerra_game.airport_group2_section1_timezone_discrepancy_v1
    WHERE airport_key='OURAIRPORTS:26990')<>60
 OR (SELECT current_vs_expected_offset_minutes_on_nov10 FROM
    airlinerra_game.airport_group2_section1_timezone_discrepancy_v1
    WHERE airport_key='OURAIRPORTS:27110')<>-90
 OR (SELECT current_vs_expected_offset_minutes_on_nov10 FROM
    airlinerra_game.airport_group2_section1_timezone_discrepancy_v1
    WHERE airport_key='OURAIRPORTS:27094')<>-30
 THEN RAISE EXCEPTION 'GROUP2_S1_DST_EFFECT_BAD';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1
 WHERE source_url NOT LIKE 'https://%')
 THEN RAISE EXCEPTION 'GROUP2_S1_TIMEZONE_OFFICIAL_SOURCE_MISSING';END IF;

 -- All proposed elevations differ from the old inaccurate nearest-airport estimate.
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1 c
 JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
 WHERE c.identity_field='elevation_reference'
  AND g.game_elevation_ft IS DISTINCT FROM c.proposed_value::numeric)<>7
 THEN RAISE EXCEPTION 'GROUP2_S1_PUBLISHED_ELEVATION_NOT_PRESERVED_SEPARATELY';END IF;

 IF has_table_privilege('anon',
  'airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1','SELECT')
 OR has_table_privilege('authenticated',
  'airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1','INSERT')
 OR has_table_privilege('authenticated',
  'airlinerra_game.airport_group2_section1_official_source_progress_v1','SELECT')
 THEN RAISE EXCEPTION 'GROUP2_S1_SOURCE_PRIVATE_RLS_BYPASS';END IF;

 block_flag:=false;
 BEGIN
  DELETE FROM airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1
  WHERE airport_key='OURAIRPORTS:26990';
 EXCEPTION WHEN SQLSTATE '42501' THEN block_flag:=true;END;
 IF NOT block_flag THEN RAISE EXCEPTION 'GROUP2_S1_TIMEZONE_PROPOSALS_MUTABLE';END IF;

 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_review_evidence_events_v1)<>0
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_admission_readiness_v1
  WHERE can_activate_flights OR ready_for_owner_release_review)
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>0
 THEN RAISE EXCEPTION 'GROUP2_S1_SOURCE_RESEARCH_CHANGED_WORLD_OR_FLIGHTS';END IF;
 RAISE NOTICE 'PASS Section1: 24 primary locality candidates, 17 remain, 7 official elevation discrepancies, 5 timezone mismatches with DST, Group1 unchanged, no flight activation';
END $accept$;
ROLLBACK;
