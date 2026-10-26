-- Airlinerra Phase 5 — operating-gate pilot 01, 26 Oct 2026
-- Research-only tables; no public or authenticated-user privileges.
-- Supabase migration already applied:
-- airlinerra_phase5_fallon_lda_and_operating_gate_pilot_20261026
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_declared_distance_clarifications (
 evidence_cycle date NOT NULL,
 airport_key text NOT NULL,
 faa_identifier text NOT NULL,
 runway_pair text NOT NULL,
 runway_end text NOT NULL,
 published_tora_ft integer,
 published_toda_ft integer,
 published_asda_ft integer,
 published_lda_ft integer,
 physical_runway_length_ft integer,
 displaced_threshold_ft integer,
 clarification_status text NOT NULL CHECK(clarification_status IN
 ('NEEDS_FAA_OR_AIRPORT_OPERATOR_WRITTEN_CLARIFICATION','CLARIFIED_WITH_AUTHORITY')),
 written_authority_response_received boolean NOT NULL DEFAULT false,
 original_zip_verified boolean NOT NULL DEFAULT false,
 research_note text NOT NULL,
 source_urls text[] NOT NULL,
 next_action text NOT NULL,
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(evidence_cycle,airport_key,runway_pair,runway_end),
 CONSTRAINT no_unsubstantiated_lda_resolution CHECK (
 (clarification_status='NEEDS_FAA_OR_AIRPORT_OPERATOR_WRITTEN_CLARIFICATION'
   AND published_lda_ft IS NULL AND NOT written_authority_response_received)
 OR (clarification_status='CLARIFIED_WITH_AUTHORITY' AND written_authority_response_received))
);
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_operational_pilot_reviews (
 evidence_cycle date NOT NULL,
 airport_key text NOT NULL,
 faa_identifier text NOT NULL,
 pilot_batch text NOT NULL,
 review_role text NOT NULL CHECK(review_role IN
 ('DISTANCE_SCREEN_CANDIDATE','PARTIAL_DECLARED_DISTANCE_EXCEPTION')),
 nominated_runway_pair text NOT NULL,
 runway_evidence_class text NOT NULL CHECK(runway_evidence_class IN
 ('PUBLISHED_LDA','AIM_ASSUMED_NOT_PUBLISHED','PARTIAL_DECLARED_DISTANCE_HOLD')),
 technical_evidence_note text NOT NULL,
 owner_airport_rules_note text NOT NULL,
 fuel_service_evidence_note text NOT NULL,
 operational_constraints_note text NOT NULL,
 airport_owner_consent_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK(airport_owner_consent_status='NOT_VERIFIED'),
 named_operator_certificate_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK(named_operator_certificate_status='NOT_VERIFIED'),
 aircraft_performance_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK(aircraft_performance_status='NOT_VERIFIED'),
 airport_access_handling_rescue_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK(airport_access_handling_rescue_status='NOT_VERIFIED'),
 flight_date_notam_weather_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK(flight_date_notam_weather_status='NOT_VERIFIED'),
 carrier_commercial_authority_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK(carrier_commercial_authority_status='NOT_VERIFIED'),
 named_operator text,
 nominated_aircraft_model text,
 operating_flight_date date,
 written_owner_agreement_url text,
 source_urls text[] NOT NULL,
 next_validation_action text NOT NULL,
 assessment_status text NOT NULL DEFAULT 'EVIDENCE_HOLD' CHECK(assessment_status='EVIDENCE_HOLD'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(evidence_cycle,airport_key,pilot_batch),
 CONSTRAINT no_unspecified_operator_or_aircraft_claim CHECK(
 named_operator IS NULL AND nominated_aircraft_model IS NULL
 AND operating_flight_date IS NULL AND written_owner_agreement_url IS NULL)
);
ALTER TABLE airlinerra.airport_faa_declared_distance_clarifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.airport_faa_operational_pilot_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra.airport_faa_declared_distance_clarifications FROM anon,authenticated;
REVOKE ALL ON TABLE airlinerra.airport_faa_operational_pilot_reviews FROM anon,authenticated;
-- Intentional absence of any "approved" gate in this pilot. A future documented
-- workflow with actual operators, aircraft, flight dates and owner authority
-- must use a separately reviewed migration, not bypass these protective checks.
