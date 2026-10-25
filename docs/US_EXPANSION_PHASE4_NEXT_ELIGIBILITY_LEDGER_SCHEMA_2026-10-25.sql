-- Airlinerra US expansion Phase 4: source-backed next eligibility ledger
-- Applied to Supabase project hwllkabgzaynalahvkpz on 2026-10-25.
-- PRIVATE EVIDENCE ONLY. Neither this table nor its records approve airports for gameplay.
-- Preserves all Phase 3 first-pass selection rows and original 3,140 airport profiles.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_next_eligibility_phase4 (
    airport_key text PRIMARY KEY REFERENCES airlinerra.airport_expansion_selection_phase3(airport_key),
    faa_identifier text NOT NULL,
    review_batch_identifier text NOT NULL,
    runway_reviewed text NOT NULL,
    published_pavement_length_ft integer,
    published_lda_ft integer,
    runway_distance_gate text NOT NULL CHECK (runway_distance_gate IN (
        'PUBLISHED_LDA_ABOVE_1200M_PENDING_LIVE_CONFIRMATION',
        'DIRECTIONAL_LANDING_PAVEMENT_BELOW_1200M',
        'GROSS_LENGTH_ONLY_LDA_UNVERIFIED'
    )),
    pavement_aircraft_gate text NOT NULL,
    owner_permission_gate text NOT NULL DEFAULT 'NOT_VERIFIED',
    operator_certificate_gate text NOT NULL DEFAULT 'NOT_VERIFIED',
    notam_weather_gate text NOT NULL DEFAULT 'NOT_VERIFIED',
    next_gate_disposition text NOT NULL DEFAULT 'BLOCKED_PENDING_REQUIRED_EVIDENCE'
      CHECK (next_gate_disposition='BLOCKED_PENDING_REQUIRED_EVIDENCE'),
    case_summary text NOT NULL,
    next_verification_action text NOT NULL,
    evidence_urls text[] NOT NULL CHECK (cardinality(evidence_urls)>0),
    review_date date NOT NULL,
    game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED'
      CHECK (game_admission_status='NOT_APPROVED'),
    assessed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE airlinerra.airport_expansion_next_eligibility_phase4 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra.airport_expansion_next_eligibility_phase4 FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE airlinerra.airport_expansion_next_eligibility_phase4
IS 'Private, non-gameplay Phase 4 runway/carrier/owner evidence screening. First-pass Phase 3 selection statuses must not be changed. All records remain NOT_APPROVED.';
-- Expected next-gate invariants: no Phase 3 status mutation and zero admissions,
-- activations and category assignments in expansion cohorts.
