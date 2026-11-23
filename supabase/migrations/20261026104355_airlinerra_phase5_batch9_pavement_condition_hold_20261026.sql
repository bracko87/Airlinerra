-- Preserve structurally long runways in bad surface condition as an independent HOLD.
-- Never treat runway length as a substitute for surface serviceability.
ALTER TABLE airlinerra.airport_expansion_phase5_runway_directions
 DROP CONSTRAINT airport_expansion_phase5_runway_directio_screening_status_check,
 DROP CONSTRAINT phase5_distance_classification_check;
ALTER TABLE airlinerra.airport_expansion_phase5_runway_directions
 ADD CONSTRAINT airport_expansion_phase5_runway_directio_screening_status_check
 CHECK (screening_status IN (
  'PUBLISHED_LDA_BELOW_1200M','PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION',
  'NOMINAL_PAVEMENT_BELOW_1200M','PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE',
  'ALTERNATE_DIRECTION_LDA_UNVERIFIED','LANDING_DIRECTION_PROHIBITED',
  'PAVEMENT_CONDITION_HOLD')),
 ADD CONSTRAINT phase5_distance_classification_check CHECK (
   (screening_status='PUBLISHED_LDA_BELOW_1200M' AND source_published_lda_ft IS NOT NULL AND source_published_lda_ft<3938)
 OR (screening_status='PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION' AND source_published_lda_ft IS NOT NULL AND source_published_lda_ft>=3938 AND lower(source_surface) IN ('asphalt','concrete','asphalt/concrete','concrete/asphalt'))
 OR (screening_status='NOMINAL_PAVEMENT_BELOW_1200M' AND nominal_post_threshold_ft IS NOT NULL AND nominal_post_threshold_ft<3938 AND source_published_lda_ft IS NULL)
 OR (screening_status='PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE' AND (source_pavement_length_ft<3938 OR lower(source_surface) NOT IN ('asphalt','concrete','asphalt/concrete','concrete/asphalt')))
 OR (screening_status='ALTERNATE_DIRECTION_LDA_UNVERIFIED' AND source_published_lda_ft IS NULL AND (nominal_post_threshold_ft IS NULL OR nominal_post_threshold_ft>=3938) AND source_pavement_length_ft>=3938 AND lower(source_surface) IN ('asphalt','concrete','asphalt/concrete','concrete/asphalt'))
 OR (screening_status='LANDING_DIRECTION_PROHIBITED' AND source_published_lda_ft IS NULL AND length(trim(restrictions_and_next_step))>20)
 OR (screening_status='PAVEMENT_CONDITION_HOLD' AND source_published_lda_ft IS NULL AND source_pavement_length_ft>=3938 AND lower(source_surface) IN ('asphalt','concrete','asphalt/concrete','concrete/asphalt') AND length(trim(restrictions_and_next_step))>20)
 );