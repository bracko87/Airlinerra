CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_independent_paved_runway_reviews (
 batch_key text NOT NULL, airport_key text NOT NULL,
 icao_code text NOT NULL,
 country_iso text NOT NULL DEFAULT 'DE' CHECK(country_iso='DE'),
 research_status text NOT NULL CHECK(research_status IN (
 'OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD',
 'SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED',
 'HISTORICAL_AIP_CURRENT_VERIFICATION_REQUIRED')),
 source_authority_grade text NOT NULL CHECK(source_authority_grade IN('CURRENT_AIRPORT_OPERATOR','SECONDARY_ONLY_CURRENT','HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK')),
 paved_runway_pair text NOT NULL, documented_physical_length_m numeric NOT NULL CHECK(documented_physical_length_m>=1200),
 documented_width_m numeric NOT NULL CHECK(documented_width_m>0),
 normalized_surface text NOT NULL CHECK(normalized_surface IN('CONCRETE','ASPHALT')),
 published_landing_direction_a_m numeric,
 published_landing_direction_b_m numeric,
 historic_registry_length_m numeric NOT NULL,
 physical_length_difference_m numeric GENERATED ALWAYS AS (documented_physical_length_m-historic_registry_length_m) STORED,
 source_url text NOT NULL, supporting_url text,
 evidence_notes text NOT NULL,
 next_review_action text NOT NULL,
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 simulation_world_active boolean NOT NULL DEFAULT false CHECK(simulation_world_active=false),
 researched_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),
 FOREIGN KEY(airport_key) REFERENCES airlinerra.airport_registry(airport_key)
);
ALTER TABLE airlinerra.airport_expansion_independent_paved_runway_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra.airport_expansion_independent_paved_runway_reviews FROM PUBLIC,anon,authenticated;