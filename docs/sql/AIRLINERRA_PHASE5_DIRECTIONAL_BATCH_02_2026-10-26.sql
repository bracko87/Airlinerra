-- Airlinerra Phase 5 Batch 2 direction-by-direction runway research, 2026-10-26.
-- Public reproducibility copy of applied Supabase migration:
-- airlinerra_phase5_batch2_directional_source_20261026.
-- Source rows are secondary FAA-derived listings from October 1, 2026.
-- No proof of official flight-date NOTAM, authorizations, certificated operator or gameplay admission.
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
CREATE INDEX IF NOT EXISTS phase5_runway_directions_screen_idx
 ON airlinerra.airport_expansion_phase5_runway_directions(screening_status);
ALTER TABLE airlinerra.airport_expansion_phase5_runway_directions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra.airport_expansion_phase5_runway_directions FROM PUBLIC, anon, authenticated;

-- Source-based direction findings for the ten Priority-2 airports.
-- ON CONFLICT DO NOTHING preserves any later independent authoritative reviews.
INSERT INTO airlinerra.airport_expansion_phase5_runway_directions
(airport_key, runway_end, runway_pair, source_pavement_length_ft, source_surface, threshold_displacement_ft, nominal_post_threshold_ft, source_published_lda_ft, distance_basis, screening_status, source_cycle_date, source_authority_level, source_url, restrictions_and_next_step)
VALUES
('OURAIRPORTS:18319', '08', '08/26', 4899, 'asphalt', 0, 4899, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/05C', 'RW08 has no displaced threshold reported; actual FAA direction-specific LDA, trees and selected aircraft/owner rights unverified.'),
('OURAIRPORTS:18319', '26', '08/26', 4899, 'asphalt', 1120, 3779, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/05C', 'RW26 threshold displaced 1,120ft; nominal available landing pavement 3,779ft below 1,200m; separate published FAA LDA still needs confirmation.'),
('OURAIRPORTS:18742', '04', '04/22', 3316, 'asphalt', 898, 2418, NULL, 'NOMINAL_FROM_THRESHOLD', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/3TR', 'Secondary poor broken asphalt 3,316ft total; physically below minimum regardless of threshold.'),
('OURAIRPORTS:18742', '15', '15/33', 4100, 'asphalt', 300, 3800, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/3TR', 'RW15 threshold displaced 300ft; nominal landing pavement 3,800ft below cutoff; obstacles and limited PAPI usable sector.'),
('OURAIRPORTS:18742', '22', '04/22', 3316, 'asphalt', 750, 2566, NULL, 'NOMINAL_FROM_THRESHOLD', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/3TR', 'Secondary poor broken asphalt 3,316ft total; physically below minimum regardless of threshold.'),
('OURAIRPORTS:18742', '33', '15/33', 4100, 'asphalt', 0, 4100, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/3TR', 'RW33 has no displaced threshold reported; physical length only ~50m above minimum; official LDA and 25,000lb S gear fit pending.'),
('OURAIRPORTS:19325', '11', '11/29', 4000, 'asphalt', 0, 4000, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/AUO', 'No displaced threshold listed on RW11; nominal margin ~19m above 1,200m, official LDA still unverified.'),
('OURAIRPORTS:19325', '18', '18/36', 5264, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/AUO', 'Longer grooved main asphalt 5,264ft; airport event PPR/tower hours and direction-specific official LDA to verify.'),
('OURAIRPORTS:19325', '29', '11/29', 4000, 'asphalt', 297, 3703, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/AUO', 'RW29 displaced 297ft; nominal landing pavement 3,703ft below minimum; runway is not presumed closed.'),
('OURAIRPORTS:19325', '36', '18/36', 5264, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/AUO', 'Longer grooved main asphalt 5,264ft; university permission, aircraft performance and direction-specific official LDA to verify.'),
('OURAIRPORTS:20304', '15', '15/33', 5100, 'asphalt', 1900, 3200, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/L65', 'RW15 displaced 1,900ft, nominal available 3,200ft. Daily skydiving/ultralights and 50ft paved width.'),
('OURAIRPORTS:20304', '33', '15/33', 5100, 'asphalt', 144, 4956, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/L65', 'RW33 nominal 4,956ft; actual officially published LDA not established. Private owner permission, skydive restrictions, and emergency-only fuel unresolved.'),
('OURAIRPORTS:20763', '01', '01/19', 5002, 'asphalt', 0, 5002, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/ORE', 'RW01 no threshold displacement listed; official LDA unverified; parachuting near airport April-November.'),
('OURAIRPORTS:20763', '14', '14/32', 4800, 'asphalt', 0, 4800, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/ORE', 'RW14 no displacement listed; official LDA still unverified; separate pavement/aircraft load.'),
('OURAIRPORTS:20763', '19', '01/19', 5002, 'asphalt', 1301, 3701, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/ORE', 'RW19 displaced threshold 1,301ft, nominal available 3,701ft below minimum; published LDA unverified.'),
('OURAIRPORTS:20763', '32', '14/32', 4800, 'asphalt', 1290, 3510, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/ORE', 'RW32 displaced threshold 1,290ft, nominal available 3,510ft below minimum; published LDA unverified.'),
('OURAIRPORTS:20783', '05', '05/23', 4011, 'asphalt', 270, 3741, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/OXD', 'RW05 displacement 270ft: nominal available 3,741ft below minimum; approach obstacles.'),
('OURAIRPORTS:20783', '23', '05/23', 4011, 'asphalt', 0, 4011, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/OXD', 'RW23 no threshold displacement; gross nominal available 4,011ft, only ~23m above minimum; official LDA pending. Jet A by request, owner/manager written use rights pending.'),
('OURAIRPORTS:20826', '12', '12/30', 1907, 'turf', NULL, NULL, 1758, 'PUBLISHED_LDA', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/PHD', 'Turf runway below minimum in length and surface; published LDA only 1,758ft.'),
('OURAIRPORTS:20826', '15', '15/33', 3951, 'asphalt', 330, 3621, 3621, 'PUBLISHED_LDA', 'PUBLISHED_LDA_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/PHD', 'FAA-derived published RW15 LDA 3,621ft; threshold displaced 330ft. Fails 1,200m even though runway length 3,951ft.'),
('OURAIRPORTS:20826', '30', '12/30', 1907, 'turf', NULL, NULL, 1758, 'PUBLISHED_LDA', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/PHD', 'Turf runway below minimum in length and surface; published LDA only 1,758ft.'),
('OURAIRPORTS:20826', '33', '15/33', 3951, 'asphalt', 0, 3951, 3634, 'PUBLISHED_LDA', 'PUBLISHED_LDA_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/PHD', 'FAA-derived published RW33 LDA 3,634ft, which is below 1,200m EVEN THOUGH no displaced threshold and full pavement length 3,951ft; do not use nominal.'),
('OURAIRPORTS:20896', '12', '12/30', 4415, 'asphalt', 295, 4120, 3785, 'PUBLISHED_LDA', 'PUBLISHED_LDA_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/PWK', 'FAA-derived published RW12 LDA 3,785ft BELOW minimum even though 4,120ft nominal pavement after displacement. Use official LDA, not 4,120.'),
('OURAIRPORTS:20896', '16', '16/34', 5001, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/PWK', 'Primary grooved asphalt 5,001ft with ILS, EMAS beyond ends; official RW16 LDA not in consulted extracted record.'),
('OURAIRPORTS:20896', '30', '12/30', 4415, 'asphalt', 432, 3983, 3725, 'PUBLISHED_LDA', 'PUBLISHED_LDA_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/PWK', 'FAA-derived published RW30 LDA 3,725ft BELOW minimum even though 3,983ft nominal pavement after displacement. Use official LDA, not 3,983.'),
('OURAIRPORTS:20896', '34', '16/34', 5001, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/PWK', 'Primary grooved asphalt 5,001ft with ILS, EMAS beyond ends; official RW34 LDA not in consulted extracted record.'),
('OURAIRPORTS:21047', '09L', '09L/27R', 5342, 'asphalt', 0, 5342, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/SEE', 'Main good asphalt no threshold displacement on RW09L, nominal 5,342ft; official direction-specific LDA and aircraft/approach suitability pending.'),
('OURAIRPORTS:21047', '09R', '09R/27L', 2738, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/SEE', 'Shorter runway 2,738ft, ineligible by physical length, with additional nighttime closure.'),
('OURAIRPORTS:21047', '17', '17/35', 4145, 'asphalt', 450, 3695, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/SEE', 'RW17 displaced 450ft, nominal available 3,695ft below minimum; other runway may be usable.'),
('OURAIRPORTS:21047', '27L', '09R/27L', 2738, 'asphalt', NULL, NULL, NULL, 'GROSS_ONLY', 'PHYSICAL_LENGTH_OR_SURFACE_INELIGIBLE', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/SEE', 'Shorter runway 2,738ft, ineligible by physical length, with additional nighttime closure.'),
('OURAIRPORTS:21047', '27R', '09L/27R', 5342, 'asphalt', 706, 4636, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/SEE', 'RW27R threshold displaced 706ft, nominal 4,636ft; official LDA, terrain/PAPI and carrier rights pending.'),
('OURAIRPORTS:21047', '35', '17/35', 4145, 'asphalt', 685, 3460, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/SEE', 'RW35 displaced 685ft, nominal available 3,460ft below minimum; other runway may be usable.'),
('OURAIRPORTS:21384', '02', '02/20', 4502, 'asphalt', 0, 4502, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/WVI', 'RW02 no displaced threshold reported, nominal 4,502ft; official LDA, trees/fog and availability pending.'),
('OURAIRPORTS:21384', '09', '09/27', 3998, 'asphalt', 0, 3998, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/WVI', 'RW09 gross and nominal 3,998ft, only ~19m above minimum; published LDA and trees/aircraft fit unresolved.'),
('OURAIRPORTS:21384', '20', '02/20', 4502, 'asphalt', 589, 3913, NULL, 'NOMINAL_FROM_THRESHOLD', 'NOMINAL_PAVEMENT_BELOW_1200M', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/WVI', 'RW20 displaced 589ft, nominal landing pavement 3,913ft, only ~7m below cutoff; official LDA and weather/straight-in approach pending.'),
('OURAIRPORTS:21384', '27', '09/27', 3998, 'asphalt', 0, 3998, NULL, 'NOMINAL_FROM_THRESHOLD', 'ALTERNATE_DIRECTION_LDA_UNVERIFIED', '2026-10-01', 'FAA_DERIVED_SECONDARY', 'https://www.airnav.com/airport/WVI', 'RW27 landing LDA remains unverified; separately, FAA-derived airport remarks PROHIBIT ALL RW27 DEPARTURES due to obstructed visibility. Do not confuse departure ban with landing restriction.')
ON CONFLICT (airport_key,runway_end) DO NOTHING;

-- Audit: 36 directions across 10 airports, 0 admitted directions.
SELECT screening_status,count(*) AS runway_directions
FROM airlinerra.airport_expansion_phase5_runway_directions
GROUP BY screening_status ORDER BY screening_status;
