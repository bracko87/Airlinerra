CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_phase5_runway_directions (
 airport_key text NOT NULL REFERENCES airlinerra.airport_expansion_phase5_gate_reviews(airport_key) ON DELETE RESTRICT,
 runway_end text NOT NULL CHECK (length(trim(runway_end)) BETWEEN 1 AND 8),
 runway_pair text NOT NULL,
 source_pavement_length_ft integer NOT NULL CHECK (source_pavement_length_ft>0),
 source_surface text NOT NULL,
 threshold_displacement_ft integer CHECK (threshold_displacement_ft>=0),
 nominal_post_threshold_ft integer CHECK (nominal_post_threshold_ft>0),
 source_published_lda_ft integer CHECK (source_published_lda_ft>0),
 distance_basis text NOT NULL CHECK (distance_basis IN ('PUBLISHED_LDA','NOMINAL_FROM_THRESHOLD','GROSS_ONLY')),
 screening_status text NOT NULL CHECK (screening_status IN ('PUBLISHED_LDA_BELOW_1200M','NOMINAL_PAVEMENT_BELOW_1200M','PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE','ALTERNATE_DIRECTION_LDA_UNVERIFIED')),
 source_cycle_date date,
 source_authority_level text NOT NULL DEFAULT 'FAA_DERIVED_SECONDARY',
 source_url text NOT NULL CHECK (source_url ~ '^https://'),
 restrictions_and_next_step text NOT NULL,
 commercial_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK (commercial_admission_status='NOT_APPROVED'),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT airport_expansion_phase5_runway_directions_pkey PRIMARY KEY (airport_key,runway_end),
 CONSTRAINT phase5_nominal_exceeds_pavement_check CHECK (nominal_post_threshold_ft IS NULL OR nominal_post_threshold_ft<=source_pavement_length_ft),
 CONSTRAINT phase5_threshold_nominal_consistency_check CHECK (threshold_displacement_ft IS NULL OR nominal_post_threshold_ft IS NULL OR nominal_post_threshold_ft=source_pavement_length_ft-threshold_displacement_ft),
 CONSTRAINT phase5_distance_classification_check CHECK (
 (screening_status='PUBLISHED_LDA_BELOW_1200M' AND source_published_lda_ft IS NOT NULL AND source_published_lda_ft < 3938)
 OR (screening_status='NOMINAL_PAVEMENT_BELOW_1200M' AND nominal_post_threshold_ft IS NOT NULL AND nominal_post_threshold_ft < 3938 AND source_published_lda_ft IS NULL)
 OR (screening_status='PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE' AND (source_pavement_length_ft<3938 OR lower(source_surface) NOT IN ('asphalt','concrete')))
 OR (screening_status='ALTERNATE_DIRECTION_LDA_UNVERIFIED' AND source_published_lda_ft IS NULL AND (nominal_post_threshold_ft IS NULL OR nominal_post_threshold_ft>=3938) AND source_pavement_length_ft>=3938 AND lower(source_surface) IN ('asphalt','concrete'))
 )
);
CREATE INDEX IF NOT EXISTS phase5_runway_directions_screen_idx ON airlinerra.airport_expansion_phase5_runway_directions(screening_status);
ALTER TABLE airlinerra.airport_expansion_phase5_runway_directions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra.airport_expansion_phase5_runway_directions FROM PUBLIC,anon,authenticated;