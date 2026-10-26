-- Airlinerra Phase 5 FAA AIM blank-LDA screening policy, 2026-10-26.
-- Schema is private and research-only: no airport, direction, or world approvals.
-- FAA AIM 4-3-6 allows *assumed* runway distances when no runway declared
-- distances are published, but an assumption is NOT a published FAA LDA.
-- Source: US DOT/BTS FAA NASR Oct 1 2026 government republication.
-- Original FAA archive was not independently downloaded/hashed.

CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_nasr_runway_physical (
 cycle_date date NOT NULL REFERENCES airlinerra.airport_faa_nasr_backfill_cycles(cycle_date),
 airport_key text NOT NULL,
 faa_identifier text NOT NULL,
 source_arpt_id text NOT NULL,
 site_no text NOT NULL,
 runway_pair text NOT NULL,
 source_objectid integer NOT NULL,
 length_ft integer,
 width_ft integer,
 surface_code text,
 surface_condition text,
 reported_length_source text,
 reported_length_source_date text,
 source_url text NOT NULL,
 raw_attributes jsonb NOT NULL,
 source_authority text NOT NULL DEFAULT 'USDOT_BTS_FAA_NASR_REPUBLICATION',
 collected_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(cycle_date,airport_key,runway_pair),
 CONSTRAINT airport_faa_nasr_physical_length_nonnegative CHECK(length_ft IS NULL OR length_ft>=0),
 CONSTRAINT airport_faa_nasr_physical_width_nonnegative CHECK(width_ft IS NULL OR width_ft>=0)
);
ALTER TABLE airlinerra.airport_faa_nasr_runway_physical ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_faa_nasr_runway_physical FROM anon,authenticated;
ALTER TABLE airlinerra.airport_faa_nasr_backfill_runway_ends
 ADD COLUMN IF NOT EXISTS displaced_threshold_source_ft integer,
 ADD COLUMN IF NOT EXISTS threshold_source_fields_retrieved boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS threshold_evidence jsonb,
 ADD COLUMN IF NOT EXISTS threshold_fields_retrieved_at timestamptz;
-- Existing applied database enforces displaced_threshold_source_ft >= 0.
-- On pristine database restoration, append a CHECK if not already present.

