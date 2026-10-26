-- Airlinerra German airport expansion Batch 02; read-only reconciliation queries.
-- Eight rows saved 2026-10-26; 6 current operator/municipality records
-- advanced to paved-runway evidence verified; EDCP and EDFE on source hold.
-- Note that acceptance was independently checked via readbacks, not one
-- combined stored-procedure assertion.

SELECT icao_code,source_authority_grade,research_status,
documented_physical_length_m,documented_width_m,
published_landing_direction_a_m,published_landing_direction_b_m,
game_admission_status,simulation_world_active
FROM airlinerra.airport_expansion_independent_paved_runway_reviews
WHERE batch_key='EXPANSION_DE_PAVED_BATCH_02_2026_10_26'
ORDER BY icao_code;

SELECT r.icao_code,a.identity_status,a.paved_runway_status,
a.review_status,a.game_admission_status
FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
JOIN airlinerra.airport_access_reviews a USING(airport_key)
WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_02_2026_10_26'
ORDER BY r.icao_code;

SELECT
(SELECT count(*) FROM airlinerra.airport_world_activation
 WHERE world_number=1 AND active) AS foundation_active,
(SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)
 AS original_picker_airports,
(SELECT count(*) FROM airlinerra.airport_world_activation
 WHERE world_number<>1) AS other_world_rows,
(SELECT count(*) FROM airlinerra.airport_world_activation w
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906') AS expansion_active,
(SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION') AS worldwide_source_holds;

-- Expected: 8 records, 6 operator-source advances, 2 source holds,
-- 3,140 foundation active and 3,140 picker records,
-- 0 expansion/world2/3 active, 1,815 worldwide independent holds.
-- EDFB LDA 18/36 = 1230/1300m. EDFE cached LDA 08/26 =
-- 1400/1166m and MUST remain held since 1166m < 1200m.
-- EDGE current city report main concrete 1720x55m, older DULV
-- listing of 1720x30m needs current AIP reconciliation.
