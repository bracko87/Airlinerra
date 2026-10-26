-- Airlinerra German Batch 06, 26 October 2026; executed PASS on private Supabase.
-- Research-only status changes; no game airport or commercial-operation approval.
DO $check$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26')<>8
 OR (SELECT count(*) FROM airlinerra.airport_expansion_german_civil_runway_end_holds
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26')<>2
 THEN RAISE EXCEPTION 'Eight research rows and two end-distance case records expected';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26'
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.paved_runway_status='VERIFIED' AND a.game_admission_status='NOT_APPROVED')<>1
 THEN RAISE EXCEPTION 'Exactly one airport (EDWI) should have advanced'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26'
 AND r.icao_code='EDWI' AND r.documented_physical_length_m=1459
 AND r.published_landing_direction_a_m=1233 AND r.published_landing_direction_b_m=1207
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING')
 THEN RAISE EXCEPTION 'JadeWeser main 02/20 runway data incorrect'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.paved_runway_status='UNVERIFIED')<>6
 THEN RAISE EXCEPTION 'Six historic/secondary rechecks must remain held';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_german_civil_runway_end_holds h
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE h.icao_code='EDXJ' AND h.source_physical_length_m=1450
 AND h.source_landing_end_a_m=1140 AND h.source_landing_end_b_m=1140
 AND a.review_status='HOLD_CIVIL_RUNWAY_USABLE_DISTANCE_1140M')
 THEN RAISE EXCEPTION 'Husum civil-access limitation not preserved'; END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_german_civil_runway_end_holds h
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE h.icao_code='EDXF' AND h.source_physical_length_m=1220
 AND h.source_landing_end_a_m=1220 AND h.source_landing_end_b_m=1040
 AND h.current_source_check='HISTORICAL_OPERATOR_HOSTED_AIRFIELD_CHART'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')
 THEN RAISE EXCEPTION 'Flensburg 2019 RW29 short landing source downgraded';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>1793
 THEN RAISE EXCEPTION 'Worldwide generic hold count not 1793';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>10
 THEN RAISE EXCEPTION 'German generic hold count not 10';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation
 WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w
 JOIN airlinerra.airport_cohorts c USING(airport_key) WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'First authorized World 1 catalog changed'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED' OR simulation_world_active))
 OR EXISTS(SELECT 1 FROM airlinerra.airport_expansion_german_civil_runway_end_holds
 WHERE batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED' OR game_world_activated))
 THEN RAISE EXCEPTION 'Research-only airport improperly approved';END IF;
END $check$;
SELECT 'PASS' AS germany_batch06_acceptance;
