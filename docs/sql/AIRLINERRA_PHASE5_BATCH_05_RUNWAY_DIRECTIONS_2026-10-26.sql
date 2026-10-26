-- Airlinerra Phase 5 Batch 5: reproducible evidence-only runway-end observations, 26 Oct 2026.
-- 18 records for eight airports, already applied in private Supabase project hwllkabgzaynalahvkpz.
-- Source-effective date is per-airport, including CUL's older 2026-08-06 record.
-- Official direction-specific published LDA not established; NO game approval or world activation.
-- Run this script only AFTER the Phase 5 table creation and Batch 3 status CHECK migration.
INSERT INTO airlinerra.airport_expansion_phase5_runway_directions
(airport_key, runway_end, runway_pair, source_pavement_length_ft, source_surface, threshold_displacement_ft, nominal_post_threshold_ft, source_published_lda_ft, distance_basis, screening_status, source_cycle_date, source_authority_level, source_url, restrictions_and_next_step)
VALUES
('OURAIRPORTS:19475', '18', '18/36', 5949, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CDS', 'Good active asphalt; official LDA unverified; 21k single-wheel and threshold lighting check.'),
('OURAIRPORTS:19475', '36', '18/36', 5949, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CDS', 'RW36 lights 60ft south of runway end; not itself a declared LDA; official source needed.'),
('OURAIRPORTS:19507', '18', '18/36', 5404, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CKM', 'Aircraft over 30000lb need one-hour PPR; runway PCR/30; LDA unverified.'),
('OURAIRPORTS:19507', '36', '18/36', 5404, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CKM', 'Same runway, one-hour PPR for >30000lb; LDA unverified.'),
('OURAIRPORTS:19509', '18', '18/36', 4001, 'concrete', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CKP', 'Only ~19.5m gross runway margin, S15000lb PCN9; LDA missing.'),
('OURAIRPORTS:19509', '36', '18/36', 4001, 'concrete', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CKP', 'Only ~19.5m gross runway margin, S15000lb PCN9; LDA missing.'),
('OURAIRPORTS:19534', '17', '17/35', 6005, 'asphalt', 641, 5364, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CON', 'RW17 threshold displaced 641ft; nominal 5364ft, NOT officially declared LDA.'),
('OURAIRPORTS:19534', '35', '17/35', 6005, 'asphalt', 0, 6005, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CON', 'RW35 physical/nominal 6005ft, true FAA published LDA not shown.'),
('OURAIRPORTS:19550', '05', '05/23', 4004, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CRG', '150ft stopways excluded, only ~20m gross margin, PAPI obstructions.'),
('OURAIRPORTS:19550', '14', '14/32', 4008, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CRG', '150ft stopways beyond ends excluded from 4008ft runway; official LDA missing.'),
('OURAIRPORTS:19550', '23', '05/23', 4004, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CRG', '150ft stopways excluded, only ~20m gross margin, PAPI restrictions.'),
('OURAIRPORTS:19550', '32', '14/32', 4008, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CRG', '150ft stopways excluded, ILS cannot establish declared LDA; official source pending.'),
('OURAIRPORTS:19566', '18', '18/36', 4000, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-08-06', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CUL', 'STALE FAA-derived Aug source, 4000ft gross and S12000lb, LDA pending.'),
('OURAIRPORTS:19566', '36', '18/36', 4000, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-08-06', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CUL', 'STALE FAA-derived Aug source, 4000ft gross and S12000lb, LDA pending.'),
('OURAIRPORTS:20243', '14', '14/32', 5499, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CPF', 'RW14 good paved main, approach obstacles; LDA not shown.'),
('OURAIRPORTS:20243', '32', '14/32', 5499, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CPF', 'RW32 PAPI limited and steep tree obstacles; actual LDA not shown.'),
('OURAIRPORTS:3474', '08', '08/26', 4683, 'asphalt', 0, 4683, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CXL', 'No displaced threshold RW08; nominal 4683ft is NOT published LDA.'),
('OURAIRPORTS:3474', '26', '08/26', 4683, 'asphalt', 160, 4523, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/CXL', '160ft threshold displacement, nominal 4523ft, NOT published LDA.')
ON CONFLICT (airport_key,runway_end) DO NOTHING;

SELECT p.faa_identifier,d.runway_end,d.screening_status,d.source_cycle_date,d.commercial_admission_status
FROM airlinerra.airport_expansion_phase5_runway_directions d
JOIN airlinerra.airport_expansion_phase5_gate_reviews p USING(airport_key)
WHERE p.phase5_batch_identifier='US_EXPANSION_PHASE5_MISSING_LDA_BATCH_05_2026_10_26'
ORDER BY p.faa_identifier,d.runway_end;
