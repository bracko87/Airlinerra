CREATE TABLE IF NOT EXISTS airlinerra.airport_independent_runway_checks_20261027 (
 airport_key text PRIMARY KEY REFERENCES airlinerra.airport_registry(airport_key),
 checked_on date NOT NULL DEFAULT '2026-10-27',
 checked_runway_length_m numeric,
 checked_paved_length_m numeric,
 checked_surface text NOT NULL,
 check_outcome text NOT NULL CHECK(check_outcome IN ('ACCEPT','REJECT','NEEDS_FOLLOWUP')),
 basis text NOT NULL CHECK(basis IN ('FAA_2026','AIRPORT_OPERATOR','STATE_AUTHORITY_HISTORIC','MIXED_FAA_HISTORICAL')),
 source_url text NOT NULL,
 review_note text NOT NULL,
 checked_at timestamptz NOT NULL DEFAULT now()
);