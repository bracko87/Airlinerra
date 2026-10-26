-- Airlinerra German airport expansion Batch 03, 2026-10-26
-- Run only against private airport research database. Source review, NOT simulation activation.
-- Executed PASS on 2026-10-26.
DO $check$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews
     WHERE batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26')<>7
 OR (SELECT count(*) FROM airlinerra.airport_expansion_runway_technical_exceptions
     WHERE batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26')<>1
 THEN RAISE EXCEPTION '7 paved runway source records plus 1 technical exception required'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews v
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE v.batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26'
 AND v.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.game_admission_status='NOT_APPROVED')<>6
 THEN RAISE EXCEPTION 'Six primary-source research advances expected'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_runway_technical_exceptions e
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE e.icao_code='EDMB' AND e.source_paved_length_m=980
 AND e.registry_qualifying_length_m=1314.9
 AND a.review_status='HOLD_OPERATOR_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT'
 AND a.game_admission_status='NOT_APPROVED')
 THEN RAISE EXCEPTION 'EDMB operator-reported runway discrepancy not held';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews v
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE v.icao_code='EDLD' AND v.batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')
 THEN RAISE EXCEPTION 'EDLD original surface evidence hold changed';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED' OR simulation_world_active))
 OR EXISTS(SELECT 1 FROM airlinerra.airport_expansion_runway_technical_exceptions
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED' OR simulation_world_active))
 THEN RAISE EXCEPTION 'Research status mistakenly became game approval';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w
 JOIN airlinerra.airport_cohorts c USING(airport_key) WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'Foundation airport World1 registration scope has changed';END IF;
END $check$;
SELECT 'PASS' AS german_expansion_batch03_test;
