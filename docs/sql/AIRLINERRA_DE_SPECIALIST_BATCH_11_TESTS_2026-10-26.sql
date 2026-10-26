-- Applied Supabase research change acceptance: executed PASS on 2026-10-26.
-- Airlinerra German expansion specialist Batch11 acceptance test.
DO $assert$
BEGIN
 IF (SELECT COUNT(*) FROM airlinerra.airport_expansion_de_specialist_batch11_decisions
 WHERE batch_key='EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26')<>3
 THEN RAISE EXCEPTION 'Exactly three specialist cases required'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_specialist_batch11_decisions d
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE d.batch_key='EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26' AND d.airport_code='EDMB'
 AND d.decision='PROVISIONAL_BELOW_1200_OPERATOR_RUNWAY_AIP_RECONCILIATION'
 AND d.operator_or_source_physical_m=980 AND d.historical_registry_length_m=1314.9
 AND d.direction_a_lda_m=780 AND d.direction_b_lda_m=980
 AND d.physical_collection_screen_pass=false
 AND a.review_status='HOLD_OPERATOR_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT'
 AND a.paved_runway_status='UNVERIFIED' AND a.game_admission_status='NOT_APPROVED')
 THEN RAISE EXCEPTION 'EDMB source-primary 980m runway provisional failure missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_specialist_batch11_decisions d
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 JOIN airlinerra.airport_expansion_german_civil_runway_end_holds h ON h.airport_key=d.airport_key AND h.icao_code='EDXJ'
 WHERE d.batch_key='EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26' AND d.airport_code='EDXJ'
 AND d.decision='PHYSICAL_PAVED_RUNWAY_PASS_CIVIL_LDA_1140_BOTH_ENDS'
 AND d.operator_or_source_physical_m=1450
 AND d.direction_a_lda_m=1140 AND d.direction_b_lda_m=1140 AND d.physical_collection_screen_pass=true
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.paved_runway_status='VERIFIED' AND a.game_admission_status='NOT_APPROVED'
 AND h.source_landing_end_a_m=1140 AND h.source_landing_end_b_m=1140 AND h.game_admission_status='NOT_APPROVED'
 AND h.game_world_activated=false)
 THEN RAISE EXCEPTION 'EDXJ runway collection must advance but remain civil-direction restricted';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_specialist_batch11_decisions d
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 JOIN airlinerra.airport_expansion_de_temp_airfield_closure_watch n ON n.airport_key=d.airport_key
 WHERE d.batch_key='EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26' AND d.airport_code='EDCP'
 AND d.decision='PHYSICAL_PAVED_RUNWAY_CORROBORATED_TEMP_NOTAM_HOLD'
 AND d.operator_or_source_physical_m=2400 AND d.physical_collection_screen_pass=true
 AND d.notam_reference='E4380/26' AND d.revisit_on='2026-11-01'
 AND n.notam_reference='E4380/26' AND n.followup_utc_date='2026-11-01'
 AND n.reported_end_utc='2026-10-31 17:00:00'
 AND a.review_status='HOLD_TEMPORARY_EDCP_AERODROME_CLOSURE_NOTAM_E4380_26'
 AND a.paved_runway_status='UNVERIFIED' AND a.game_admission_status='NOT_APPROVED')
 THEN RAISE EXCEPTION 'EDCP temporary E4380/26 hold / expiry check missing';END IF;
 IF (SELECT COUNT(*) FROM airlinerra.airport_access_reviews a JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING')<>35
 OR (SELECT COUNT(*) FROM airlinerra.airport_access_reviews a JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status='INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING')<>7
 OR (SELECT COUNT(*) FROM airlinerra.airport_access_reviews a JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status IN('HOLD_OPERATOR_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT','HOLD_TEMPORARY_EDCP_AERODROME_CLOSURE_NOTAM_E4380_26'))<>2
 THEN RAISE EXCEPTION 'Germany 42 source-advanced / 2 specialist-held status totals mismatch';END IF;
 IF EXISTS (SELECT 1 FROM airlinerra.airport_expansion_de_specialist_batch11_decisions
 WHERE batch_key='EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED' OR game_activation_authorized OR aircraft_flight_approval OR latest_effective_aip_verified))
 THEN RAISE EXCEPTION 'Specialist research accidentally claims actual airline/game or current official AIP permission';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w JOIN airlinerra.airport_cohorts c USING(airport_key) WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'Owner-authorized initial World1 game airport catalog mutated';END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_class pc JOIN pg_namespace ns ON ns.oid=pc.relnamespace
 WHERE ns.nspname='airlinerra' AND pc.relname='airport_expansion_de_specialist_batch11_decisions'
 AND pc.relrowsecurity AND NOT has_table_privilege('anon',pc.oid,'SELECT')
 AND NOT has_table_privilege('authenticated',pc.oid,'SELECT'))
 THEN RAISE EXCEPTION 'Private three-case research table is exposed';END IF;
END $assert$;
SELECT 'PASS' AS de_specialist_batch11_test;
