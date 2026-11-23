CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_operator_runway_source_issues(
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 icao_code text NOT NULL,
 issue_code text NOT NULL CHECK(issue_code IN(
  'OPERATOR_PHYSICAL_LENGTH_LDA_CONTRADICTION',
  'DIRECTIONAL_LDA_BELOW_1200_AND_PHYSICAL_SOURCE_RECONCILIATION')),
 runway_pair text NOT NULL,
 operator_reported_physical_m numeric,
 source_landing_a_m numeric,
 source_landing_b_m numeric,
 historic_registry_runway_m numeric NOT NULL,
 source_url text NOT NULL,
 supporting_url text,
 explanation text NOT NULL,
 next_step text NOT NULL,
 case_status text NOT NULL DEFAULT 'SOURCE_RECONCILIATION_HOLD'
  CHECK(case_status='SOURCE_RECONCILIATION_HOLD'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED'
  CHECK(game_admission_status='NOT_APPROVED'),
 simulation_world_active boolean NOT NULL DEFAULT false CHECK(NOT simulation_world_active),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key)
);
ALTER TABLE airlinerra.airport_expansion_operator_runway_source_issues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_operator_runway_source_issues FROM PUBLIC,anon,authenticated;