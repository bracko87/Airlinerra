-- Executed PASS in private Supabase for German expansion Batch08 on 2026-10-26.
DO $assert$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_multisource_adjudications
 WHERE batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26')<>8
 THEN RAISE EXCEPTION 'German Batch08 requires eight independently reviewed cases';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_multisource_adjudications r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26'
 AND r.runways_only_screen_boolean=true
 AND r.resolution='MULTISOURCE_PAVED_RUNWAY_SCREEN_PASSES_RELEASE_HOLD'
 AND a.review_status='INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.identity_status='VERIFIED' AND a.paved_runway_status='VERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>2
 THEN RAISE EXCEPTION 'Expected exactly two advanced paved-runway research cases';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_multisource_adjudications r
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE r.batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26'
 AND r.runways_only_screen_boolean IS NULL
 AND r.resolution='CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.paved_runway_status='UNVERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>6
 THEN RAISE EXCEPTION 'Expected six source verification holds, without premature clearance';END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_expansion_de_multisource_adjudications
 WHERE batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26'
 AND airport_code='EDLD' AND paved_length_m=1500 AND paved_width_m=30
 AND runway_surface='ASPHALT' AND runways_only_screen_boolean=true)
 OR NOT EXISTS (SELECT 1 FROM airlinerra.airport_expansion_de_multisource_adjudications
 WHERE batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26'
 AND airport_code='ETHM' AND paved_length_m=1615 AND paved_width_m=35
 AND runway_surface='ASPHALT' AND runways_only_screen_boolean=true)
 THEN RAISE EXCEPTION 'EDLD/ETHM paved source facts missing';END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra.airport_expansion_de_multisource_adjudications
 WHERE batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26'
 AND airport_code='EDXF' AND paved_length_m=1220
 AND runways_only_screen_boolean IS NULL)
 OR NOT EXISTS (SELECT 1 FROM airlinerra.airport_expansion_de_multisource_adjudications
 WHERE batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26'
 AND airport_code='EDTF' AND paved_length_m IS NULL
 AND runways_only_screen_boolean IS NULL)
 THEN RAISE EXCEPTION 'Historically sourced near-min runway measurements mistakenly cleared';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906' AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>1789
 THEN RAISE EXCEPTION 'Global generic verification backlog must be 1789';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_multisource_adjudications
 WHERE batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26'
 AND (game_admission_status<>'NOT_APPROVED'
 OR game_activation_allowed OR commercial_permission_verified))
 THEN RAISE EXCEPTION 'Research result falsely claims game/airline approval';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation
 WHERE world_number=1 AND active)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS (SELECT 1 FROM airlinerra.airport_world_activation
 WHERE world_number<>1)
 OR EXISTS (SELECT 1 FROM airlinerra.airport_world_activation a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'Owner-approved original 3140 game world was modified';END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='airlinerra' AND c.relname='airport_expansion_de_multisource_adjudications'
 AND c.relrowsecurity
 AND NOT has_table_privilege('anon',c.oid,'SELECT')
 AND NOT has_table_privilege('authenticated',c.oid,'SELECT'))
 THEN RAISE EXCEPTION 'German runway research table missing private RLS';END IF;
END $assert$;
SELECT 'PASS' AS germany_batch08_acceptance;
