-- Airlinerra Phase 5 US FAA October-2026 runway declared-distance evidence backfill.
-- Source: US DOT Bureau of Transportation Statistics NTAD Runway Ends Table,
-- which republishes FAA NASR APT_RWY_END without modifying the original table.
-- This schema is research-only; does NOT approve airports or activate worlds.
-- October FAA subscription original ZIP was not independently downloaded/hash checked.
--
-- Applied to private Supabase hwllkabgzaynalahvkpz on 2026-10-26.
-- Replay this schema before loading the eight CSV archive parts.
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_nasr_backfill_cycles (
 cycle_date date PRIMARY KEY,
 source_dataset text NOT NULL,
 source_registry_url text NOT NULL,
 original_faa_archive_url text,
 delivery_authority text NOT NULL,
 original_archive_sha256 text,
 original_archive_verified boolean NOT NULL DEFAULT false,
 dataset_observed_at timestamptz NOT NULL DEFAULT now(),
 notes text NOT NULL,
 CONSTRAINT airport_faa_nasr_no_unverified_hash CHECK (
  original_archive_verified = false OR original_archive_sha256 IS NOT NULL
 )
);
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_nasr_backfill_runway_ends (
 cycle_date date NOT NULL REFERENCES airlinerra.airport_faa_nasr_backfill_cycles(cycle_date),
 airport_key text NOT NULL,
 faa_identifier text NOT NULL,
 source_arpt_id text NOT NULL,
 site_no text NOT NULL,
 source_state_code text,
 runway_pair text NOT NULL,
 runway_end text NOT NULL,
 source_objectid integer NOT NULL,
 published_lda_ft integer,
 published_tora_ft integer,
 published_toda_ft integer,
 published_asda_ft integer,
 source_lda_status text NOT NULL CHECK (
  source_lda_status IN ('SOURCE_PUBLISHED_LDA','SOURCE_LDA_BLANK')
 ),
 row_reconciliation_status text NOT NULL DEFAULT 'NOT_RECONCILED' CHECK (
  row_reconciliation_status IN ('NOT_RECONCILED','MATCHED_PRIOR_SECONDARY',
   'SECONDARY_DISCREPANCY','NEW_DIRECTION_NOT_IN_PRIOR_LEDGER','REVIEW_REQUIRED')
 ),
 commercial_admission_status text NOT NULL DEFAULT 'NOT_APPROVED'
  CHECK(commercial_admission_status='NOT_APPROVED'),
 source_url text NOT NULL,
 source_attributes jsonb NOT NULL,
 captured_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(cycle_date,airport_key,runway_pair,runway_end),
 CONSTRAINT airport_faa_nasr_lda_consistency CHECK (
  (source_lda_status='SOURCE_LDA_BLANK' AND published_lda_ft IS NULL)
  OR (source_lda_status='SOURCE_PUBLISHED_LDA' AND published_lda_ft IS NOT NULL AND published_lda_ft>=0)
 )
);
CREATE INDEX IF NOT EXISTS airport_faa_nasr_airport_id_idx
 ON airlinerra.airport_faa_nasr_backfill_runway_ends(cycle_date,source_arpt_id);
CREATE INDEX IF NOT EXISTS airport_faa_nasr_lda_not_null_idx
 ON airlinerra.airport_faa_nasr_backfill_runway_ends(cycle_date,published_lda_ft)
 WHERE published_lda_ft IS NOT NULL;
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_nasr_backfill_airport_coverage (
 cycle_date date NOT NULL REFERENCES airlinerra.airport_faa_nasr_backfill_cycles(cycle_date),
 airport_key text NOT NULL,
 faa_identifier text NOT NULL,
 source_arpt_id text,
 site_no text,
 retrieved_direction_count integer NOT NULL DEFAULT 0 CHECK(retrieved_direction_count>=0),
 published_lda_direction_count integer NOT NULL DEFAULT 0 CHECK(published_lda_direction_count>=0),
 blank_lda_direction_count integer NOT NULL DEFAULT 0 CHECK(blank_lda_direction_count>=0),
 coverage_status text NOT NULL CHECK(coverage_status IN (
  'FAA_IDENTIFIER_MATCHED','FAA_ICAO_ALIAS_CONFIRMED','IDENTIFIER_ALIAS_REVIEW',
  'MULTIPLE_SOURCE_SITE_NUMBERS','FAA_SOURCE_NO_RUNWAY_END_ROWS'
 )),
 source_url text NOT NULL,
 notes text NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(cycle_date,airport_key),
 CONSTRAINT airport_faa_nasr_coverage_counts CHECK(
  retrieved_direction_count=published_lda_direction_count+blank_lda_direction_count
 )
);
ALTER TABLE airlinerra.airport_faa_nasr_backfill_cycles ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.airport_faa_nasr_backfill_runway_ends ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.airport_faa_nasr_backfill_airport_coverage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra.airport_faa_nasr_backfill_cycles FROM anon,authenticated;
REVOKE ALL ON TABLE airlinerra.airport_faa_nasr_backfill_runway_ends FROM anon,authenticated;
REVOKE ALL ON TABLE airlinerra.airport_faa_nasr_backfill_airport_coverage FROM anon,authenticated;
INSERT INTO airlinerra.airport_faa_nasr_backfill_cycles (
 cycle_date,source_dataset,source_registry_url,original_faa_archive_url,
 delivery_authority,original_archive_sha256,original_archive_verified,notes
) VALUES (
 '2026-10-01',
 'FAA NASR APT_RWY_END via USDOT BTS NTAD unmodified republication',
 'https://services.arcgis.com/xOi1kZaI0eWDREZv/arcgis/rest/services/Runway_Ends_Table/FeatureServer/1',
 'https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_2026-10-01.zip',
 'USDOT_BTS_NTAD_GOVERNMENT_REPUBLICATION',NULL,false,
 'Direct FAA-derived government republication, row EFF_DATE 2026/10/01. Preserve NULL LNDG_DIST_AVBL as unknown. Original FAA ZIP not independently hash-authenticated. No game admission.'
) ON CONFLICT(cycle_date) DO NOTHING;
-- For a restored archive, load all eight GitHub CSV parts through an
-- administrator-only controlled import, validate alias PAAQ->PAQ and
-- cross-check 781 rows, 211 airport coverage, and 91 non-null LDA entries.
-- Keep the existing Phase 5 airport gate statuses and world activation intact.
