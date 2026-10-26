-- Airlinerra Phase 5 operating-gate pilot 01 audit. Executed PASS Oct 26 2026.
-- Fail closed: documentation of a service is NOT an approval or permission.
DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_faa_declared_distance_clarifications
     WHERE faa_identifier='FLX' AND evidence_cycle='2026-10-01'
       AND clarification_status='NEEDS_FAA_OR_AIRPORT_OPERATOR_WRITTEN_CLARIFICATION'
       AND NOT written_authority_response_received AND published_lda_ft IS NULL
       AND published_tora_ft=5703 AND published_toda_ft=5703
       AND game_admission_status='NOT_APPROVED')<>2
 THEN RAISE EXCEPTION 'Fallon direction count, source TORA/TODA or status failed'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_operational_pilot_reviews
     WHERE pilot_batch='US_PHASE5_OPERATING_GATES_PILOT_01_2026_10_26')<>6
 THEN RAISE EXCEPTION 'Pilot six-airport roster incomplete'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_operational_pilot_reviews
     WHERE pilot_batch='US_PHASE5_OPERATING_GATES_PILOT_01_2026_10_26'
       AND assessment_status='EVIDENCE_HOLD' AND game_admission_status='NOT_APPROVED'
       AND airport_owner_consent_status='NOT_VERIFIED'
       AND named_operator_certificate_status='NOT_VERIFIED'
       AND aircraft_performance_status='NOT_VERIFIED'
       AND airport_access_handling_rescue_status='NOT_VERIFIED'
       AND flight_date_notam_weather_status='NOT_VERIFIED'
       AND carrier_commercial_authority_status='NOT_VERIFIED'
       AND named_operator IS NULL AND nominated_aircraft_model IS NULL
       AND operating_flight_date IS NULL AND written_owner_agreement_url IS NULL
       AND cardinality(source_urls)>=2)<>6
 THEN RAISE EXCEPTION 'Unverified pilots were marked verified'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_faa_operational_pilot_reviews
     WHERE review_role='DISTANCE_SCREEN_CANDIDATE'
       AND pilot_batch='US_PHASE5_OPERATING_GATES_PILOT_01_2026_10_26')<>5
  OR (SELECT count(*) FROM airlinerra.airport_faa_operational_pilot_reviews
     WHERE faa_identifier='FLX' AND review_role='PARTIAL_DECLARED_DISTANCE_EXCEPTION'
       AND pilot_batch='US_PHASE5_OPERATING_GATES_PILOT_01_2026_10_26')<>1
 THEN RAISE EXCEPTION 'Pilot candidates / exception breakdown invalid'; END IF;
 IF EXISTS (
   SELECT 1 FROM airlinerra.airport_faa_operational_pilot_reviews p
   JOIN airlinerra.airport_faa_initial_distance_decisions d USING(airport_key)
   WHERE (p.review_role='DISTANCE_SCREEN_CANDIDATE'
     AND d.evidence_decision<>'DISTANCE_SCREEN_CANDIDATE_ONLY')
   OR (p.review_role='PARTIAL_DECLARED_DISTANCE_EXCEPTION'
     AND d.evidence_decision<>'PARTIAL_DECLARED_DISTANCE_MANUAL_REVIEW')
 ) THEN RAISE EXCEPTION 'Incorrect research distance source'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_phase5_gate_reviews
     WHERE game_admission_status='NOT_APPROVED')<>211
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation)
 OR (SELECT count(*) FROM airlinerra.airport_cohorts WHERE cohort='ORIGINAL_3140')<>3140
 THEN RAISE EXCEPTION 'Protected airport game data changed'; END IF;
END $verify$;
SELECT 'PASS' AS pilot_acceptance_result;
