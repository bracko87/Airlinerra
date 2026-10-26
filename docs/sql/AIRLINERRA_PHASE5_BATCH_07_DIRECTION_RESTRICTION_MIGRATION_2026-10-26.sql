-- Airlinerra Phase 5 Batch 7, applied 2026-10-26.
-- Source-control archive for Supabase migration
-- airlinerra_phase5_batch7_direction_restriction_and_mixed_pavement_20261026.
-- Allows combinations of asphalt+concrete and explicit prohibited landing direction.
-- No gameplay approvals; existing NOT_APPROVED constraints remain.
ALTER TABLE airlinerra.airport_expansion_phase5_runway_directions
 DROP CONSTRAINT airport_expansion_phase5_runway_directio_screening_status_check,
 DROP CONSTRAINT phase5_distance_classification_check;

ALTER TABLE airlinerra.airport_expansion_phase5_runway_directions
 ADD CONSTRAINT airport_expansion_phase5_runway_directio_screening_status_check
 CHECK (screening_status IN (
  'PUBLISHED_LDA_BELOW_1200M',
  'PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION',
  'NOMINAL_PAVEMENT_BELOW_1200M',
  'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE',
  'ALTERNATE_DIRECTION_LDA_UNVERIFIED',
  'LANDING_DIRECTION_PROHIBITED')),
 ADD CONSTRAINT phase5_distance_classification_check CHECK (
   (screening_status='PUBLISHED_LDA_BELOW_1200M' AND source_published_lda_ft IS NOT NULL AND source_published_lda_ft<3938)
 OR (screening_status='PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION'
     AND source_published_lda_ft IS NOT NULL AND source_published_lda_ft>=3938
     AND lower(source_surface) IN ('asphalt','concrete','asphalt/concrete','concrete/asphalt'))
 OR (screening_status='NOMINAL_PAVEMENT_BELOW_1200M'
     AND nominal_post_threshold_ft IS NOT NULL AND nominal_post_threshold_ft<3938
     AND source_published_lda_ft IS NULL)
 OR (screening_status='PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE'
     AND (source_pavement_length_ft<3938 OR lower(source_surface) NOT IN ('asphalt','concrete','asphalt/concrete','concrete/asphalt')))
 OR (screening_status='ALTERNATE_DIRECTION_LDA_UNVERIFIED'
     AND source_published_lda_ft IS NULL
     AND (nominal_post_threshold_ft IS NULL OR nominal_post_threshold_ft>=3938)
     AND source_pavement_length_ft>=3938
     AND lower(source_surface) IN ('asphalt','concrete','asphalt/concrete','concrete/asphalt'))
 OR (screening_status='LANDING_DIRECTION_PROHIBITED'
     AND source_published_lda_ft IS NULL AND length(trim(restrictions_and_next_step))>20)
 );

-- The original table still constrains commercial_admission_status = NOT_APPROVED.
-- The airport gate table still constrains game_admission_status = NOT_APPROVED.
