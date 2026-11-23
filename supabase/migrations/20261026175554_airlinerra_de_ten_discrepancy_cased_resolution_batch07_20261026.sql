CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_runway_resolution_cases(
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 airport_code text NOT NULL,
 source_grade text NOT NULL CHECK(source_grade IN(
  'OPERATOR_2025_CURRENT_PUBLICATION_WITH_OLDER_TECHNICAL_TABLE',
  'CURRENT_AIRPORT_OPERATOR_DOCUMENTED_PHYSICAL',
  'HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK',
  'CURRENT_OR_LOCAL_SECONDARY_WITH_UNRESOLVED_CONFLICT',
  'SECONDARY_WITHOUT_CURRENT_OFFICIAL_RUNWAY',
  'ON_FIELD_FLYING_GROUP_OPERATOR_NOT_VERIFIED',
  'DIRECTIONAL_LDA_CONFIRMED_PHYSICAL_SOURCE_UNRESOLVED'
 )),
 disposition text NOT NULL CHECK(disposition IN(
 'PAVED_RUNWAY_CONFIRMED_LANDING_DIRECTION_EXCEPTION',
 'PAVED_RUNWAY_CONFIRMED_DECLARED_DISTANCE_CONFLICT',
 'AWAIT_CURRENT_OFFICIAL_PAVED_RUNWAY_EVIDENCE',
 'AWAIT_CURRENT_OFFICIAL_AIP_REVALIDATION',
 'AWAIT_PAVEMENT_SUBTYPE_AUTHORITY',
 'AWAIT_OPERATOR_RUNWAY_DIMENSIONS',
 'AWAIT_AIRPORT_IDENTITY_CROSSWALK'
 )),
 source_url text NOT NULL,
 supporting_url text,
 physical_runway_length_m numeric,
 physical_runway_width_m numeric,
 landing_end_a_m numeric,
 landing_end_b_m numeric,
 evidence_summary text NOT NULL,
 next_source_action text NOT NULL,
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED'
  CHECK(game_admission_status='NOT_APPROVED'),
 world_activation_allowed boolean NOT NULL DEFAULT false
  CHECK(NOT world_activation_allowed),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),
 UNIQUE(batch_key,airport_code)
);
ALTER TABLE airlinerra.airport_expansion_de_runway_resolution_cases ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_runway_resolution_cases FROM PUBLIC,anon,authenticated;