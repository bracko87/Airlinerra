-- Airlinerra Phase 5 private evidence queue, 26 October 2026.
-- Reproducibility archive for the schema created by the Supabase migration
-- airlinerra_phase5_evidence_queue_20261026, plus the idempotent initial seed.
-- Not a gameplay activation or operational flight authorization.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_phase5_gate_reviews (
  airport_key text PRIMARY KEY REFERENCES airlinerra.airport_expansion_next_eligibility_phase4(airport_key) ON DELETE RESTRICT,
  faa_identifier text NOT NULL,
  phase4_review_batch_identifier text NOT NULL,
  phase4_runway_distance_gate text NOT NULL CHECK (
    phase4_runway_distance_gate IN (
      'PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION',
      'DIRECTIONAL_LANDING_PAVEMENT_BELOW_1200M',
      'GROSS_LENGTH_ONLY_LDA_UNVERIFIED'
    )
  ),
  queue_priority smallint NOT NULL CHECK (queue_priority BETWEEN 1 AND 3),
  phase5_batch_identifier text,
  phase5_review_status text NOT NULL DEFAULT 'QUEUED'
    CHECK (phase5_review_status IN ('QUEUED','IN_REVIEW','EVIDENCE_HOLD','REVIEW_COMPLETE_BLOCKED')),
  lda_evidence_status text NOT NULL CHECK (
    lda_evidence_status IN (
      'SOURCE_PUBLISHED_PENDING_REVALIDATION',
      'BELOW_MINIMUM_DIRECTION_RECHECK',
      'OFFICIAL_LDA_NOT_VERIFIED',
      'REVALIDATED_ABOVE_MINIMUM',
      'FAILED_DISTANCE_GATE'
    )
  ),
  aircraft_compatibility_status text NOT NULL DEFAULT 'NOT_VERIFIED'
    CHECK (aircraft_compatibility_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  owner_commercial_permission_status text NOT NULL DEFAULT 'NOT_VERIFIED'
    CHECK (owner_commercial_permission_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  operator_certificate_status text NOT NULL DEFAULT 'NOT_VERIFIED'
    CHECK (operator_certificate_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  notam_weather_status text NOT NULL DEFAULT 'NOT_VERIFIED'
    CHECK (notam_weather_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  fuel_handling_rescue_status text NOT NULL DEFAULT 'NOT_VERIFIED'
    CHECK (fuel_handling_rescue_status IN ('NOT_VERIFIED','VERIFIED','FAILED')),
  game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED'
    CHECK (game_admission_status='NOT_APPROVED'),
  source_evidence_urls text[] NOT NULL CHECK (cardinality(source_evidence_urls)>0),
  next_verification_action text NOT NULL,
  verification_notes text,
  last_independent_verification_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS airport_expansion_phase5_queue_idx
  ON airlinerra.airport_expansion_phase5_gate_reviews
  (queue_priority, phase5_review_status, faa_identifier);

ALTER TABLE airlinerra.airport_expansion_phase5_gate_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra.airport_expansion_phase5_gate_reviews FROM PUBLIC, anon, authenticated;

-- Insert only genuine Phase 3 narrow advances from Phase 4; never duplicate or promote.
INSERT INTO airlinerra.airport_expansion_phase5_gate_reviews
(airport_key, faa_identifier, phase4_review_batch_identifier, phase4_runway_distance_gate,
 queue_priority, phase5_batch_identifier, phase5_review_status, lda_evidence_status,
 source_evidence_urls, next_verification_action, verification_notes)
SELECT
 p.airport_key, p.faa_identifier, p.review_batch_identifier, p.runway_distance_gate,
 CASE p.runway_distance_gate
   WHEN 'PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION' THEN 1
   WHEN 'DIRECTIONAL_LANDING_PAVEMENT_BELOW_1200M' THEN 2 ELSE 3 END,
 CASE WHEN p.runway_distance_gate='PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION'
      THEN 'US_EXPANSION_PHASE5_LDA_REVALIDATION_BATCH_01_2026_10_26'
      ELSE NULL END,
 'QUEUED',
 CASE p.runway_distance_gate
   WHEN 'PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION'
     THEN 'SOURCE_PUBLISHED_PENDING_REVALIDATION'
   WHEN 'DIRECTIONAL_LANDING_PAVEMENT_BELOW_1200M'
     THEN 'BELOW_MINIMUM_DIRECTION_RECHECK'
   ELSE 'OFFICIAL_LDA_NOT_VERIFIED' END,
 p.evidence_urls, p.next_verification_action,
 'Queue initialized from completed Phase 4 assessment; inherited evidence is NOT a Phase 5 independent verification. No game approval.'
FROM airlinerra.airport_expansion_next_eligibility_phase4 p
JOIN airlinerra.airport_expansion_selection_phase3 s USING (airport_key)
JOIN airlinerra.airport_cohorts c USING (airport_key)
WHERE c.cohort='EXPANSION_3906'
  AND s.selection_status='CONSTRAINT_SCOPE_CONFIRMED_NEXT_ELIGIBILITY'
ON CONFLICT (airport_key) DO NOTHING;

-- Expected invariant: total 211, gameplay approvals 0, originally preserved 3140.
SELECT queue_priority, phase5_review_status, COUNT(*) AS records
FROM airlinerra.airport_expansion_phase5_gate_reviews
GROUP BY queue_priority, phase5_review_status ORDER BY queue_priority, phase5_review_status;
