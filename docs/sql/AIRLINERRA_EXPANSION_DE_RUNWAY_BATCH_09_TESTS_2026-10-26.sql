-- Verified PASS in private Supabase on 2026-10-26.
DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_batch09_airport_evidence
  WHERE batch_key='EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26')<>6
 THEN RAISE EXCEPTION 'Batch09 requires six original German airport evidence rows';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_batch09_airport_evidence e
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE e.batch_key='EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26'
 AND e.airport_code IN('EDBN','EDMO')
 AND e.runway_screen_decision='MULTISOURCE_PAVED_PHYSICAL_RUNWAY_CONFIRMED'
 AND a.review_status='INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING'
 AND a.identity_status='VERIFIED' AND a.paved_runway_status='VERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>2
 THEN RAISE EXCEPTION 'Neubrandenburg and Oberpfaffenhofen research advances not exactly two';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_temp_airfield_closure_watch h
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE h.airport_key='OURAIRPORTS:2207' AND h.notam_reference='E4380/26'
 AND h.reported_start_utc='2026-10-26 07:00:00'
 AND h.reported_end_utc='2026-10-31 17:00:00'
 AND h.followup_utc_date='2026-11-01'
 AND h.aerodrome_closed_during_windows
 AND h.airspace_restriction_to='2028-12-31'
 AND a.review_status='HOLD_TEMPORARY_EDCP_AERODROME_CLOSURE_NOTAM_E4380_26'
 AND a.paved_runway_status='UNVERIFIED'
 AND a.game_admission_status='NOT_APPROVED')
 THEN RAISE EXCEPTION 'Peenemunde temporary aerodrome closure or separate restricted airspace incorrectly handled';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_expansion_de_batch09_airport_evidence e
 JOIN airlinerra.airport_access_reviews a USING(airport_key)
 WHERE e.batch_key='EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26'
 AND e.airport_code IN('EDAK','EDTF','EDXF')
 AND e.runway_screen_decision='PHYSICAL_RUNWAY_NEEDS_CURRENT_SOURCE'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.paved_runway_status='UNVERIFIED'
 AND a.game_admission_status='NOT_APPROVED')<>3
 THEN RAISE EXCEPTION '3 near-threshold/unverified physical runway airports must stay held';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_batch09_airport_evidence
 WHERE game_admission_status<>'NOT_APPROVED' OR world_activation_allowed)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_expansion_de_temp_airfield_closure_watch
 WHERE game_admission_status<>'NOT_APPROVED' OR world_activation_allowed)
 THEN RAISE EXCEPTION 'Source-only study was wrongly game-approved';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_access_reviews a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906'
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION')<>1786
 THEN RAISE EXCEPTION 'Expansion generic verification backlog must now be 1786';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation
 WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation
 WHERE world_number<>1)
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation a
 JOIN airlinerra.airport_cohorts c USING(airport_key)
 WHERE c.cohort='EXPANSION_3906')
 THEN RAISE EXCEPTION 'First 3140 owner-authorized game airports changed';END IF;
 IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='airlinerra'
 AND c.relname IN('airport_expansion_de_batch09_airport_evidence','airport_expansion_de_temp_airfield_closure_watch')
 AND c.relrowsecurity AND NOT has_table_privilege('anon',c.oid,'SELECT')
 AND NOT has_table_privilege('authenticated',c.oid,'SELECT'))<>2
 THEN RAISE EXCEPTION 'Research tables are not isolated from public API';END IF;
END $verify$;
SELECT 'PASS' AS german_batch09_source_acceptance;
