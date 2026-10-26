-- Executed PASS against private Supabase on 2026-10-26; game-world activation unchanged.
DO $test$
BEGIN
 IF (SELECT COUNT(*) FROM airlinerra.airport_expansion_de_batch10_multisource_runway_screen WHERE batch_key='EXPANSION_DE_PHYSICAL_SCREEN_BATCH_10_2026_10_26')<>3
 THEN RAISE EXCEPTION 'Batch10 expected 3 physical-runway research records'; END IF;
 IF (SELECT COUNT(*) FROM airlinerra.airport_expansion_de_batch10_multisource_runway_screen s JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE s.batch_key='EXPANSION_DE_PHYSICAL_SCREEN_BATCH_10_2026_10_26'
 AND s.physical_paved_screen='CORROBORATED_GEOMETRY_REQUIRES_EFFECTIVE_AIP_REVALIDATION'
 AND s.physical_paved_runway_m>=1200
 AND s.normalized_surface IN('ASPHALT','CONCRETE')
 AND s.latest_effective_aip_verified=false
 AND s.aircraft_specific_operating_permission=false
 AND s.game_admission_status='NOT_APPROVED'
 AND s.game_world_activation_authorized=false
 AND a.review_status='INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.identity_status='VERIFIED' AND a.paved_runway_status='VERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>3
 THEN RAISE EXCEPTION 'Batch10 three physical-only advances lacked correct source and permission safeguards'; END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_expansion_de_batch10_multisource_runway_screen
 WHERE airport_code='EDAK' AND physical_paved_runway_m=1415 AND physical_width_m=48 AND normalized_surface='CONCRETE'
 AND latest_effective_aip_verified=false)
 OR NOT EXISTS (SELECT 1 FROM airlinerra.airport_expansion_de_batch10_multisource_runway_screen
 WHERE airport_code='EDTF' AND physical_paved_runway_m=1240 AND alternative_published_physical_m=1400
 AND published_end_a_lda_m=1190 AND published_end_b_lda_m=1040 AND latest_effective_aip_verified=false)
 OR NOT EXISTS (SELECT 1 FROM airlinerra.airport_expansion_de_batch10_multisource_runway_screen
 WHERE airport_code='EDXF' AND physical_paved_runway_m=1220 AND physical_width_m=30
 AND published_end_a_lda_m=1220 AND published_end_b_lda_m=1040
 AND latest_effective_aip_verified=false)
 THEN RAISE EXCEPTION 'EDAK/EDTF/EDXF source geometry or landing-direction restrictions lost'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>0
 THEN RAISE EXCEPTION 'German general independent runway evidence queue is not empty'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status IN('INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 'INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'))<>41
 THEN RAISE EXCEPTION 'German 41 physically screened runway candidates mismatched'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status IN('HOLD_OPERATOR_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT',
 'HOLD_CIVIL_RUNWAY_USABLE_DISTANCE_1140M',
 'HOLD_TEMPORARY_EDCP_AERODROME_CLOSURE_NOTAM_E4380_26'))<>3
 THEN RAISE EXCEPTION 'Three named German technical/temporary holds changed'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>1783
 THEN RAISE EXCEPTION 'Worldwide generic expansion hold count not 1783'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE world_number=1 AND active)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w JOIN airlinerra.airport_cohorts c USING(airport_key) WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'Authorized founding World 1 airport membership changed'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_batch10_multisource_runway_screen
 WHERE latest_effective_aip_verified OR aircraft_specific_operating_permission
 OR game_admission_status<>'NOT_APPROVED' OR game_world_activation_authorized)
 THEN RAISE EXCEPTION 'Research table falsely claims AIP/airline/game approval'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='airlinerra' AND c.relname='airport_expansion_de_batch10_multisource_runway_screen'
 AND c.relrowsecurity AND NOT has_table_privilege('anon',c.oid,'SELECT')
 AND NOT has_table_privilege('authenticated',c.oid,'SELECT'))
 THEN RAISE EXCEPTION 'Private research evidence leaked'; END IF;
END $test$;
SELECT 'PASS' AS de_batch10_source_audit;
