-- Airlinerra German expansion Batch 04 research acceptance tests.
-- Executed PASS on 2026-10-26 in private Supabase.
DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_04_2026_10_26')<>8
 THEN RAISE EXCEPTION 'Expected eight reviews';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_04_2026_10_26'
 AND r.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.identity_status='VERIFIED' AND a.paved_runway_status='VERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>7
 THEN RAISE EXCEPTION 'Seven source-backed advances expected';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.icao_code='EDMO' AND r.batch_key='EXPANSION_DE_PAVED_BATCH_04_2026_10_26'
 AND r.source_authority_grade='SECONDARY_ONLY_CURRENT'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION' AND a.game_admission_status='NOT_APPROVED')
 THEN RAISE EXCEPTION 'Oberpfaffenhofen must remain source-held';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDMS' AND batch_key='EXPANSION_DE_PAVED_BATCH_04_2026_10_26'
 AND documented_physical_length_m=1350
 AND published_landing_direction_a_m=1250 AND published_landing_direction_b_m=1350)
 THEN RAISE EXCEPTION 'Straubing runway strip conflated with pavement or landing distances';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDQG' AND batch_key='EXPANSION_DE_PAVED_BATCH_04_2026_10_26'
 AND published_landing_direction_a_m=1847 AND published_landing_direction_b_m=1882)
 THEN RAISE EXCEPTION 'Giebelstadt end-specific landing distances missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDRY' AND batch_key='EXPANSION_DE_PAVED_BATCH_04_2026_10_26'
 AND documented_physical_length_m=1677 AND published_landing_direction_a_m=1400
 AND published_landing_direction_b_m=1400)
 THEN RAISE EXCEPTION 'Speyer declared LDA must not be inflated';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDQM' AND batch_key='EXPANSION_DE_PAVED_BATCH_04_2026_10_26'
 AND documented_physical_length_m=1540 AND historic_registry_length_m=1480.1
 AND published_landing_direction_a_m IS NULL AND published_landing_direction_b_m IS NULL)
 THEN RAISE EXCEPTION 'Hof-Plauen source runway geometry discrepancy lost';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key) WHERE c.cohort='EXPANSION_3906'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>1801
 THEN RAISE EXCEPTION 'Global hold queue must be 1801';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>18
 THEN RAISE EXCEPTION 'German hold queue must be 18';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_04_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED' OR simulation_world_active))
 THEN RAISE EXCEPTION 'Research must remain not approved';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation
 WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w
 JOIN airlinerra.airport_cohorts c USING(airport_key) WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'Founding playable game airport inventory changed';END IF;
END $verify$;
SELECT 'PASS' AS batch04_research_acceptance;
