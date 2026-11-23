CREATE TABLE IF NOT EXISTS airlinerra.airport_quality_audit_flags (
  airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key) ON DELETE CASCADE,
  flag_code text NOT NULL,
  risk_level text NOT NULL CHECK (risk_level IN ('HIGH','MEDIUM','LOW','INFO')),
  verification_status text NOT NULL CHECK (verification_status IN ('AUTO_SCREEN','SOURCE_CONFIRMED','NEEDS_INDEPENDENT_REVIEW')),
  audit_note text NOT NULL,
  evidence_url text,
  checked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (airport_key,flag_code)
);