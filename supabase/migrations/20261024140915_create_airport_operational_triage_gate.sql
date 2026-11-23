CREATE TABLE airlinerra.airport_operational_triage (
  airport_key text PRIMARY KEY REFERENCES airlinerra.airport_commercial_verification(airport_key) ON DELETE RESTRICT,
  triage_status text NOT NULL DEFAULT 'PENDING' CHECK (triage_status IN (
    'PENDING','CONSTRAINT_CONFIRMED_HOLD','SOURCE_IDENTITY_RECONCILIATION','CURRENT_SCREEN_INELIGIBLE'
  )),
  restriction_category text,
  priority smallint NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 3),
  finding text,
  actions_required text,
  evidence_urls text[] NOT NULL DEFAULT '{}'::text[],
  evidence_effective_date date,
  triage_checked_at timestamptz,
  assessor text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (triage_status='PENDING' AND triage_checked_at IS NULL)
    OR (triage_status<>'PENDING' AND finding IS NOT NULL AND actions_required IS NOT NULL
      AND array_length(evidence_urls,1)>0 AND triage_checked_at IS NOT NULL)
  )
);
ALTER TABLE airlinerra.airport_operational_triage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_operational_triage FROM anon,authenticated;