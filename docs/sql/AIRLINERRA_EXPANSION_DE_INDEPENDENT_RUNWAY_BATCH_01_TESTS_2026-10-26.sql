-- Airlinerra German expansion Batch 01: regression, independently executed PASS 2026-10-26.
-- The original 3140 game airports must remain active; new airports are research only.
DO $assert$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_01_2026_10_26')<>8
 THEN RAISE EXCEPTION 'Expected eight source review records';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_01_2026_10_26'
 AND r.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.identity_status='VERIFIED' AND a.paved_runway_status='VERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>6
 THEN RAISE EXCEPTION 'Expected six independently confirmed operator runways';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_01_2026_10_26'
 AND r.source_authority_grade<>'CURRENT_AIRPORT_OPERATOR'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>2
 THEN RAISE EXCEPTION 'Secondary/historical source must remain in hold';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>1821
 THEN RAISE EXCEPTION 'Independent source queue count changed unexpectedly';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDAX' AND documented_physical_length_m=2380 AND published_landing_direction_a_m=1301 AND published_landing_direction_b_m=1341)
 OR NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDAZ' AND documented_physical_length_m=1510 AND published_landing_direction_a_m=1340 AND published_landing_direction_b_m=1270)
 OR NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDBH' AND published_landing_direction_a_m=1385 AND published_landing_direction_b_m=1450)
 THEN RAISE EXCEPTION 'Direction-specific landing distance facts missing';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE icao_code='EDAV' AND physical_length_difference_m=22)
 THEN RAISE EXCEPTION 'Finow 22m source length discrepancy not preserved';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE game_admission_status<>'NOT_APPROVED' OR simulation_world_active)
 THEN RAISE EXCEPTION 'Research row incorrectly approved';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906')
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 THEN RAISE EXCEPTION 'Protected owner-authorized founding world modified';END IF;
END $assert$;
SELECT 'PASS' AS german_expansion_batch_result;
