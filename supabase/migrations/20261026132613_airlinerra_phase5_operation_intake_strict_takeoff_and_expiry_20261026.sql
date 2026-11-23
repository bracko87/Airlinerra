CREATE OR REPLACE VIEW airlinerra.airport_faa_operation_case_readiness
WITH (security_invoker=true) AS
WITH grouped AS (
 SELECT c.case_id,c.airport_key,c.faa_identifier,c.runway_pair,c.runway_end,c.service_class,
 c.nominated_operator_name,c.nominated_operator_faa_certificate,c.nominated_aircraft_model,
 c.nominated_aircraft_registration,c.aircraft_afm_revision,c.intended_flight_date,
 c.planned_landing_weight_lb,c.planned_takeoff_weight_lb,c.aircraft_wingspan_ft,
 c.aircraft_required_runway_width_ft,c.adjusted_required_landing_distance_ft,
 c.adjusted_required_takeoff_distance_ft,c.performance_assumption_notes,
 c.status,c.game_admission_status,
 s.adjudicated_distance_screen_status,s.published_lda_ft,s.aim_assumed_landing_ft,
 s.physical_runway_width_ft,s.physical_runway_ft,
 e.published_tora_ft,s.pair_any_declared_distance,
 COUNT(g.gate_code) AS evidence_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status='VERIFIED'
   AND c.intended_flight_date IS NOT NULL
   AND g.verified_valid_through>=c.intended_flight_date) AS verified_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status='NOT_APPLICABLE') AS not_applicable_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status='FAILED') AS failed_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status NOT IN('VERIFIED','NOT_APPLICABLE')
   OR (g.evidence_status='VERIFIED' AND
   (c.intended_flight_date IS NULL OR g.verified_valid_through<c.intended_flight_date))) AS unresolved_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status='VERIFIED' AND
   (c.intended_flight_date IS NULL OR g.verified_valid_through<c.intended_flight_date)) AS expired_evidence_gates
 FROM airlinerra.airport_faa_operation_verification_cases c
 JOIN airlinerra.airport_faa_aim_direction_adjudicated s
 ON s.cycle_date=c.evidence_cycle AND s.airport_key=c.airport_key
 AND s.runway_pair=c.runway_pair AND s.runway_end=c.runway_end
 JOIN airlinerra.airport_faa_nasr_backfill_runway_ends e
 ON e.cycle_date=c.evidence_cycle AND e.airport_key=c.airport_key
 AND e.runway_pair=c.runway_pair AND e.runway_end=c.runway_end
 LEFT JOIN airlinerra.airport_faa_operation_gate_evidence g ON g.case_id=c.case_id
 GROUP BY c.case_id,s.adjudicated_distance_screen_status,s.published_lda_ft,
 s.aim_assumed_landing_ft,s.physical_runway_width_ft,s.physical_runway_ft,
 e.published_tora_ft,s.pair_any_declared_distance
), measured AS (
 SELECT x.*,
 CASE WHEN x.adjudicated_distance_screen_status='PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY'
 THEN x.published_lda_ft
 WHEN x.adjudicated_distance_screen_status='AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY'
 THEN x.aim_assumed_landing_ft ELSE NULL END AS research_distance_available_ft,
 CASE WHEN x.published_tora_ft IS NOT NULL THEN x.published_tora_ft
 WHEN NOT x.pair_any_declared_distance THEN x.physical_runway_ft
 ELSE NULL END AS research_takeoff_run_available_ft,
 (x.service_class<>'UNSPECIFIED'
 AND length(trim(coalesce(x.nominated_operator_name,'')))>0
 AND length(trim(coalesce(x.nominated_operator_faa_certificate,'')))>0
 AND length(trim(coalesce(x.nominated_aircraft_model,'')))>0
 AND length(trim(coalesce(x.nominated_aircraft_registration,'')))>0
 AND length(trim(coalesce(x.aircraft_afm_revision,'')))>0
 AND x.intended_flight_date IS NOT NULL AND x.intended_flight_date>=current_date
 AND x.planned_landing_weight_lb IS NOT NULL AND x.planned_takeoff_weight_lb IS NOT NULL
 AND x.aircraft_wingspan_ft IS NOT NULL AND x.aircraft_required_runway_width_ft IS NOT NULL
 AND x.adjusted_required_landing_distance_ft IS NOT NULL
 AND x.adjusted_required_takeoff_distance_ft IS NOT NULL
 AND length(trim(coalesce(x.performance_assumption_notes,'')))>=30) AS input_complete
 FROM grouped x
)
SELECT case_id,airport_key,faa_identifier,runway_pair,runway_end,service_class,
 nominated_operator_name,nominated_operator_faa_certificate,nominated_aircraft_model,
 nominated_aircraft_registration,aircraft_afm_revision,intended_flight_date,
 planned_landing_weight_lb,planned_takeoff_weight_lb,aircraft_wingspan_ft,
 aircraft_required_runway_width_ft,adjusted_required_landing_distance_ft,
 adjusted_required_takeoff_distance_ft,performance_assumption_notes,status,game_admission_status,
 adjudicated_distance_screen_status,published_lda_ft,aim_assumed_landing_ft,
 physical_runway_width_ft,physical_runway_ft,evidence_gates,verified_gates,
 not_applicable_gates,failed_gates,unresolved_gates,research_distance_available_ft,
 input_complete,
 CASE WHEN adjudicated_distance_screen_status NOT IN(
 'PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY','AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY')
 THEN 'DIRECTION_EVIDENCE_HOLD'
 WHEN NOT input_complete THEN 'MISSING_OPERATOR_AIRCRAFT_OR_FLIGHT_DATE'
 WHEN research_distance_available_ft IS NULL OR physical_runway_width_ft IS NULL
 OR research_takeoff_run_available_ft IS NULL THEN 'MISSING_RUNWAY_MEASUREMENTS'
 WHEN adjusted_required_landing_distance_ft>research_distance_available_ft
 OR adjusted_required_takeoff_distance_ft>research_takeoff_run_available_ft
 OR aircraft_required_runway_width_ft>physical_runway_width_ft
 THEN 'AIRCRAFT_DISTANCE_WIDTH_OR_TAKEOFF_FAIL'
 WHEN failed_gates>0 THEN 'EVIDENCE_FAILED'
 WHEN evidence_gates<>11 OR unresolved_gates>0 OR expired_evidence_gates>0
 THEN 'UNVERIFIED_OPERATING_GATES'
 ELSE 'MANUAL_ADJUDICATION_ONLY_NOT_APPROVED'
 END AS verification_readiness,
 'NOT_APPROVED'::text AS resulting_game_admission_status,
 research_takeoff_run_available_ft,expired_evidence_gates
FROM measured;
REVOKE ALL ON airlinerra.airport_faa_operation_case_readiness FROM anon,authenticated;