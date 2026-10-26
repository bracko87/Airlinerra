-- Airlinerra Phase 5: research-only aircraft, certificated operator, flight-date verification intake.
-- Applied to private Supabase on 26 October 2026 via migrations:
-- airlinerra_phase5_named_operator_aircraft_date_workflow_20261026
-- airlinerra_phase5_operation_intake_strict_takeoff_and_expiry_20261026
-- The second one supersedes the initial readiness VIEW definition.
-- The FAA-derived runway data must be installed first. No game activation/approval is granted.
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_operation_verification_cases (
 case_id text PRIMARY KEY, evidence_cycle date NOT NULL, airport_key text NOT NULL,
 faa_identifier text NOT NULL,runway_pair text NOT NULL,runway_end text NOT NULL,
 linked_pilot_batch text,
 service_class text NOT NULL DEFAULT 'UNSPECIFIED' CHECK(service_class IN
 ('UNSPECIFIED','SCHEDULED_PASSENGER','CHARTER_PASSENGER','CARGO','OTHER_PAID_SERVICE')),
 nominated_operator_name text,nominated_operator_faa_certificate text,
 nominated_aircraft_model text,nominated_aircraft_registration text,aircraft_afm_revision text,
 intended_flight_date date,
 planned_landing_weight_lb numeric(12,2) CHECK(planned_landing_weight_lb IS NULL OR planned_landing_weight_lb>0),
 planned_takeoff_weight_lb numeric(12,2) CHECK(planned_takeoff_weight_lb IS NULL OR planned_takeoff_weight_lb>0),
 aircraft_wingspan_ft numeric(9,2) CHECK(aircraft_wingspan_ft IS NULL OR aircraft_wingspan_ft>0),
 aircraft_required_runway_width_ft numeric(9,2) CHECK(aircraft_required_runway_width_ft IS NULL OR aircraft_required_runway_width_ft>0),
 adjusted_required_landing_distance_ft numeric(12,2) CHECK(adjusted_required_landing_distance_ft IS NULL OR adjusted_required_landing_distance_ft>0),
 adjusted_required_takeoff_distance_ft numeric(12,2) CHECK(adjusted_required_takeoff_distance_ft IS NULL OR adjusted_required_takeoff_distance_ft>0),
 performance_assumption_notes text,
 status text NOT NULL DEFAULT 'INTAKE_INCOMPLETE' CHECK(status IN
 ('INTAKE_INCOMPLETE','EVIDENCE_COLLECTION','MANUAL_REVIEW_REQUIRED','EVIDENCE_REJECTED')),
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
 evidence_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK(evidence_status IN
 ('UNVERIFIED','EVIDENCE_SUBMITTED','VERIFIED','FAILED','NOT_APPLICABLE')),
 evidence_url text,evidence_document_date date,verified_valid_through date,
 reviewer_name text,reviewed_at timestamptz,evidence_note text,
 last_updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(case_id,gate_code),
 CONSTRAINT faa_operation_gate_verified_requires_traceability CHECK (
 evidence_status NOT IN('EVIDENCE_SUBMITTED','VERIFIED','NOT_APPLICABLE')
 OR (length(trim(coalesce(evidence_url,'')))>=10
 AND (evidence_status='EVIDENCE_SUBMITTED'
 OR (length(trim(coalesce(reviewer_name,'')))>=3 AND reviewed_at IS NOT NULL
 AND length(trim(coalesce(evidence_note,'')))>=20)))),
 CONSTRAINT faa_operation_gate_verified_dates CHECK(evidence_status<>'VERIFIED'
 OR (evidence_document_date IS NOT NULL AND verified_valid_through IS NOT NULL
 AND verified_valid_through>=evidence_document_date)),
 CONSTRAINT faa_operation_gate_fail_note CHECK(evidence_status<>'FAILED'
 OR length(trim(coalesce(evidence_note,'')))>=12)
);
CREATE INDEX IF NOT EXISTS faa_operation_case_airport_idx
 ON airlinerra.airport_faa_operation_verification_cases(evidence_cycle,airport_key);
