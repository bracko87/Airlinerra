-- Airlinerra Germany Batch05 acceptance tests, verified PASS in private Supabase Oct26 2026.
DO $audit$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_05_2026_10_26')<>8
 OR (SELECT count(*) FROM airlinerra.airport_expansion_operator_runway_source_issues
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_05_2026_10_26')<>2
 THEN RAISE EXCEPTION 'Expected 8 source reviews and 2 research holds'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_05_2026_10_26'
 AND r.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.identity_status='VERIFIED' AND a.paved_runway_status='VERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>6
 THEN RAISE EXCEPTION 'Six qualifying runway operator source reviews required'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_operator_runway_source_issues e
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE e.batch_key='EXPANSION_DE_PAVED_BATCH_05_2026_10_26'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.paved_runway_status='UNVERIFIED'
 AND e.game_admission_status='NOT_APPROVED')<>2
 THEN RAISE EXCEPTION 'EDTD/EDTF source exceptions must remain held'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_operator_runway_source_issues
 WHERE icao_code='EDTD' AND operator_reported_physical_m=1200
 AND source_landing_a_m=1290 AND source_landing_b_m=1200
 AND historic_registry_runway_m=1289.9)
 THEN RAISE EXCEPTION 'EDTD published physical runway vs LDA contradiction lost'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_operator_runway_source_issues
 WHERE icao_code='EDTF' AND source_landing_a_m=1190 AND source_landing_b_m=1040
 AND historic_registry_runway_m=1338.1)
 THEN RAISE EXCEPTION 'EDTF sub-1200m usable landing directions not recorded'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDTY' AND documented_physical_length_m=1540
 AND documented_width_m=30 AND normalized_surface='CONCRETE'
 AND published_landing_direction_a_m=1365 AND published_landing_direction_b_m=1413)
 THEN RAISE EXCEPTION 'EDTY operator runway/landing distance record missing';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>1795
 THEN RAISE EXCEPTION 'Expansion source verification queue must be 1795';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>12
 THEN RAISE EXCEPTION 'Germany generic source hold queue must be 12';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_05_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED' OR simulation_world_active))
 THEN RAISE EXCEPTION 'Research entries must never be gameplay-approved';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w
 JOIN airlinerra.airport_cohorts c USING(airport_key) WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'Original 3140 World1 inventory or registration source changed';END IF;
 IF EXISTS(SELECT 1 FROM pg_class p JOIN pg_namespace n ON n.oid=p.relnamespace
 WHERE n.nspname='airlinerra' AND p.relname='airport_expansion_operator_runway_source_issues'
 AND (NOT p.relrowsecurity OR has_table_privilege('anon',p.oid,'SELECT')
 OR has_table_privilege('authenticated',p.oid,'SELECT')))
 THEN RAISE EXCEPTION 'Operator issue research table exposed';END IF;
END $audit$;
SELECT 'PASS' AS germany_batch05_acceptance;
