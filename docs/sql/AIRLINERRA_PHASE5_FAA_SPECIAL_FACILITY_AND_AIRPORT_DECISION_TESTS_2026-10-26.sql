-- Airlinerra Phase 5 FAA nonstandard-facility and airport preliminary
-- eligibility ledger independent assertions, executed PASS on 2026-10-26.
DO $audit$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_faa_nonstandard_facility_ends)<>23
  OR (SELECT count(*) FROM airlinerra.airport_faa_nonstandard_facility_ends WHERE facility_type='HELIPAD')<>15
  OR (SELECT count(*) FROM airlinerra.airport_faa_nonstandard_facility_ends WHERE facility_type='WATER_LANDING_AREA')<>4
  OR (SELECT count(*) FROM airlinerra.airport_faa_nonstandard_facility_ends WHERE facility_type='ULTRALIGHT_RUNWAY')<>4
 THEN RAISE EXCEPTION 'Incorrect special-purpose terminal classification'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_faa_nonstandard_facility_ends
  WHERE fixed_wing_runway_eligible OR game_admission_status<>'NOT_APPROVED')
 THEN RAISE EXCEPTION 'Unauthorized special-purpose admission'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_aim_direction_adjudicated)<>781
  OR EXISTS(SELECT 1 FROM airlinerra.airport_faa_aim_direction_adjudicated
    WHERE adjudicated_distance_screen_status='PHYSICAL_RUNWAY_NOT_IN_GOVERNMENT_LAYER')
  OR (SELECT count(*) FROM airlinerra.airport_faa_aim_direction_adjudicated
    WHERE adjudicated_distance_screen_status='EXCLUDED_SPECIAL_PURPOSE_FACILITY')<>23
 THEN RAISE EXCEPTION 'Unresolved missing-physical runway end or lost evidence'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_initial_distance_decisions)<>211
  OR (SELECT count(*) FROM airlinerra.airport_faa_initial_distance_decisions
      WHERE evidence_decision='DISTANCE_SCREEN_CANDIDATE_ONLY')<>208
  OR (SELECT count(*) FROM airlinerra.airport_faa_initial_distance_decisions
      WHERE evidence_decision='PARTIAL_DECLARED_DISTANCE_MANUAL_REVIEW')<>1
  OR (SELECT count(*) FROM airlinerra.airport_faa_initial_distance_decisions
      WHERE evidence_decision='NO_DISTANCE_SCREEN_PASS')<>2
 THEN RAISE EXCEPTION 'Incorrect airport research decision totals'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_faa_initial_distance_decisions
   WHERE faa_identifier='FLX' AND evidence_decision='PARTIAL_DECLARED_DISTANCE_MANUAL_REVIEW')
  OR (SELECT count(*) FROM airlinerra.airport_faa_initial_distance_decisions
      WHERE faa_identifier IN ('64S','PHD') AND evidence_decision='NO_DISTANCE_SCREEN_PASS')<>2
 THEN RAISE EXCEPTION 'Exception airports incorrectly screened'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_faa_initial_distance_decisions WHERE
  original_faa_zip_sha256_verified OR owner_paid_use_verified
  OR aircraft_performance_verified OR certified_operator_verified
  OR flight_date_safety_verified OR handling_rescue_verified
  OR game_admission_status<>'NOT_APPROVED')
 THEN RAISE EXCEPTION 'Screening mistaken for commercial approval'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_phase5_gate_reviews
      WHERE game_admission_status='NOT_APPROVED')<>211
  OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation)
  OR (SELECT count(*) FROM airlinerra.airport_cohorts WHERE cohort='ORIGINAL_3140')<>3140
 THEN RAISE EXCEPTION 'Protected game inventory violated'; END IF;
END $audit$;
SELECT 'PASS' AS batch_result;