CREATE INDEX IF NOT EXISTS faa_operation_gate_status_idx
 ON airlinerra.airport_faa_operation_gate_evidence(gate_code,evidence_status);
ALTER TABLE airlinerra.airport_faa_operation_verification_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.airport_faa_operation_gate_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_faa_operation_verification_cases FROM anon,authenticated;
REVOKE ALL ON airlinerra.airport_faa_operation_gate_evidence FROM anon,authenticated;

-- Exact read-only readiness view fetched independently from live PostgreSQL.
CREATE OR REPLACE VIEW airlinerra.airport_faa_operation_case_readiness
WITH (security_invoker=true) AS
 WITH grouped AS (
         SELECT c.case_id,
            c.airport_key,
            c.faa_identifier,
            c.runway_pair,
            c.runway_end,
            c.service_class,
            c.nominated_operator_name,
            c.nominated_operator_faa_certificate,
            c.nominated_aircraft_model,
            c.nominated_aircraft_registration,
            c.aircraft_afm_revision,
            c.intended_flight_date,
            c.planned_landing_weight_lb,
            c.planned_takeoff_weight_lb,
            c.aircraft_wingspan_ft,
            c.aircraft_required_runway_width_ft,
            c.adjusted_required_landing_distance_ft,
            c.adjusted_required_takeoff_distance_ft,
            c.performance_assumption_notes,
            c.status,
            c.game_admission_status,
            s.adjudicated_distance_screen_status,
            s.published_lda_ft,
            s.aim_assumed_landing_ft,
            s.physical_runway_width_ft,
            s.physical_runway_ft,
            e.published_tora_ft,
            s.pair_any_declared_distance,
            count(g.gate_code) AS evidence_gates,
            count(g.gate_code) FILTER (WHERE g.evidence_status = 'VERIFIED'::text AND c.intended_flight_date IS NOT NULL AND g.verified_valid_through >= c.intended_flight_date) AS verified_gates,
            count(g.gate_code) FILTER (WHERE g.evidence_status = 'NOT_APPLICABLE'::text) AS not_applicable_gates,
            count(g.gate_code) FILTER (WHERE g.evidence_status = 'FAILED'::text) AS failed_gates,
            count(g.gate_code) FILTER (WHERE (g.evidence_status <> ALL (ARRAY['VERIFIED'::text, 'NOT_APPLICABLE'::text])) OR g.evidence_status = 'VERIFIED'::text AND (c.intended_flight_date IS NULL OR g.verified_valid_through < c.intended_flight_date)) AS unresolved_gates,
            count(g.gate_code) FILTER (WHERE g.evidence_status = 'VERIFIED'::text AND (c.intended_flight_date IS NULL OR g.verified_valid_through < c.intended_flight_date)) AS expired_evidence_gates
           FROM airlinerra.airport_faa_operation_verification_cases c
             JOIN airlinerra.airport_faa_aim_direction_adjudicated s ON s.cycle_date = c.evidence_cycle AND s.airport_key = c.airport_key AND s.runway_pair = c.runway_pair AND s.runway_end = c.runway_end
             JOIN airlinerra.airport_faa_nasr_backfill_runway_ends e ON e.cycle_date = c.evidence_cycle AND e.airport_key = c.airport_key AND e.runway_pair = c.runway_pair AND e.runway_end = c.runway_end
             LEFT JOIN airlinerra.airport_faa_operation_gate_evidence g ON g.case_id = c.case_id
          GROUP BY c.case_id, s.adjudicated_distance_screen_status, s.published_lda_ft, s.aim_assumed_landing_ft, s.physical_runway_width_ft, s.physical_runway_ft, e.published_tora_ft, s.pair_any_declared_distance
        ), measured AS (
         SELECT x.case_id,
            x.airport_key,
            x.faa_identifier,
            x.runway_pair,
            x.runway_end,
            x.service_class,
            x.nominated_operator_name,
            x.nominated_operator_faa_certificate,
            x.nominated_aircraft_model,
            x.nominated_aircraft_registration,
            x.aircraft_afm_revision,
            x.intended_flight_date,
            x.planned_landing_weight_lb,
            x.planned_takeoff_weight_lb,
            x.aircraft_wingspan_ft,
            x.aircraft_required_runway_width_ft,
            x.adjusted_required_landing_distance_ft,
            x.adjusted_required_takeoff_distance_ft,
            x.performance_assumption_notes,
            x.status,
            x.game_admission_status,
            x.adjudicated_distance_screen_status,
            x.published_lda_ft,
            x.aim_assumed_landing_ft,
            x.physical_runway_width_ft,
            x.physical_runway_ft,
            x.published_tora_ft,
            x.pair_any_declared_distance,
            x.evidence_gates,
            x.verified_gates,
            x.not_applicable_gates,
            x.failed_gates,
            x.unresolved_gates,
            x.expired_evidence_gates,
                CASE
                    WHEN x.adjudicated_distance_screen_status = 'PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY'::text THEN x.published_lda_ft
                    WHEN x.adjudicated_distance_screen_status = 'AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY'::text THEN x.aim_assumed_landing_ft
                    ELSE NULL::integer
                END AS research_distance_available_ft,
                CASE
                    WHEN x.published_tora_ft IS NOT NULL THEN x.published_tora_ft
                    WHEN NOT x.pair_any_declared_distance THEN x.physical_runway_ft
                    ELSE NULL::integer
                END AS research_takeoff_run_available_ft,
            x.service_class <> 'UNSPECIFIED'::text AND length(TRIM(BOTH FROM COALESCE(x.nominated_operator_name, ''::text))) > 0 AND length(TRIM(BOTH FROM COALESCE(x.nominated_operator_faa_certificate, ''::text))) > 0 AND length(TRIM(BOTH FROM COALESCE(x.nominated_aircraft_model, ''::text))) > 0 AND length(TRIM(BOTH FROM COALESCE(x.nominated_aircraft_registration, ''::text))) > 0 AND length(TRIM(BOTH FROM COALESCE(x.aircraft_afm_revision, ''::text))) > 0 AND x.intended_flight_date IS NOT NULL AND x.intended_flight_date >= CURRENT_DATE AND x.planned_landing_weight_lb IS NOT NULL AND x.planned_takeoff_weight_lb IS NOT NULL AND x.aircraft_wingspan_ft IS NOT NULL AND x.aircraft_required_runway_width_ft IS NOT NULL AND x.adjusted_required_landing_distance_ft IS NOT NULL AND x.adjusted_required_takeoff_distance_ft IS NOT NULL AND length(TRIM(BOTH FROM COALESCE(x.performance_assumption_notes, ''::text))) >= 30 AS input_complete
           FROM grouped x
        )
 SELECT case_id,
    airport_key,
    faa_identifier,
    runway_pair,
    runway_end,
    service_class,
    nominated_operator_name,
    nominated_operator_faa_certificate,
    nominated_aircraft_model,
    nominated_aircraft_registration,
    aircraft_afm_revision,
    intended_flight_date,
    planned_landing_weight_lb,
    planned_takeoff_weight_lb,
    aircraft_wingspan_ft,
    aircraft_required_runway_width_ft,
    adjusted_required_landing_distance_ft,
    adjusted_required_takeoff_distance_ft,
    performance_assumption_notes,
    status,
    game_admission_status,
    adjudicated_distance_screen_status,
    published_lda_ft,
    aim_assumed_landing_ft,
    physical_runway_width_ft,
    physical_runway_ft,
    evidence_gates,
    verified_gates,
    not_applicable_gates,
    failed_gates,
    unresolved_gates,
    research_distance_available_ft,
    input_complete,
        CASE
            WHEN adjudicated_distance_screen_status <> ALL (ARRAY['PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY'::text, 'AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY'::text]) THEN 'DIRECTION_EVIDENCE_HOLD'::text
            WHEN NOT input_complete THEN 'MISSING_OPERATOR_AIRCRAFT_OR_FLIGHT_DATE'::text
            WHEN research_distance_available_ft IS NULL OR physical_runway_width_ft IS NULL OR research_takeoff_run_available_ft IS NULL THEN 'MISSING_RUNWAY_MEASUREMENTS'::text
            WHEN adjusted_required_landing_distance_ft > research_distance_available_ft::numeric OR adjusted_required_takeoff_distance_ft > research_takeoff_run_available_ft::numeric OR aircraft_required_runway_width_ft > physical_runway_width_ft::numeric THEN 'AIRCRAFT_DISTANCE_WIDTH_OR_TAKEOFF_FAIL'::text
            WHEN failed_gates > 0 THEN 'EVIDENCE_FAILED'::text
            WHEN evidence_gates <> 11 OR unresolved_gates > 0 OR expired_evidence_gates > 0 THEN 'UNVERIFIED_OPERATING_GATES'::text
            ELSE 'MANUAL_ADJUDICATION_ONLY_NOT_APPROVED'::text
        END AS verification_readiness,
    'NOT_APPROVED'::text AS resulting_game_admission_status,
    research_takeoff_run_available_ft,
    expired_evidence_gates
   FROM measured;
