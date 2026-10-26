-- Airlinerra Phase 5 — first documented airport-level evidence decision,
-- based solely on October 2026 FAA government-republished runway data.
-- Prerequisite: special-purpose facility migration and FAA AIM direction screen.
-- Game remains NOT APPROVED for all 211 airports.
CREATE TABLE IF NOT EXISTS airlinerra.airport_faa_initial_distance_decisions (
 cycle_date date NOT NULL REFERENCES airlinerra.airport_faa_nasr_backfill_cycles(cycle_date),
 airport_key text NOT NULL,
 faa_identifier text NOT NULL,
 direction_total integer NOT NULL,
 distance_pass_direction_count integer NOT NULL,
 published_distance_pass_count integer NOT NULL,
 aim_assumption_pass_count integer NOT NULL,
 partial_declared_hold_count integer NOT NULL,
 excluded_special_purpose_direction_count integer NOT NULL,
 prohibited_landing_direction_count integer NOT NULL,
 pavement_condition_hold_count integer NOT NULL,
 evidence_decision text NOT NULL CHECK(evidence_decision IN (
 'DISTANCE_SCREEN_CANDIDATE_ONLY','PARTIAL_DECLARED_DISTANCE_MANUAL_REVIEW','NO_DISTANCE_SCREEN_PASS')),
 distance_adjudication_note text NOT NULL,
 original_faa_zip_sha256_verified boolean NOT NULL DEFAULT false CHECK(original_faa_zip_sha256_verified=false),
 owner_paid_use_verified boolean NOT NULL DEFAULT false CHECK(owner_paid_use_verified=false),
 aircraft_performance_verified boolean NOT NULL DEFAULT false CHECK(aircraft_performance_verified=false),
 certified_operator_verified boolean NOT NULL DEFAULT false CHECK(certified_operator_verified=false),
 flight_date_safety_verified boolean NOT NULL DEFAULT false CHECK(flight_date_safety_verified=false),
 handling_rescue_verified boolean NOT NULL DEFAULT false CHECK(handling_rescue_verified=false),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 evidence_snapshot_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(cycle_date,airport_key),
 CONSTRAINT initial_distance_decision_counts CHECK (
 direction_total>=distance_pass_direction_count AND
 distance_pass_direction_count=published_distance_pass_count+aim_assumption_pass_count AND
 direction_total>=excluded_special_purpose_direction_count AND
 direction_total>=partial_declared_hold_count AND
 direction_total>=prohibited_landing_direction_count AND
 direction_total>=pavement_condition_hold_count),
 CONSTRAINT initial_distance_decision_logic CHECK (
 (evidence_decision='DISTANCE_SCREEN_CANDIDATE_ONLY' AND distance_pass_direction_count>0)
 OR (evidence_decision='PARTIAL_DECLARED_DISTANCE_MANUAL_REVIEW'
 AND distance_pass_direction_count=0 AND partial_declared_hold_count>0)
 OR (evidence_decision='NO_DISTANCE_SCREEN_PASS' AND distance_pass_direction_count=0))
);
ALTER TABLE airlinerra.airport_faa_initial_distance_decisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_faa_initial_distance_decisions FROM anon,authenticated;

WITH counted AS (
 SELECT cycle_date,airport_key,faa_identifier,COUNT(*) ends,
 COUNT(*) FILTER(WHERE adjudicated_distance_screen_status IN (
 'AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY','PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY')) pass_ends,
 COUNT(*) FILTER(WHERE adjudicated_distance_screen_status='PUBLISHED_LDA_PASSES_DISTANCE_SCREEN_ONLY') published_pass,
 COUNT(*) FILTER(WHERE adjudicated_distance_screen_status='AIM_ASSUMED_DISTANCE_PASSES_SCREEN_ONLY') assumed_pass,
 COUNT(*) FILTER(WHERE adjudicated_distance_screen_status='PARTIAL_DECLARED_DISTANCES_MANUAL_REVIEW') partial_hold,
 COUNT(*) FILTER(WHERE adjudicated_distance_screen_status='EXCLUDED_SPECIAL_PURPOSE_FACILITY') special,
 COUNT(*) FILTER(WHERE adjudicated_distance_screen_status='LANDING_DIRECTION_PROHIBITED') prohibited,
 COUNT(*) FILTER(WHERE adjudicated_distance_screen_status='PAVEMENT_CONDITION_HOLD') surface_hold
 FROM airlinerra.airport_faa_aim_direction_adjudicated
 WHERE cycle_date='2026-10-01' GROUP BY 1,2,3
)
INSERT INTO airlinerra.airport_faa_initial_distance_decisions (
 cycle_date,airport_key,faa_identifier,direction_total,distance_pass_direction_count,
 published_distance_pass_count,aim_assumption_pass_count,partial_declared_hold_count,
 excluded_special_purpose_direction_count,prohibited_landing_direction_count,
 pavement_condition_hold_count,evidence_decision,distance_adjudication_note)
SELECT cycle_date,airport_key,faa_identifier,ends,pass_ends,published_pass,assumed_pass,
partial_hold,special,prohibited,surface_hold,
CASE WHEN pass_ends>0 THEN 'DISTANCE_SCREEN_CANDIDATE_ONLY'
 WHEN partial_hold>0 THEN 'PARTIAL_DECLARED_DISTANCE_MANUAL_REVIEW'
 ELSE 'NO_DISTANCE_SCREEN_PASS' END,
CASE WHEN pass_ends>0 THEN
 'At least one source runway end passes distance screening only. No operational aircraft, owner, carrier, NOTAM, weather or rescue clearance.'
 WHEN partial_hold>0 THEN
 'No screening candidate until the partially declared runway distance is resolved: do not infer LDA from gross pavement.'
 ELSE 'No October 2026 runway end passes initial research distance screen; revalidate before any new decision.' END
FROM counted
ON CONFLICT(cycle_date,airport_key) DO NOTHING;

-- Expected 208 CANDIDATE_ONLY, 1 PARTIAL_DECLARED_MANUAL, 2 NO_PASS;
-- all 211 airport game_admission_status NOT_APPROVED, zero world activated.
SELECT evidence_decision,count(*) airports,sum(distance_pass_direction_count) candidate_ends
FROM airlinerra.airport_faa_initial_distance_decisions GROUP BY 1 ORDER BY 1;