CREATE OR REPLACE VIEW airlinerra.airport_faa_aim_direction_screen
WITH (security_invoker=true)
AS
WITH source_end AS (
 SELECT e.*,
 bool_or(e.published_lda_ft IS NOT NULL OR e.published_tora_ft IS NOT NULL
 OR e.published_toda_ft IS NOT NULL OR e.published_asda_ft IS NOT NULL)
 OVER(PARTITION BY e.cycle_date,e.airport_key,e.runway_pair) AS pair_any_declared_distance
 FROM airlinerra.airport_faa_nasr_backfill_runway_ends e
 WHERE e.cycle_date='2026-10-01'
), joined AS (
 SELECT e.cycle_date,e.airport_key,e.faa_identifier,e.source_arpt_id,
 e.runway_pair,e.runway_end,e.published_lda_ft,e.published_tora_ft,
 e.published_toda_ft,e.published_asda_ft,e.pair_any_declared_distance,
 e.displaced_threshold_source_ft,e.threshold_source_fields_retrieved,
 e.source_lda_status,e.source_url,e.row_reconciliation_status,
 p.length_ft,p.width_ft,p.surface_code,p.surface_condition,
 p.source_url AS physical_source_url,p.reported_length_source_date,
 prior.screening_status AS prior_screening_status,
 prior.restrictions_and_next_step AS prior_restriction,c.original_archive_verified
 FROM source_end e
 LEFT JOIN airlinerra.airport_faa_nasr_runway_physical p
 ON p.cycle_date=e.cycle_date AND p.airport_key=e.airport_key AND p.runway_pair=e.runway_pair
 LEFT JOIN airlinerra.airport_expansion_phase5_runway_directions prior
 ON prior.airport_key=e.airport_key AND prior.runway_pair=e.runway_pair
 AND ltrim(prior.runway_end,'0')=ltrim(e.runway_end,'0')
 JOIN airlinerra.airport_faa_nasr_backfill_cycles c ON c.cycle_date=e.cycle_date
), computed AS (
 SELECT j.*,
 CASE WHEN j.published_lda_ft IS NULL AND NOT j.pair_any_declared_distance
 AND j.length_ft IS NOT NULL AND j.threshold_source_fields_retrieved
 AND j.displaced_threshold_source_ft IS DISTINCT FROM -1
 AND coalesce(j.displaced_threshold_source_ft,0)<=j.length_ft
 THEN j.length_ft - coalesce(j.displaced_threshold_source_ft,0)
 ELSE NULL END AS aim_assumed_landing_ft,
 CASE WHEN j.published_lda_ft IS NOT NULL
 THEN 'GOVERNMENT_REPUBLICATION_PUBLISHED_LDA'
 WHEN j.pair_any_declared_distance
 THEN 'PARTIAL_DECLARED_DISTANCES_REQUIRE_REVIEW'
 WHEN NOT j.threshold_source_fields_retrieved OR j.length_ft IS NULL
 THEN 'NO_SUFFICIENT_FAA_PHYSICAL_DATA'
 ELSE 'FAA_AIM_4_3_6_CONDITIONAL_ASSUMPTION_NOT_PUBLISHED_LDA'
 END AS distance_evidence_basis
 FROM joined j
)
SELECT cycle_date,airport_key,faa_identifier,source_arpt_id,runway_pair,runway_end,
 length_ft AS physical_runway_ft,width_ft AS physical_runway_width_ft,
 surface_code,surface_condition,displaced_threshold_source_ft,
 threshold_source_fields_retrieved,published_lda_ft,
 aim_assumed_landing_ft,distance_evidence_basis,pair_any_declared_distance,
 CASE
 WHEN prior_screening_status='LANDING_DIRECTION_PROHIBITED'
 THEN 'LANDING_DIRECTION_PROHIBITED'
 WHEN length_ft IS NULL THEN 'PHYSICAL_RUNWAY_NOT_IN_GOVERNMENT_LAYER'
 WHEN surface_code IS NULL OR surface_code NOT IN('ASPH','CONC','ASPH-CONC','CONC-ASPH')
 THEN 'NON_PAVED_OR_UNVERIFIED_SURFACE'
 WHEN length_ft<3938 THEN 'PHYSICAL_RUNWAY_BELOW_1200M'
 WHEN surface_condition IN('POOR','FAILED') OR prior_screening_status='PAVEMENT_CONDITION_HOLD'
 THEN 'PAVEMENT_CONDITION_HOLD'
 WHEN published_lda_ft IS NOT NULL AND published_lda_ft<3938
 THEN 'PUBLISHED_LDA_BELOW_1200M'
 WHEN published_lda_ft IS NOT NULL AND published_lda_ft>=3938
 THEN 'PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY'
 WHEN pair_any_declared_distance THEN 'PARTIAL_DECLARED_DISTANCES_MANUAL_REVIEW'
 WHEN NOT threshold_source_fields_retrieved THEN 'THRESHOLD_SOURCE_NOT_RETRIEVED'
 WHEN aim_assumed_landing_ft IS NULL THEN 'ASSUMPTION_INVALID_OR_INCOMPLETE'
 WHEN aim_assumed_landing_ft<3938 THEN 'AIM_ASSUMED_DISTANCE_BELOW_1200M'
 ELSE 'AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY'
 END AS distance_screen_status,
 'NOT_APPROVED'::text AS game_admission_status,
 original_archive_verified,source_url,physical_source_url,
 prior_screening_status,prior_restriction,reported_length_source_date
FROM computed;

REVOKE ALL ON airlinerra.airport_faa_aim_direction_screen FROM anon,authenticated;
-- 1,200 metres = 3,937.007874... feet; integer feet threshold >=3,938.
-- No numeric zero substitution for missing FAA published LDA.
-- Null DISPLACED_THR_LEN in a retrieved FAA end record is treated ONLY as
-- 'no displacement reported' within the AIM planning assumption. It does
-- not prove a certified landing distance or override local NOTAM restrictions.
-- Chart Supplement/airport operator confirmation remains required before use.
-- The view deliberately preserves 23 runway ends absent from the
-- geospatial runway physical layer as explicit NO_PHYSICAL holds.
SELECT distance_screen_status,count(*) FROM airlinerra.airport_faa_aim_direction_screen
GROUP BY distance_screen_status ORDER BY distance_screen_status;
