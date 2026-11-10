-- Group 2 Section1 acceptance. ROLLBACK ONLY; no source edits or game changes.
BEGIN;
DO $t$
DECLARE n integer;bad boolean;
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT count(DISTINCT airport_key) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT count(DISTINCT batch_number) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>23
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_batch_acceptance_v1)<>23
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_batch_completion_v1)<>23
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_identity_v1)<>1118
 THEN RAISE EXCEPTION 'SECTION1_ALL_1118_NOT_COVERED_IN_23_BATCHES';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_batch_completion_v1
   WHERE (batch_number<=22 AND airports<>50)
   OR (batch_number=23 AND airports<>18)
   OR game_complete<>airports
   OR game_data_result<>'game_complete_estimated'
   OR independent_source_verification_complete
   OR live_airport_operations_enabled)
 THEN RAISE EXCEPTION 'SECTION1_BATCH_SIZE_GAME_COMPLETENESS_INCONSISTENT';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_batch_acceptance_v1 a
 JOIN airlinerra_game.airport_group2_section1_batch_completion_v1 live USING(batch_number)
 WHERE a.airports<>live.airports OR a.complete_game_profiles<>live.game_complete
  OR a.original_source_municipalities_missing<>live.source_municipality_missing
  OR a.game_airport_name_locality_fallbacks<>live.airport_name_fallbacks
  OR a.original_gps_codes_missing<>live.missing_source_gps
  OR a.game_timezones_corrected<>live.corrected_game_timezones
  OR a.zero_elevation_fallbacks<>live.zero_elevation_game_fallbacks)
 THEN RAISE EXCEPTION 'SECTION1_FROZEN_ACCEPTANCE_DOES_NOT_MATCH_LIVE_READ_MODEL';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1
   WHERE section1_game_data_complete)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_game_registry_v1
   WHERE game_airport_name IS NULL OR game_navigation_code IS NULL
   OR game_locality_label IS NULL OR country_iso IS NULL
   OR latitude_deg IS NULL OR longitude_deg IS NULL
   OR game_timezone_iana IS NULL OR game_elevation_ft IS NULL)
 THEN RAISE EXCEPTION 'SECTION1_UNUSABLE_GAME_RECORD';END IF;
 IF (SELECT count(DISTINCT game_navigation_code) FROM
   airlinerra_game.airport_group2_section1_game_registry_v1)<>1118
 OR (SELECT count(DISTINCT original_source_ident) FROM
   airlinerra_game.airport_group2_section1_game_registry_v1)<>1118
 THEN RAISE EXCEPTION 'SECTION1_DUPLICATE_LOOKUP_OR_SOURCE_IDENT';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1
   WHERE source_municipality_missing)<>41
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1
   WHERE game_locality_basis='OFFICIAL_OPERATOR_SERVED_CITY_CANDIDATE_UNVERIFIED')<>24
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1
   WHERE game_locality_basis='AIRPORT_NAME_GAME_FALLBACK_NOT_REAL_MUNICIPALITY')<>17
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1
   WHERE source_gps_code_missing)<>2
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1
   WHERE zero_elevation_fallback)<>11
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_game_registry_v1
   WHERE state_rule_game_timezone_corrected)<>5
 THEN RAISE EXCEPTION 'SECTION1_GAME_ESTIMATES_WRONGLY_CLAIMED_SOURCE_VERIFIED';END IF;
 IF (SELECT game_data_result FROM airlinerra_game.airport_group2_section1_overall_status_v1)
   <>'game_complete_estimated'
 OR (SELECT group2_airports FROM airlinerra_game.airport_group2_section1_overall_status_v1)<>1118
 OR (SELECT game_complete_airports FROM airlinerra_game.airport_group2_section1_overall_status_v1)<>1118
 OR (SELECT batches FROM airlinerra_game.airport_group2_section1_overall_status_v1)<>23
 OR (SELECT source_verified_complete FROM airlinerra_game.airport_group2_section1_overall_status_v1)
 OR (SELECT commercial_flight_access_enabled FROM airlinerra_game.airport_group2_section1_overall_status_v1)
 THEN RAISE EXCEPTION 'SECTION1_FALSE_COMPLETION_OR_FLIGHT_AUTHORITY';END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_game_registry_v1 r
 JOIN airlinerra_game.airport_group2_section1_game_timezone_overrides_v1 tz USING(airport_key)
 WHERE r.game_timezone_iana IS DISTINCT FROM tz.resolved_game_timezone_iana
  OR tz.allowed_for_live_flights OR tz.independently_airport_verified)
 THEN RAISE EXCEPTION 'SECTION1_FIVE_AU_TIMEZONE_CORRECTIONS_NOT_USED_OR_FALSELY_CERTIFIED';END IF;
 IF (SELECT timezone_iana FROM airlinerra_game.airport_group2_section1_identity_v1
  WHERE airport_key='OURAIRPORTS:26990')<>'Australia/Brisbane'
 OR (SELECT timezone_iana FROM airlinerra_game.airport_group2_section1_identity_v1
  WHERE airport_key='OURAIRPORTS:27110')<>'Australia/Darwin'
 OR (SELECT timezone_iana FROM airlinerra_game.airport_group2_section1_identity_v1
  WHERE airport_key='OURAIRPORTS:27125')<>'Australia/Adelaide'
 THEN RAISE EXCEPTION 'SECTION1_STANDARD_GAME_INTERFACE_STILL_USING_BAD_AU_TIMEZONES';END IF;
 IF (SELECT timezone_iana FROM airlinerra_game.airport_group2_game_profiles_v1
  WHERE airport_key='OURAIRPORTS:26990')<>'Australia/Sydney'
 THEN RAISE EXCEPTION 'SECTION1_UNREVIEWED_SOURCE_SNAPSHOT_OVERWRITTEN';END IF;

 IF has_table_privilege('anon','airlinerra_game.airport_group2_fixed_batch_members_v1','SELECT')
 OR has_table_privilege('authenticated','airlinerra_game.airport_group2_fixed_batch_members_v1','UPDATE')
 OR has_table_privilege('authenticated','airlinerra_game.airport_group2_section1_game_registry_v1','SELECT')
 OR has_table_privilege('authenticated','airlinerra_game.airport_group2_section1_batch_acceptance_v1','INSERT')
 OR has_table_privilege('anon','airlinerra_game.airport_group2_section1_overall_status_v1','SELECT')
 THEN RAISE EXCEPTION 'SECTION1_INTERNAL_BATCH_OR_SOURCE_DATA_EXPOSED_TO_PLAYERS';END IF;
 bad:=false;
 BEGIN
  DELETE FROM airlinerra_game.airport_group2_fixed_batch_members_v1 WHERE batch_number=23;
 EXCEPTION WHEN SQLSTATE '42501' THEN bad:=true;END;
 IF NOT bad THEN RAISE EXCEPTION 'SECTION1_BATCH_ASSIGNMENT_MUTABLE';END IF;
 bad:=false;
 BEGIN
  UPDATE airlinerra_game.airport_group2_section1_batch_acceptance_v1
  SET complete_game_profiles=0 WHERE batch_number=1;
 EXCEPTION WHEN SQLSTATE '42501' THEN bad:=true;END;
 IF NOT bad THEN RAISE EXCEPTION 'SECTION1_BATCH_ACCEPTANCE_MUTABLE';END IF;

 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_review_evidence_events_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
  WHERE commercial_playable)<>0
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>0
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'SECTION1_GROUP1_OR_OPERATIONAL_GATE_CHANGED';END IF;
 RAISE NOTICE 'PASS Group2 Section1 game_complete_estimated 1118/1118 in 23 batches (22x50 +18); 5 AU game clock fixes, 41 source municipality gaps, 2 source GPS gaps, 11 elevation estimates. No real commercial release.';
END $t$;
ROLLBACK;
