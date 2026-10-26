-- Airlinerra Phase 5 Batch 3: source-controlled record of migration
-- Applied in Supabase project hwllkabgzaynalahvkpz on 2026-10-26.
-- Supports secondary-source *published* positive LDA observations, without authorizing gameplay.
ALTER TABLE airlinerra.airport_expansion_phase5_runway_directions
 DROP CONSTRAINT airport_expansion_phase5_runway_directio_screening_status_check,
 DROP CONSTRAINT phase5_distance_classification_check;

ALTER TABLE airlinerra.airport_expansion_phase5_runway_directions
 ADD CONSTRAINT airport_expansion_phase5_runway_directio_screening_status_check
 CHECK (screening_status IN (
 'PUBLISHED_LDA_BELOW_1200M','PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION',
 'NOMINAL_PAVEMENT_BELOW_1200M','PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE',
 'ALTERNATE_DIRECTION_LDA_UNVERIFIED')),
 ADD CONSTRAINT phase5_distance_classification_check CHECK (
 (screening_status='PUBLISHED_LDA_BELOW_1200M' AND source_published_lda_ft IS NOT NULL AND source_published_lda_ft<3938)
 OR (screening_status='PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION' AND source_published_lda_ft IS NOT NULL AND source_published_lda_ft>=3938 AND lower(source_surface) IN ('asphalt','concrete'))
 OR (screening_status='NOMINAL_PAVEMENT_BELOW_1200M' AND nominal_post_threshold_ft IS NOT NULL AND nominal_post_threshold_ft<3938 AND source_published_lda_ft IS NULL)
 OR (screening_status='PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE' AND (source_pavement_length_ft<3938 OR lower(source_surface) NOT IN ('asphalt','concrete')))
 OR (screening_status='ALTERNATE_DIRECTION_LDA_UNVERIFIED' AND source_published_lda_ft IS NULL AND (nominal_post_threshold_ft IS NULL OR nominal_post_threshold_ft>=3938) AND source_pavement_length_ft>=3938 AND lower(source_surface) IN ('asphalt','concrete'))
 );

-- Actual applied source observations; reruns are idempotent.
-- Not original FAA NASR verification or proof of lawful commercial use.
INSERT INTO airlinerra.airport_expansion_phase5_runway_directions
(airport_key,runway_end,runway_pair,source_pavement_length_ft,source_surface,
 threshold_displacement_ft,nominal_post_threshold_ft,source_published_lda_ft,
 distance_basis,screening_status,source_cycle_date,source_authority_level,source_url,
 restrictions_and_next_step)
VALUES
('OURAIRPORTS:18736','18','18/36',4807,'asphalt',125,4682,4682,'PUBLISHED_LDA','PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION','2026-10-01','FAA_DERIVED_SECONDARY','https://www.airnav.com/airport/3S4','3S4 RW18 secondary-source LDA 4682ft, already incorporates 125ft threshold displacement. Independently validate current FAA record, load, rescue, commercial rights and operator.'),
('OURAIRPORTS:18736','36','18/36',4807,'asphalt',NULL,NULL,4682,'PUBLISHED_LDA','PUBLISHED_LDA_ABOVE_1200M_PENDING_REVALIDATION','2026-10-01','FAA_DERIVED_SECONDARY','https://www.airnav.com/airport/3S4','3S4 RW36 secondary-source published LDA 4682ft despite gross 4807ft. Independently verify official current record, aircraft and operating gates.'),
('OURAIRPORTS:18957','02','02/20',3986,'asphalt',233,3753,NULL,'NOMINAL_FROM_THRESHOLD','NOMINAL_PAVEMENT_BELOW_1200M','2026-10-01','FAA_DERIVED_SECONDARY','https://www.airnav.com/airport/64S','64S RW02 nominal 3986-233=3753ft, below game minimum. Official published LDA not established. Hold.'),
('OURAIRPORTS:18957','20','02/20',3986,'asphalt',231,3755,NULL,'NOMINAL_FROM_THRESHOLD','NOMINAL_PAVEMENT_BELOW_1200M','2026-10-01','FAA_DERIVED_SECONDARY','https://www.airnav.com/airport/64S','64S RW20 nominal 3986-231=3755ft, below game minimum. Official published LDA not established. Hold.')
ON CONFLICT(airport_key,runway_end) DO NOTHING;

-- Verification: 40 directions across 12 airports (36 Batch 2 + 4 Batch 3).
SELECT screening_status,COUNT(*) FROM airlinerra.airport_expansion_phase5_runway_directions GROUP BY 1;
