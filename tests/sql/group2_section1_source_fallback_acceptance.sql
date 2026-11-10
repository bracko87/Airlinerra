-- Group 2 Section 1: rollback-only identity and provenance acceptance.
-- Primary operator sources and secondary AirlineSim code comparisons MUST NOT
-- alter source registry, approval, game geometry or operational status.
BEGIN;
DO $test$
DECLARE rejected boolean; first_airport text;
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_identity_quality_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1)<>9
 OR (SELECT count(DISTINCT airport_key) FROM
  airlinerra_game.airport_group2_section1_source_candidates_v1)<>5
 THEN RAISE EXCEPTION 'SECTION1_GROUP2_COVERAGE_OR_CANDIDATE_COUNT_BAD';END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_section1_source_candidates_v1
  WHERE independently_authority_verified OR may_replace_game_profile
    OR operational_or_commercial_authority)
 THEN RAISE EXCEPTION 'SECTION1_PRELIMINARY_DATA_NOT_FAIL_CLOSED';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1
  WHERE source_kind='OFFICIAL_AIRPORT_OPERATOR'
  AND identity_field='served_city'
  AND review_status='PRIMARY_SOURCE_CANDIDATE_NEEDS_INDEPENDENT_REVIEW')<>3
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1
  WHERE source_kind='AIRLINESIM_THIRD_PARTY_SIMULATION'
  AND identity_field IN('iata_reference','icao_reference')
  AND review_status='SIMULATION_COMPARISON_ONLY')<>6
 THEN RAISE EXCEPTION 'SECTION1_PRIMARY_SECONDARY_SOURCE_CLASSIFICATION_WRONG';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_source_candidates_v1 s
  JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
  WHERE s.identity_field='icao_reference'
  AND s.source_kind='AIRLINESIM_THIRD_PARTY_SIMULATION'
  AND s.proposed_value IS DISTINCT FROM g.source_ident)
 THEN RAISE EXCEPTION 'SECTION1_AIRLINESIM_ICAO_DIFFERENCE_NOT_FLAGGED';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_source_candidates_v1
  WHERE source_kind='AIRLINESIM_THIRD_PARTY_SIMULATION'
   AND identity_field='served_city')<>0
 THEN RAISE EXCEPTION 'AIRLINESIM_INVENTED_MUNICIPALITY';END IF;

 IF (SELECT source_municipalities_missing FROM airlinerra_game.airport_group2_section1_progress_v1)<>41
 OR (SELECT missing_city_with_primary_candidate FROM airlinerra_game.airport_group2_section1_progress_v1)<>3
 OR (SELECT missing_city_without_primary_candidate FROM airlinerra_game.airport_group2_section1_progress_v1)<>38
 OR (SELECT source_gps_codes_missing FROM airlinerra_game.airport_group2_section1_progress_v1)<>2
 OR (SELECT game_timezones_not_authority_verified FROM airlinerra_game.airport_group2_section1_progress_v1)<>1118
 OR (SELECT game_zero_elevation_fallbacks FROM airlinerra_game.airport_group2_section1_progress_v1)<>11
 OR (SELECT authority_verified_section1_airports FROM airlinerra_game.airport_group2_section1_progress_v1)<>0
 THEN RAISE EXCEPTION 'SECTION1_SOURCE_GAPS_HIDDEN_OR_FABRICATED';END IF;

 IF EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
  WHERE airport_key IN('OURAIRPORTS:26916','OURAIRPORTS:27866','OURAIRPORTS:26969')
   AND source_municipality IS NOT NULL)
 THEN RAISE EXCEPTION 'SECTION1_UNREVIEWED_LOCALITY_OVERWROTE_CANONICAL_SOURCE';END IF;

 IF has_table_privilege('anon','airlinerra_game.airport_group2_section1_source_candidates_v1','SELECT')
 OR has_table_privilege('authenticated','airlinerra_game.airport_group2_section1_source_candidates_v1','INSERT')
 OR has_table_privilege('authenticated','airlinerra_game.airport_group2_section1_identity_quality_v1','SELECT')
 THEN RAISE EXCEPTION 'SECTION1_UNREVIEWED_RESEARCH_EXPOSED_TO_BROWSER';END IF;

 rejected:=false;
 BEGIN
  INSERT INTO airlinerra_game.airport_group2_section1_source_candidates_v1(
   airport_key,identity_field,proposed_value,source_kind,publisher,
   source_url,statement_context,review_status)
  VALUES('OURAIRPORTS:27866','served_city','Onslow',
   'AIRLINESIM_THIRD_PARTY_SIMULATION','AirlineSim by simulogics',
   'https://example.invalid/synthetic-simulation-row',
   'Rollback-only test that must refuse a game site as municipality source.',
   'SIMULATION_COMPARISON_ONLY');
 EXCEPTION WHEN SQLSTATE '23514' THEN rejected:=true; END;
 IF NOT rejected THEN RAISE EXCEPTION 'SECTION1_AIRLINESIM_CITY_GATE_BYPASS';END IF;

 rejected:=false;
 BEGIN
  UPDATE airlinerra_game.airport_group2_section1_source_candidates_v1
  SET may_replace_game_profile=true WHERE airport_key='OURAIRPORTS:27866';
 EXCEPTION WHEN SQLSTATE '42501' THEN rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'SECTION1_RESEARCH_WAS_MUTABLE';END IF;

 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_review_evidence_events_v1)<>0
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_admission_readiness_v1
  WHERE can_activate_flights)
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>0
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'SECTION1_FALLBACK_CHANGED_PLAYABLE_GAME_STATE';END IF;
 RAISE NOTICE 'PASS SECTION1 Group2: 1118 identities, 41 unknown source municipalities, 3 operator city candidates, 6 AirlineSim codes comparison-only, all 1118 timezones estimated, no game admission';
END $test$;
ROLLBACK;
