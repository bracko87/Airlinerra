-- Airlinerra Phase 5 — classify FAA runway-end records omitted by the
-- geospatial PHYSICAL RUNWAYS view because they are NOT normal paved runways.
-- Applied 2026-10-26 to private Supabase research schema airlinerra.
-- FAA AC 150/5200-35: H1/H2 helipad, xxW water landing area, xxU ultralight.
-- SOURCE CYCLE: 2026-10-01, US DOT BTS NASR unchanged republication.
-- No physical landing distance or aviation operating entitlement invented.

CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_nonstandard_facility_ends (
 cycle_date date NOT NULL REFERENCES airlinerra.airport_faa_nasr_backfill_cycles(cycle_date),
 airport_key text NOT NULL,
 faa_identifier text NOT NULL,
 runway_pair text NOT NULL,
 runway_end text NOT NULL,
 source_objectid integer NOT NULL,
 facility_type text NOT NULL CHECK(facility_type IN ('HELIPAD','WATER_LANDING_AREA','ULTRALIGHT_RUNWAY')),
 source_identity_basis text NOT NULL,
 fixed_wing_runway_eligible boolean NOT NULL DEFAULT false CHECK(fixed_wing_runway_eligible=false),
 screening_status text NOT NULL DEFAULT 'EXCLUDED_SPECIAL_PURPOSE_FACILITY' CHECK(screening_status='EXCLUDED_SPECIAL_PURPOSE_FACILITY'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 source_url text NOT NULL,
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(cycle_date,airport_key,runway_pair,runway_end),
 CONSTRAINT nonstandard_suffix_consistent CHECK (
 (facility_type='HELIPAD' AND runway_pair ~ '^H[0-9]+$' AND runway_end=runway_pair) OR
 (facility_type='WATER_LANDING_AREA' AND runway_pair ~ '^[0-9]+W/[0-9]+W$' AND runway_end ~ '^[0-9]+W$') OR
 (facility_type='ULTRALIGHT_RUNWAY' AND runway_pair ~ '^[0-9]+U/[0-9]+U$' AND runway_end ~ '^[0-9]+U$')
 )
);
ALTER TABLE airlinerra.airport_faa_nonstandard_facility_ends ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_faa_nonstandard_facility_ends FROM anon,authenticated;

WITH chosen AS (
 SELECT e.cycle_date,e.airport_key,e.faa_identifier,e.runway_pair,e.runway_end,e.source_objectid,e.source_url,
 CASE
 WHEN e.runway_pair ~ '^H[0-9]+$' AND e.runway_end=e.runway_pair THEN 'HELIPAD'
 WHEN e.runway_pair ~ '^[0-9]+W/[0-9]+W$' AND e.runway_end ~ '^[0-9]+W$' THEN 'WATER_LANDING_AREA'
 WHEN e.runway_pair ~ '^[0-9]+U/[0-9]+U$' AND e.runway_end ~ '^[0-9]+U$' THEN 'ULTRALIGHT_RUNWAY'
 ELSE NULL END AS kind
 FROM airlinerra.airport_faa_nasr_backfill_runway_ends e
 JOIN airlinerra.airport_faa_aim_direction_screen s
 USING (cycle_date,airport_key,runway_pair,runway_end)
 WHERE e.cycle_date='2026-10-01'
 AND s.distance_screen_status='PHYSICAL_RUNWAY_NOT_IN_GOVERNMENT_LAYER'
)
INSERT INTO airlinerra.airport_faa_nonstandard_facility_ends
(cycle_date,airport_key,faa_identifier,runway_pair,runway_end,source_objectid,
facility_type,source_identity_basis,source_url)
SELECT cycle_date,airport_key,faa_identifier,runway_pair,runway_end,source_objectid,
kind,'FAA airport-data ID: Hx=helipad, W=water, U=ultralight; independently matched Oct 2026 record',source_url
FROM chosen WHERE kind IS NOT NULL
ON CONFLICT(cycle_date,airport_key,runway_pair,runway_end) DO NOTHING;

-- Preserve the former view exactly. This new view adds a type-aware exclusion
-- to avoid erroneously treating a helipad/water runway as a missing paved runway.
CREATE OR REPLACE VIEW airlinerra.airport_faa_aim_direction_adjudicated
WITH (security_invoker=true) AS
SELECT s.*,n.facility_type AS nonstandard_facility_type,
 CASE WHEN n.facility_type IS NOT NULL THEN 'EXCLUDED_SPECIAL_PURPOSE_FACILITY'
 ELSE s.distance_screen_status END AS adjudicated_distance_screen_status
FROM airlinerra.airport_faa_aim_direction_screen s
LEFT JOIN airlinerra.airport_faa_nonstandard_facility_ends n
 ON n.cycle_date=s.cycle_date AND n.airport_key=s.airport_key
 AND n.runway_pair=s.runway_pair AND n.runway_end=s.runway_end;
REVOKE ALL ON airlinerra.airport_faa_aim_direction_adjudicated FROM anon,authenticated;
-- Expect 15 HELIPAD, 4 WATER_LANDING_AREA, 4 ULTRALIGHT_RUNWAY; 23 total.
SELECT facility_type,count(*) FROM airlinerra.airport_faa_nonstandard_facility_ends GROUP BY 1 ORDER BY 1;
