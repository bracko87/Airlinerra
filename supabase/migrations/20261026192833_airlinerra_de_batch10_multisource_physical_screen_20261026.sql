CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_batch10_multisource_runway_screen (
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 airport_code text NOT NULL,
 runway_pair text NOT NULL,
 physical_paved_screen text NOT NULL
 CHECK (physical_paved_screen='CORROBORATED_GEOMETRY_REQUIRES_EFFECTIVE_AIP_REVALIDATION'),
 source_quality text NOT NULL,
 physical_paved_runway_m numeric NOT NULL CHECK(physical_paved_runway_m>=1200),
 physical_width_m numeric NOT NULL CHECK(physical_width_m>0),
 normalized_surface text NOT NULL CHECK(normalized_surface IN('ASPHALT','CONCRETE')),
 historic_registry_runway_m numeric NOT NULL,
 alternative_published_physical_m numeric,
 published_end_a_lda_m numeric,
 published_end_b_lda_m numeric,
 lda_source_recency text NOT NULL,
 latest_effective_aip_verified boolean NOT NULL DEFAULT false CHECK(NOT latest_effective_aip_verified),
 physical_source_url text NOT NULL,
 independent_supporting_url text NOT NULL,
 third_source_url text,
 runway_provenance_note text NOT NULL,
 unresolved_aip_or_direction_issue text NOT NULL,
 aircraft_specific_operating_permission boolean NOT NULL DEFAULT false CHECK(NOT aircraft_specific_operating_permission),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 game_world_activation_authorized boolean NOT NULL DEFAULT false CHECK(NOT game_world_activation_authorized),
 checked_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),
 UNIQUE(batch_key,airport_code)
);
ALTER TABLE airlinerra.airport_expansion_de_batch10_multisource_runway_screen ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_batch10_multisource_runway_screen FROM PUBLIC,anon,authenticated;