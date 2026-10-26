-- Executed PASS against private Supabase on 2026-10-26.
-- Ten German source cases, two operator runway-only advances, eight holds.
DO $audit$
DECLARE expected text[]:=ARRAY['EDAK','EDBN','EDCP','EDFE','EDLD','EDMO','EDTD','EDTF','EDXF','ETHM'];
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_runway_resolution_cases
  WHERE batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26')<>10
 THEN RAISE EXCEPTION 'Expected 10 reconciled source case entries'; END IF;
 IF EXISTS(SELECT code FROM unnest(expected) AS code
  EXCEPT SELECT airport_code FROM airlinerra.airport_expansion_de_runway_resolution_cases
  WHERE batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26')
 THEN RAISE EXCEPTION 'Expected named source case not present'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_independent_paved_runway_reviews
 WHERE batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26')<>2
 OR (SELECT count(*) FROM airlinerra.airport_expansion_german_civil_runway_end_holds
 WHERE batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26')<>2
 THEN RAISE EXCEPTION 'Expected two paved source elevations and two distinct LDA exceptions';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_runway_resolution_cases rs
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE rs.batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26'
 AND rs.airport_code IN('EDFE','EDTD')
 AND rs.game_admission_status='NOT_APPROVED'
 AND a.review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.paved_runway_status='VERIFIED' AND a.identity_status='VERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>2 THEN
 RAISE EXCEPTION 'EDFE and EDTD must advance physical runway only';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_runway_resolution_cases rs
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE rs.batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26'
 AND rs.airport_code NOT IN('EDFE','EDTD')
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.paved_runway_status='UNVERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>8
 THEN RAISE EXCEPTION 'Remaining eight source cases must remain on original source verification hold';END IF;
 IF NOT EXISTS(
 SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews x
 JOIN airlinerra.airport_expansion_german_civil_runway_end_holds h
 ON h.airport_key=x.airport_key AND h.batch_key=x.batch_key
 WHERE x.batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26'
 AND x.icao_code='EDFE'
 AND x.documented_physical_length_m=1400 AND x.documented_width_m=25
 AND x.normalized_surface='ASPHALT'
 AND x.published_landing_direction_a_m=1400
 AND x.published_landing_direction_b_m=1166
 AND h.source_landing_end_b_m=1166 AND h.game_admission_status='NOT_APPROVED'
 ) THEN RAISE EXCEPTION 'Egelsbach operator-confirmed RW26 LDA 1166 must stay held'; END IF;
 IF NOT EXISTS(
 SELECT 1 FROM airlinerra.airport_expansion_independent_paved_runway_reviews x
 JOIN airlinerra.airport_expansion_german_civil_runway_end_holds h
 ON h.airport_key=x.airport_key AND h.batch_key=x.batch_key
 WHERE x.batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26'
 AND x.icao_code='EDTD'
 AND x.documented_physical_length_m=1200
 AND x.published_landing_direction_a_m=1290
 AND h.source_landing_end_a_m=1290
 AND h.source_physical_length_m=1200
 ) THEN RAISE EXCEPTION 'Donaueschingen 1200 gross and contradictory 1290 LDA must remain separate'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_runway_resolution_cases
 WHERE batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED' OR world_activation_allowed))
 THEN RAISE EXCEPTION 'Research airport was wrongly granted gameplay authority'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>1791
 OR (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 JOIN airlinerra.airport_registry r USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND r.country_iso='DE'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>8
 THEN RAISE EXCEPTION 'German/global generic source holds must be 8/1791'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation
 WHERE world_number=1 AND active)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation a
 JOIN airlinerra.airport_cohorts c USING(airport_key) WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'Protected original World 1 airport release changed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='airlinerra' AND c.relname='airport_expansion_de_runway_resolution_cases'
 AND c.relrowsecurity AND NOT has_table_privilege('anon',c.oid,'SELECT')
 AND NOT has_table_privilege('authenticated',c.oid,'SELECT'))
 THEN RAISE EXCEPTION 'Resolution case table privacy missing';END IF;
END $audit$;
SELECT 'PASS' AS germany_batch07_acceptance;
