CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_runway_technical_exceptions (
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 icao_code text NOT NULL,
 exception_type text NOT NULL CHECK(exception_type='OPERATOR_PAVED_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT'),
 source_paved_length_m numeric NOT NULL CHECK(source_paved_length_m>0 AND source_paved_length_m<1200),
 source_paved_width_m numeric NOT NULL CHECK(source_paved_width_m>0),
 runway_pair text NOT NULL,
 runway_surface text NOT NULL CHECK(runway_surface IN ('ASPHALT','CONCRETE')),
 source_landing_direction_a_m numeric,
 source_landing_direction_b_m numeric,
 registry_qualifying_length_m numeric NOT NULL CHECK(registry_qualifying_length_m>=1200),
 source_authority_grade text NOT NULL CHECK(source_authority_grade='CURRENT_AIRPORT_OPERATOR'),
 source_url text NOT NULL,
 evidence_notes text NOT NULL,
 required_reconciliation text NOT NULL,
 review_status text NOT NULL DEFAULT 'SOURCE_CONFLICT_EXCLUSION_REVIEW' CHECK(review_status='SOURCE_CONFLICT_EXCLUSION_REVIEW'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 simulation_world_active boolean NOT NULL DEFAULT false CHECK(NOT simulation_world_active),
 last_verified_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (batch_key,airport_key)
);
ALTER TABLE airlinerra.airport_expansion_runway_technical_exceptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_runway_technical_exceptions FROM PUBLIC,anon,authenticated;