-- Airlinerra FAA AIM October 2026 evidence-screen acceptance checks.
-- Read-only assertions; fail with exception on any unexpected approval
-- or conflation of an assumed distance with a published LDA.
DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_faa_aim_direction_screen)<>781
  THEN RAISE EXCEPTION 'Unexpected source runway-end coverage'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_nasr_runway_physical)<>379
  THEN RAISE EXCEPTION 'Physical-runway import incomplete'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_nasr_backfill_runway_ends
     WHERE threshold_source_fields_retrieved)<>781
  THEN RAISE EXCEPTION 'Runway-end threshold import incomplete'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_aim_direction_screen
     WHERE distance_screen_status='AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY')<>435
  THEN RAISE EXCEPTION 'Conditional assumption totals changed'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_aim_direction_screen
     WHERE distance_screen_status='PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY')<>67
  THEN RAISE EXCEPTION 'Source-published LDA totals changed'; END IF;
 IF EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE published_lda_ft IS NOT NULL AND aim_assumed_landing_ft IS NOT NULL)
  THEN RAISE EXCEPTION 'Published and assumed LDA conflated'; END IF;
 IF EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE pair_any_declared_distance
     AND distance_evidence_basis='FAA_AIM_4_3_6_CONDITIONAL_ASSUMPTION_NOT_PUBLISHED_LDA')
  THEN RAISE EXCEPTION 'Partial declaration improperly assumed'; END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE faa_identifier='RDK' AND runway_end='05' AND aim_assumed_landing_ft=4100
     AND published_lda_ft IS NULL)
  THEN RAISE EXCEPTION 'RDK displaced threshold case'; END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE faa_identifier='MQI' AND runway_end='05' AND aim_assumed_landing_ft=4001)
  THEN RAISE EXCEPTION 'MQI displaced threshold case'; END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE faa_identifier='FLX' AND runway_end='03'
     AND distance_screen_status='PARTIAL_DECLARED_DISTANCES_MANUAL_REVIEW')
  THEN RAISE EXCEPTION 'FLX partial declaration not held'; END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE faa_identifier='LAM' AND runway_end='09'
     AND distance_screen_status='LANDING_DIRECTION_PROHIBITED')
  THEN RAISE EXCEPTION 'LAM prohibited landing was not retained'; END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE faa_identifier='3S4' AND runway_end='18' AND published_lda_ft=4682
     AND aim_assumed_landing_ft IS NULL)
  THEN RAISE EXCEPTION '3S4 published distance overwritten'; END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE faa_identifier='TOI' AND runway_end='14'
     AND distance_screen_status='PAVEMENT_CONDITION_HOLD')
  THEN RAISE EXCEPTION 'Troy runway condition hold lost'; END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE faa_identifier='Y70' AND runway_end='18'
     AND distance_screen_status='NON_PAVED_OR_UNVERIFIED_SURFACE')
  THEN RAISE EXCEPTION 'Turf runway incorrectly admitted'; END IF;
 IF EXISTS (SELECT 1 FROM airlinerra.airport_faa_aim_direction_screen
     WHERE game_admission_status<>'NOT_APPROVED')
  OR (SELECT count(*) FROM airlinerra.airport_expansion_phase5_gate_reviews
      WHERE game_admission_status='NOT_APPROVED')<>211
  OR EXISTS (SELECT 1 FROM airlinerra.airport_world_activation)
  THEN RAISE EXCEPTION 'Unauthorized gameplay admission'; END IF;
END $verify$;
SELECT 'PASS' AS acceptance_test_result;
