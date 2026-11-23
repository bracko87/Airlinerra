CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_phase5_gate_reviews (
  airport_key text PRIMARY KEY REFERENCES airlinerra.airport_expansion_next_eligibility_phase4(airport_key) ON DELETE RESTRICT,
  faa_identifier text NOT NULL,
  phase4_review_batch_identifier text NOT NULL,
  phase4_runway_distance_gate text NOT NULL CHECK (phase4_runway_distance_gate IN ('PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION','DIRECTIONAL_LANDING_PAVEMENT_BELOW_1200M','GROSS_LENGTH_ONLY_LDA_UNVERIFIED')),
  queue_priority smallint NOT NULL CHECK (queue_priority BETWEEN 1 AND 3),
  phase5_batch_identifier text,
  phase5_review_status text NOT NULL DEFAULT 'QUEUED' CHECK (phase5_review_status IN ('QUEUED','IN_REVIEW','EVIDENCE_HOLD','REVIEW_COMPLETE_BLOCKED')),
  lda_evidence_status text NOT NULL CHECK (lda_evidence_status IN ('SOURCE_PUBLISHED_PENDING_REVALIDATION','BELOW_MINIMUM_DIRECTION_RECHECK','OFFICIAL_LDA_NOT_VERIFIED','REVALIDATED_ABOVE_MINIMUM','FAILED_DISTANCE_GATE')),
  aircraft_compatibility_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK (aircraft_compatibility_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  owner_commercial_permission_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK (owner_commercial_permission_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  operator_certificate_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK (operator_certificate_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  notam_weather_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK (notam_weather_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  fuel_handling_rescue_status text NOT NULL DEFAULT 'NOT_VERIFIED' CHECK (fuel_handling_rescue_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK (game_admission_status='NOT_APPROVED'),
  source_evidence_urls text[] NOT NULL CHECK (cardinality(source_evidence_urls)>0),
  next_verification_action text NOT NULL,
  verification_notes text,
  last_independent_verification_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS airport_expansion_phase5_queue_idx ON airlinerra.airport_expansion_phase5_gate_reviews(queue_priority, phase5_review_status, faa_identifier);
ALTER TABLE airlinerra.airport_expansion_phase5_gate_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra.airport_expansion_phase5_gate_reviews FROM PUBLIC, anon, authenticated;