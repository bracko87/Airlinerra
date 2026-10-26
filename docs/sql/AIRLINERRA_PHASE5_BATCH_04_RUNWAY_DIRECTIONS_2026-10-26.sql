-- Airlinerra Phase 5 Batch 4 — source archive of 12 runway-end records (2026-10-26).
-- Apply only after Batch 2 table and Batch 3 positive-LDA check migration.
-- These source records were already written to Supabase and post-write verified.
-- All official current-cycle FAA LDA checks still pending; all airports NOT_APPROVED.
INSERT INTO airlinerra.airport_expansion_phase5_runway_directions
(airport_key, runway_end, runway_pair, source_pavement_length_ft, source_surface, threshold_displacement_ft, nominal_post_threshold_ft, source_published_lda_ft, distance_basis, screening_status, source_cycle_date, source_authority_level, source_url, restrictions_and_next_step)
VALUES
('OURAIRPORTS:19329', '05', '05/23', 5374, 'asphalt', 0, 5374, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/AVO', 'No displaced threshold listed; nominal 5374ft, official LDA missing'),
('OURAIRPORTS:19329', '10', '10/28', 3844, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/AVO', 'Secondary RW10 only 3844ft gross, below minimum'),
('OURAIRPORTS:19329', '23', '05/23', 5374, 'asphalt', 1044, 4330, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/AVO', 'RW23 displaced 1044ft, nominal 4330ft; authoritative published LDA missing'),
('OURAIRPORTS:19329', '28', '10/28', 3844, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/AVO', 'Secondary RW28 only 3844ft gross, below minimum'),
('OURAIRPORTS:19397', '03', '03/21', 4600, 'concrete', 600, 4000, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-09-03', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/BNO', 'RW03 threshold 600ft displaced, 4000ft nominal pavement only, official LDA missing'),
('OURAIRPORTS:19397', '12', '12/30', 5101, 'concrete', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-09-03', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/BNO', 'RW12 physical 5101ft, old September source, official LDA missing'),
('OURAIRPORTS:19397', '21', '03/21', 4600, 'concrete', 0, 4600, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-09-03', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/BNO', 'RW21 no displaced threshold reported, physical 4600ft, official LDA missing'),
('OURAIRPORTS:19397', '30', '12/30', 5101, 'concrete', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-09-03', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/BNO', 'RW30 physical 5101ft, old September source, official LDA missing'),
('OURAIRPORTS:19454', '01', '01/19', 2471, 'asphalt/gravel', NULL, NULL, NULL, 'GROSS_ONLY', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/C80', 'RW01 explicitly closed after pavement failure, only 2471ft gross'),
('OURAIRPORTS:19454', '12', '12/30', 5000, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/C80', 'RW12 fair 5000ft asphalt, official LDA missing; other runway closure does not disqualify'),
('OURAIRPORTS:19454', '19', '01/19', 2471, 'asphalt/gravel', NULL, NULL, NULL, 'GROSS_ONLY', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/C80', 'RW19 explicitly closed, damaged and under 1200m'),
('OURAIRPORTS:19454', '30', '12/30', 5000, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/C80', 'RW30 fair 5000ft asphalt, VGSI out of service, official LDA missing')
ON CONFLICT (airport_key,runway_end) DO NOTHING;

SELECT p.faa_identifier,d.runway_end,d.screening_status,d.source_cycle_date,d.commercial_admission_status
FROM airlinerra.airport_expansion_phase5_runway_directions d
JOIN airlinerra.airport_expansion_phase5_gate_reviews p USING(airport_key)
WHERE p.phase5_batch_identifier='US_EXPANSION_PHASE5_MISSING_LDA_BATCH_04_2026_10_26'
ORDER BY p.faa_identifier,d.runway_end;
