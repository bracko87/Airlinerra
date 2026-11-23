CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_specialist_batch11_decisions (
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 airport_code text NOT NULL,
 decision text NOT NULL CHECK(decision IN (
 'PROVISIONAL_BELOW_1200_OPERATOR_RUNWAY_AIP_RECONCILIATION',
 'PHYSICAL_PAVED_RUNWAY_PASS_CIVIL_LDA_1140_BOTH_ENDS',
 'PHYSICAL_PAVED_RUNWAY_CORROBORATED_TEMP_NOTAM_HOLD'
 )),
 operator_or_source_physical_m numeric NOT NULL CHECK(operator_or_source_physical_m>0),
 pavement_width_m numeric,
 runway_pair text NOT NULL,
 surface text NOT NULL CHECK(surface IN('ASPHALT','CONCRETE')),
 historical_registry_length_m numeric NOT NULL,
 direction_a_lda_m numeric,
 direction_b_lda_m numeric,
 physical_collection_screen_pass boolean NOT NULL,
 temporary_or_civil_operational_hold boolean NOT NULL,
 authority_grade text NOT NULL,
 primary_url text NOT NULL,
 independent_url text NOT NULL,
 secondary_url text,
 evidence_note text NOT NULL,
 outstanding_aip_action text NOT NULL,
 notam_reference text,
 revisit_on date,
 latest_effective_aip_verified boolean NOT NULL DEFAULT false CHECK(NOT latest_effective_aip_verified),
 aircraft_flight_approval boolean NOT NULL DEFAULT false CHECK(NOT aircraft_flight_approval),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 game_activation_authorized boolean NOT NULL DEFAULT false CHECK(NOT game_activation_authorized),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),
 UNIQUE(batch_key,airport_code),
 CHECK (decision <> 'PROVISIONAL_BELOW_1200_OPERATOR_RUNWAY_AIP_RECONCILIATION' OR (operator_or_source_physical_m<1200 AND NOT physical_collection_screen_pass)),
 CHECK (decision <> 'PHYSICAL_PAVED_RUNWAY_PASS_CIVIL_LDA_1140_BOTH_ENDS' OR (operator_or_source_physical_m>=1200 AND physical_collection_screen_pass AND direction_a_lda_m=1140 AND direction_b_lda_m=1140 AND temporary_or_civil_operational_hold)),
 CHECK (decision <> 'PHYSICAL_PAVED_RUNWAY_CORROBORATED_TEMP_NOTAM_HOLD' OR (operator_or_source_physical_m>=1200 AND physical_collection_screen_pass AND temporary_or_civil_operational_hold AND notam_reference IS NOT NULL AND revisit_on IS NOT NULL))
);
ALTER TABLE airlinerra.airport_expansion_de_specialist_batch11_decisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_specialist_batch11_decisions FROM PUBLIC, anon, authenticated;