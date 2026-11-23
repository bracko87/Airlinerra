-- Airlinerra Phase 5: private, research-only named-aircraft/operator/date gate intake.
-- No operator, aircraft, route or flight date has been nominated or verified.
-- No world admission. Archived FAA Oct 2026 government-republished evidence stays unchanged.
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_operation_verification_cases (
 case_id text PRIMARY KEY,
 evidence_cycle date NOT NULL,
 airport_key text NOT NULL,
 faa_identifier text NOT NULL,
 runway_pair text NOT NULL,
 runway_end text NOT NULL,
 linked_pilot_batch text,
 service_class text NOT NULL DEFAULT 'UNSPECIFIED'
   CHECK(service_class IN('UNSPECIFIED','SCHEDULED_PASSENGER','CHARTER_PASSENGER','CARGO','OTHER_PAID_SERVICE')),
 nominated_operator_name text,
 nominated_operator_faa_certificate text,
 nominated_aircraft_model text,
 nominated_aircraft_registration text,
 aircraft_afm_revision text,
 intended_flight_date date,
 planned_landing_weight_lb numeric(12,2) CHECK(planned_landing_weight_lb IS NULL OR planned_landing_weight_lb>0),
 planned_takeoff_weight_lb numeric(12,2) CHECK(planned_takeoff_weight_lb IS NULL OR planned_takeoff_weight_lb>0),
 aircraft_wingspan_ft numeric(9,2) CHECK(aircraft_wingspan_ft IS NULL OR aircraft_wingspan_ft>0),
 aircraft_required_runway_width_ft numeric(9,2) CHECK(aircraft_required_runway_width_ft IS NULL OR aircraft_required_runway_width_ft>0),
 adjusted_required_landing_distance_ft numeric(12,2) CHECK(adjusted_required_landing_distance_ft IS NULL OR adjusted_required_landing_distance_ft>0),
 adjusted_required_takeoff_distance_ft numeric(12,2) CHECK(adjusted_required_takeoff_distance_ft IS NULL OR adjusted_required_takeoff_distance_ft>0),
 performance_assumption_notes text,
 status text NOT NULL DEFAULT 'INTAKE_INCOMPLETE'
   CHECK(status IN('INTAKE_INCOMPLETE','EVIDENCE_COLLECTION','MANUAL_REVIEW_REQUIRED','EVIDENCE_REJECTED')),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT faa_operation_case_end_fk FOREIGN KEY(evidence_cycle,airport_key,runway_pair,runway_end)
 REFERENCES airlinerra.airport_faa_nasr_backfill_runway_ends(cycle_date,airport_key,runway_pair,runway_end),
 CONSTRAINT faa_operation_case_valid_identifier CHECK(length(trim(case_id)) BETWEEN 12 AND 120 AND length(trim(faa_identifier))>=2)
);
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_operation_gate_evidence (
 case_id text NOT NULL REFERENCES airlinerra.airport_faa_operation_verification_cases(case_id),
 gate_code text NOT NULL CHECK(gate_code IN(
 'RUNWAY_DIRECTION_SOURCE','FAA_NASR_PROVENANCE','AIRCRAFT_AIRWORTHINESS',
 'AIRCRAFT_AF_MANUAL_PERFORMANCE','RUNWAY_WIDTH_SURFACE_PAVEMENT_LOAD',
 'FAA_OPERATOR_CERTIFICATE_OPSPECS','DOT_ECONOMIC_AUTHORITY',
 'AIRPORT_OWNER_PAID_USE_PERMISSION','FUEL_HANDLING_RESCUE_ACCESS',
 'FLIGHT_DAY_NOTAM_FICON_WEATHER','SERVICE_CLASS_SECURITY_CUSTOMS')),
 evidence_status text NOT NULL DEFAULT 'UNVERIFIED'
 CHECK(evidence_status IN('UNVERIFIED','EVIDENCE_SUBMITTED','VERIFIED','FAILED','NOT_APPLICABLE')),
 evidence_url text,evidence_document_date date,verified_valid_through date,
 reviewer_name text,reviewed_at timestamptz,evidence_note text,
 last_updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(case_id,gate_code),
 CONSTRAINT faa_operation_gate_verified_requires_traceability CHECK (
   evidence_status NOT IN('EVIDENCE_SUBMITTED','VERIFIED','NOT_APPLICABLE')
   OR (length(trim(coalesce(evidence_url,'')))>=10 AND
       (evidence_status='EVIDENCE_SUBMITTED'
       OR (length(trim(coalesce(reviewer_name,'')))>=3
           AND reviewed_at IS NOT NULL
           AND length(trim(coalesce(evidence_note,'')))>=20)))
 ),
 CONSTRAINT faa_operation_gate_verified_dates CHECK (
 evidence_status<>'VERIFIED' OR (evidence_document_date IS NOT NULL
   AND verified_valid_through IS NOT NULL
   AND verified_valid_through>=evidence_document_date)
 ),
 CONSTRAINT faa_operation_gate_fail_note CHECK(evidence_status<>'FAILED' OR length(trim(coalesce(evidence_note,'')))>=12)
);
CREATE INDEX IF NOT EXISTS faa_operation_case_airport_idx
 ON airlinerra.airport_faa_operation_verification_cases(evidence_cycle,airport_key);
CREATE INDEX IF NOT EXISTS faa_operation_gate_status_idx
 ON airlinerra.airport_faa_operation_gate_evidence(gate_code,evidence_status);
