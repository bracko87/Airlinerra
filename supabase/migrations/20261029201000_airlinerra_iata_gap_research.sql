-- World 1 IATA gap research. A "no-code" source record is never proof
-- that IATA officially has no assignment. Preserve all original approvals.
CREATE TABLE IF NOT EXISTS airlinerra_game.airport_iata_resolution (
  world_id smallint NOT NULL,
  airport_key text NOT NULL,
  candidate_iata text CHECK (candidate_iata IS NULL OR candidate_iata ~ '^[A-Z]{3}$'),
  research_status text NOT NULL CHECK (research_status IN (
    'operator_source_reported',
    'secondary_candidate_conflict',
    'not_reported_in_consulted_sources',
    'historical_or_reassigned',
    'authority_check_required',
    'fictional_not_applicable',
    'iata_authority_confirmed',
    'iata_authority_unassigned'
  )),
  code_disposition text NOT NULL DEFAULT 'keep_unknown' CHECK (code_disposition IN (
    'keep_unknown','source_reported_only','verified_iata_code','verified_unassigned','not_applicable'
  )),
  evidence_note text NOT NULL,
  evidence_urls jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(evidence_urls)='array'),
  source_organization text,
  source_checked_on date NOT NULL DEFAULT CURRENT_DATE,
  authority_verified_on date,
  reviewed_by text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(world_id,airport_key),
  FOREIGN KEY(world_id,airport_key) REFERENCES
    airlinerra_game.airport_reference_profiles(world_id,airport_key) ON DELETE RESTRICT,
  CHECK(research_status NOT IN ('iata_authority_confirmed','iata_authority_unassigned')
    OR (authority_verified_on IS NOT NULL AND reviewed_by IS NOT NULL
      AND source_organization IS NOT NULL)),
  CHECK(code_disposition <> 'verified_iata_code' OR
    (research_status='iata_authority_confirmed' AND candidate_iata IS NOT NULL))
);
ALTER TABLE airlinerra_game.airport_iata_resolution ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.airport_iata_resolution FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS airport_iata_resolution_status_idx
  ON airlinerra_game.airport_iata_resolution(world_id,research_status);
-- The operator explicitly publishes QGY for ICAO LHPR. This is a sourced
-- IATA claim, not an assertion of verified IATA-assignment database access.
UPDATE airlinerra_game.airport_reference_profiles
SET iata_reported='QGY', refreshed_at=now()
WHERE world_id=1 AND airport_key='OURAIRPORTS:4303'
  AND iata_reported IS NULL AND icao_reported='LHPR' AND country_iso='HU'
  AND NOT EXISTS(
    SELECT 1 FROM airlinerra_game.airport_reference_profiles p
    WHERE p.world_id=1 AND p.airport_key<>'OURAIRPORTS:4303' AND p.iata_reported='QGY'
  );
UPDATE airlinerra_game.airport_identity_geography_audit
SET code_statuses=jsonb_set(code_statuses,'{iata}',to_jsonb('operator_source_reported'::text),true),
    fields_not_reported=array_remove(fields_not_reported,'iata_not_reported'),
    fields_to_verify=CASE WHEN 'iata_official_assignment' = ANY(fields_to_verify)
     THEN fields_to_verify ELSE array_append(fields_to_verify,'iata_official_assignment') END,
    audit_status='researching'
WHERE world_id=1 AND airport_key='OURAIRPORTS:4303'
  AND code_statuses->>'iata'='not_reported'
  AND EXISTS(
    SELECT 1 FROM airlinerra_game.airport_reference_profiles p
    WHERE p.world_id=1 AND p.airport_key='OURAIRPORTS:4303' AND p.iata_reported='QGY'
  );
INSERT INTO airlinerra_game.airport_field_evidence
  (world_id,airport_key,field_path,evidence_value,source_authority,source_url,
  source_license,source_observed_on,verification,reviewer_note)
SELECT 1,'OURAIRPORTS:4303','codes.iata',
  '{"code":"QGY","source_type":"airport_operator","verification":"operator_source_reported_not_iata_authority"}'::jsonb,
  'Gyor-Per Airport official operator',
  'https://lhpr.hu/en_EN/airport-data',
  NULL,date '2026-10-29','unverified',
  'Airport operator explicitly lists IATA QGY and ICAO LHPR. IATA official coding-directory confirmation pending.'
WHERE NOT EXISTS(
  SELECT 1 FROM airlinerra_game.airport_field_evidence e
  WHERE e.world_id=1 AND e.airport_key='OURAIRPORTS:4303'
    AND e.field_path='codes.iata' AND e.source_url='https://lhpr.hu/en_EN/airport-data'
);
