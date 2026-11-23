CREATE TABLE IF NOT EXISTS airlinerra.airport_icao_manual_review_20261027 (
 airport_key text PRIMARY KEY REFERENCES airlinerra.airport_registry(airport_key),
 review_sequence integer NOT NULL UNIQUE,
 code_to_check text NOT NULL,
 code_evidence_status text NOT NULL CHECK (code_evidence_status IN ('SOURCE_REPORTED_ICAO','FOUR_LETTER_UNVERIFIED_ICAO')),
 review_status text NOT NULL DEFAULT 'PENDING' CHECK (review_status IN ('PENDING','REJECT_KNOWN','APPROVED_BY_OWNER','REJECTED_BY_OWNER','NEEDS_MORE_EVIDENCE')),
 manually_checked boolean NOT NULL DEFAULT false,
 confirmed_icao boolean,
 confirmed_runway boolean,
 confirmed_operational boolean,
 confirmed_civil_access boolean,
 manual_notes text,
 reviewed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE airlinerra.airport_icao_manual_review_20261027 IS 'Manual reviewer queue only. Existing game activation is not changed by checklist initialization. User approves reviewed selections later.';