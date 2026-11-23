CREATE TABLE IF NOT EXISTS airlinerra.airport_candidate_preapproval_pool (
  airport_key text PRIMARY KEY REFERENCES airlinerra.airport_registry(airport_key),
  review_sequence integer NOT NULL UNIQUE,
  approved_category text NOT NULL CHECK (approved_category IN ('Local','Regional','Medium','Large','Major Hub','Mega Hub')),
  decision_status text NOT NULL DEFAULT 'PRE_APPROVED' CHECK (decision_status IN ('PRE_APPROVED','PROMOTED_TO_WORLD1','WITHDRAWN')),
  reviewed_by text NOT NULL DEFAULT 'OWNER_CHECKLIST',
  review_note text,
  preapproved_at timestamptz NOT NULL DEFAULT now(),
  promoted_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE airlinerra.airport_candidate_preapproval_pool IS 'Staging-only owner-checked Airlinerra candidate airports. Does not grant World 1 playable status. Six approved category levels are mandatory.';
ALTER TABLE airlinerra.airport_icao_manual_review_20261027
  ADD COLUMN IF NOT EXISTS proposed_category text,
  ADD COLUMN IF NOT EXISTS reviewed_category text;
ALTER TABLE airlinerra.airport_icao_manual_review_20261027
  DROP CONSTRAINT IF EXISTS airport_icao_manual_review_20261027_review_status_check;
ALTER TABLE airlinerra.airport_icao_manual_review_20261027
  DROP CONSTRAINT IF EXISTS airport_icao_manual_review_20261027_review_status_che;
ALTER TABLE airlinerra.airport_icao_manual_review_20261027
  ADD CONSTRAINT airport_icao_manual_review_status_new_check
  CHECK (review_status IN ('PENDING','REJECT_KNOWN','APPROVED_BY_OWNER','REJECTED_BY_OWNER','NEEDS_MORE_EVIDENCE','PRE_APPROVED','EXCLUDED_UNCHECKED'));
ALTER TABLE airlinerra.airport_icao_manual_review_20261027
  ADD CONSTRAINT airport_icao_manual_reviewed_category_six_check
  CHECK (reviewed_category IS NULL OR reviewed_category IN ('Local','Regional','Medium','Large','Major Hub','Mega Hub'));
ALTER TABLE airlinerra.airport_icao_manual_review_20261027
  ADD CONSTRAINT airport_icao_manual_proposed_category_six_check
  CHECK (proposed_category IS NULL OR proposed_category IN ('Local','Regional','Medium','Large','Major Hub','Mega Hub'));