REVOKE ALL ON airlinerra.airport_faa_operation_case_readiness FROM anon,authenticated;

-- Seed cases and gates in SEPARATE SQL statements: a single PostgreSQL WITH
-- statement cannot SELECT the newly inserted case rows in the same snapshot.
WITH seed(faa_identifier,runway_end) AS (VALUES
 ('FLX','03'),('GWR','16'),('HND','17R'),('PAAQ','16'),('PRO','14'),('RDK','05'))
INSERT INTO airlinerra.airport_faa_operation_verification_cases
(case_id,evidence_cycle,airport_key,faa_identifier,runway_pair,runway_end,linked_pilot_batch)
SELECT 'USPH5-OPS-01-'||seed.faa_identifier||'-'||seed.runway_end,
 p.evidence_cycle,p.airport_key,p.faa_identifier,p.nominated_runway_pair,seed.runway_end,p.pilot_batch
FROM seed JOIN airlinerra.airport_faa_operational_pilot_reviews p
 ON p.faa_identifier=seed.faa_identifier AND p.pilot_batch='US_PHASE5_OPERATING_GATES_PILOT_01_2026_10_26'
JOIN airlinerra.airport_faa_nasr_backfill_runway_ends e
 ON e.cycle_date=p.evidence_cycle AND e.airport_key=p.airport_key
 AND e.runway_pair=p.nominated_runway_pair AND e.runway_end=seed.runway_end
ON CONFLICT(case_id) DO NOTHING;

INSERT INTO airlinerra.airport_faa_operation_gate_evidence(case_id,gate_code)
SELECT c.case_id,g.gate_code FROM airlinerra.airport_faa_operation_verification_cases c
CROSS JOIN (VALUES ('RUNWAY_DIRECTION_SOURCE'),('FAA_NASR_PROVENANCE'),
 ('AIRCRAFT_AIRWORTHINESS'),('AIRCRAFT_AF_MANUAL_PERFORMANCE'),
 ('RUNWAY_WIDTH_SURFACE_PAVEMENT_LOAD'),('FAA_OPERATOR_CERTIFICATE_OPSPECS'),
 ('DOT_ECONOMIC_AUTHORITY'),('AIRPORT_OWNER_PAID_USE_PERMISSION'),
 ('FUEL_HANDLING_RESCUE_ACCESS'),('FLIGHT_DAY_NOTAM_FICON_WEATHER'),
 ('SERVICE_CLASS_SECURITY_CUSTOMS')) g(gate_code)
WHERE c.linked_pilot_batch='US_PHASE5_OPERATING_GATES_PILOT_01_2026_10_26'
ON CONFLICT(case_id,gate_code) DO NOTHING;