ALTER TABLE airlinerra.airport_faa_operation_verification_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.airport_faa_operation_gate_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_faa_operation_verification_cases FROM anon,authenticated;
REVOKE ALL ON airlinerra.airport_faa_operation_gate_evidence FROM anon,authenticated;

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
 COUNT(g.gate_code) AS evidence_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status='VERIFIED'
     AND (g.verified_valid_through IS NULL OR g.verified_valid_through>=c.intended_flight_date))
 AS verified_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status='NOT_APPLICABLE') AS not_applicable_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status='FAILED') AS failed_gates,
 COUNT(g.gate_code) FILTER (WHERE g.evidence_status NOT IN ('VERIFIED','NOT_APPLICABLE')) AS unresolved_gates
 FROM airlinerra.airport_faa_operation_verification_cases c
 JOIN airlinerra.airport_faa_aim_direction_adjudicated s
 ON s.cycle_date=c.evidence_cycle AND s.airport_key=c.airport_key
 AND s.runway_pair=c.runway_pair AND s.runway_end=c.runway_end
 LEFT JOIN airlinerra.airport_faa_operation_gate_evidence g ON g.case_id=c.case_id
 GROUP BY c.case_id,s.adjudicated_distance_screen_status,s.published_lda_ft,
 s.aim_assumed_landing_ft,s.physical_runway_width_ft,s.physical_runway_ft
), measured AS (
 SELECT x.*,
 CASE WHEN x.adjudicated_distance_screen_status='PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY'
  THEN x.published_lda_ft
 WHEN x.adjudicated_distance_screen_status='AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY'
  THEN x.aim_assumed_landing_ft ELSE NULL END AS research_distance_available_ft,
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
 AND length(trim(coalesce(x.performance_assumption_notes,'')))>=30
 ) AS input_complete
 FROM grouped x
)
SELECT measured.*,
 CASE
 WHEN adjudicated_distance_screen_status NOT IN (
  'PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY','AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY'
 ) THEN 'DIRECTION_EVIDENCE_HOLD'
 WHEN NOT input_complete THEN 'MISSING_OPERATOR_AIRCRAFT_OR_FLIGHT_DATE'
 WHEN research_distance_available_ft IS NULL OR physical_runway_width_ft IS NULL
 THEN 'MISSING_RUNWAY_MEASUREMENTS'
 WHEN adjusted_required_landing_distance_ft>research_distance_available_ft
 OR aircraft_required_runway_width_ft>physical_runway_width_ft
 THEN 'AIRCRAFT_DISTANCE_OR_WIDTH_FAIL'
 WHEN failed_gates>0 THEN 'EVIDENCE_FAILED'
 WHEN evidence_gates<>11 OR unresolved_gates>0 THEN 'UNVERIFIED_OPERATING_GATES'
 ELSE 'MANUAL_ADJUDICATION_ONLY_NOT_APPROVED'
 END AS verification_readiness,
 'NOT_APPROVED'::text AS resulting_game_admission_status
FROM measured;
REVOKE ALL ON airlinerra.airport_faa_operation_case_readiness FROM anon,authenticated;

-- Preserve the original six-airport pilot as intake scaffolding. No operator,
-- aircraft model, registered aircraft, flight date or service type is invented.
WITH seed(faa_identifier,runway_end) AS (VALUES
 ('FLX','03'),('GWR','16'),('HND','17R'),('PAAQ','16'),('PRO','14'),('RDK','05')),
 created AS (
 INSERT INTO airlinerra.airport_faa_operation_verification_cases
 (case_id,evidence_cycle,airport_key,faa_identifier,runway_pair,runway_end,linked_pilot_batch)
 SELECT 'USPH5-OPS-01-'||seed.faa_identifier||'-'||seed.runway_end,
 p.evidence_cycle,p.airport_key,p.faa_identifier,p.nominated_runway_pair,seed.runway_end,p.pilot_batch
 FROM seed JOIN airlinerra.airport_faa_operational_pilot_reviews p
 ON p.faa_identifier=seed.faa_identifier
 AND p.pilot_batch='US_PHASE5_OPERATING_GATES_PILOT_01_2026_10_26'
 JOIN airlinerra.airport_faa_nasr_backfill_runway_ends e ON e.cycle_date=p.evidence_cycle
 AND e.airport_key=p.airport_key AND e.runway_pair=p.nominated_runway_pair
 AND e.runway_end=seed.runway_end
 ON CONFLICT (case_id) DO NOTHING RETURNING case_id)
INSERT INTO airlinerra.airport_faa_operation_gate_evidence(case_id,gate_code)
SELECT c.case_id,g.gate_code
FROM airlinerra.airport_faa_operation_verification_cases c
CROSS JOIN (VALUES ('RUNWAY_DIRECTION_SOURCE'),('FAA_NASR_PROVENANCE'),
 ('AIRCRAFT_AIRWORTHINESS'),('AIRCRAFT_AF_MANUAL_PERFORMANCE'),
 ('RUNWAY_WIDTH_SURFACE_PAVEMENT_LOAD'),('FAA_OPERATOR_CERTIFICATE_OPSPECS'),
 ('DOT_ECONOMIC_AUTHORITY'),('AIRPORT_OWNER_PAID_USE_PERMISSION'),
 ('FUEL_HANDLING_RESCUE_ACCESS'),('FLIGHT_DAY_NOTAM_FICON_WEATHER'),
 ('SERVICE_CLASS_SECURITY_CUSTOMS')) g(gate_code)
WHERE c.linked_pilot_batch='US_PHASE5_OPERATING_GATES_PILOT_01_2026_10_26'
ON CONFLICT(case_id,gate_code) DO NOTHING;
