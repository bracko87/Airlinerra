-- Airlinerra Phase 5, reusable named operator/aircraft/date intake: read-only regression checks.
-- Verified in Supabase 26 October 2026; all real-world operating evidence remains unverified.
DO $check$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_faa_operation_verification_cases)<>6
 THEN RAISE EXCEPTION 'Unexpected pilot case count'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_operation_gate_evidence)<>66
 THEN RAISE EXCEPTION 'Incomplete gate questionnaire'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_faa_operation_case_readiness
 WHERE evidence_gates<>11 OR verified_gates<>0 OR unresolved_gates<>11
 OR input_complete OR resulting_game_admission_status<>'NOT_APPROVED')
 THEN RAISE EXCEPTION 'Unexpected verification state'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_operation_case_readiness
 WHERE verification_readiness='MISSING_OPERATOR_AIRCRAFT_OR_FLIGHT_DATE')<>5
 THEN RAISE EXCEPTION 'Candidate intake should be incomplete'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_faa_operation_case_readiness
 WHERE faa_identifier='FLX' AND verification_readiness='DIRECTION_EVIDENCE_HOLD')
 THEN RAISE EXCEPTION 'Fallon exception not retained'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_faa_operation_case_readiness
 WHERE faa_identifier='RDK' AND research_distance_available_ft=4100
 AND research_takeoff_run_available_ft=5100)
 THEN RAISE EXCEPTION 'Red Oak landing/takeoff mismatch'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_faa_operation_case_readiness
 WHERE faa_identifier='PAAQ' AND research_distance_available_ft=5506
 AND research_takeoff_run_available_ft=6006 AND published_lda_ft=5506)
 THEN RAISE EXCEPTION 'Palmer published runway evidence mismatch'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_phase5_gate_reviews
 WHERE game_admission_status='NOT_APPROVED')<>211
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation)
 OR (SELECT count(*) FROM airlinerra.airport_cohorts WHERE cohort='ORIGINAL_3140')<>3140
 THEN RAISE EXCEPTION 'Unexpected game inventory mutation'; END IF;
END $check$;
SELECT 'PASS' AS result;

-- Separately executed, transaction-rolled-back negative constraint checks:
-- (a) approval status cannot be changed by this intake workflow;
-- (b) verified evidence without reviewer/document/validity data is rejected;
-- (c) a case referencing an unrecognized FAA runway direction fails its FK.
