-- Positive/negative proof on isolated PostgreSQL 17.
-- The migration must NEVER overwrite the input source rules, relax a
-- documented ban, approve commercial flights, or expose research evidence
-- as a noise certificate. Real Section 5 simplified hard bans remain intact.
\set ON_ERROR_STOP on
DO $verify$
DECLARE
 h text; actual text; m jsonb; original text; state text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'AIRPORT_RULE_ALIGNMENT_NOT_DISPOSABLE';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_unified_operations_v1)<>8
 OR (SELECT count(*) FROM airlinerra_game.section9_airport_game_restriction_alignment_v1)<>8
 OR (SELECT count(*) FROM (
   SELECT world_id,airport_key FROM airlinerra_game.airport_unified_operations_v1
   GROUP BY world_id,airport_key HAVING count(*)<>1) d)<>0
 THEN RAISE EXCEPTION 'View lost, duplicated or replaced airport rows';END IF;
 SELECT digest INTO h FROM airlinerra_game.fixture_airport_source_hashes
 WHERE source='catalog';
 SELECT md5(string_agg(to_jsonb(t)::text,'|' ORDER BY airport_key))
 INTO actual FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 t;
 IF h IS DISTINCT FROM actual THEN RAISE EXCEPTION 'Catalog source was modified';END IF;
 SELECT digest INTO h FROM airlinerra_game.fixture_airport_source_hashes
 WHERE source='simplified';
 SELECT md5(string_agg(to_jsonb(t)::text,'|' ORDER BY airport_key))
 INTO actual FROM airlinerra_game.section5_airport_simplified_game_rules_v1 t;
 IF h IS DISTINCT FROM actual THEN RAISE EXCEPTION 'Simplified source was modified';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_airport_game_restriction_alignment_v1
     WHERE nighttime_rule_conflict)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_airport_game_restriction_alignment_v1
     WHERE noise_rule_conflict)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_airport_game_restriction_alignment_v1
     WHERE simplified_rule_missing)<>1
 THEN RAISE EXCEPTION 'Source disagreements were not faithfully recorded';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1
    WHERE airport_key='MUC' AND game_nighttime_ban AND game_noise_restrictions
      AND operationally_authorized AND dispatch_eligible_by_airport_admission)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_airport_game_restriction_alignment_v1
    WHERE airport_key='MUC' AND NOT catalog_noise_restrictions
      AND simplified_noise_restrictions AND noise_rule_conflict
      AND conservative_game_noise_restrictions
      AND restriction_alignment_status='CATALOG_AND_SIMPLIFIED_RULES_DISAGREE_REVIEW_REQUIRED'
      AND NOT real_world_certification_granted AND NOT flight_clearance_granted)
 THEN RAISE EXCEPTION 'Munich false-negative noise restriction was not disclosed safely';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1
    WHERE airport_key='BEG' AND (game_nighttime_ban OR game_noise_restrictions))
 THEN RAISE EXCEPTION 'Belgrade clear game-restriction flags were altered';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1
    WHERE airport_key='MISSING_NIGHT' AND game_nighttime_ban
    AND NOT game_noise_restrictions)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1
    WHERE airport_key='MISSING_NOISE' AND game_noise_restrictions
    AND NOT game_nighttime_ban)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1
    WHERE airport_key='CATALOG_NIGHT' AND game_nighttime_ban
    AND NOT game_noise_restrictions)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_airport_game_restriction_alignment_v1
    WHERE airport_key='CATALOG_NIGHT' AND nighttime_rule_conflict
    AND restriction_alignment_status='CATALOG_AND_SIMPLIFIED_RULES_DISAGREE_REVIEW_REQUIRED')
 THEN RAISE EXCEPTION 'Conservative night/noise flags incorrectly weakened';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_airport_game_restriction_alignment_v1
    WHERE airport_key='NO_SIMPLIFIED' AND simplified_rule_missing
      AND conservative_game_nighttime_ban AND conservative_game_noise_restrictions
      AND NOT flight_clearance_granted)
 THEN RAISE EXCEPTION 'Missing source row was incorrectly treated as clearance';END IF;
 -- The original Group2 release policy and documented ban remain untouched.
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1
    WHERE airport_key='GROUP2_READY' AND source_group='GROUP_2'
      AND admitted_to_world AND operationally_authorized AND dispatch_eligible_by_airport_admission
      AND admission_status='GAME_SIMULATION_ADMITTED_REAL_WORLD_EVIDENCE_UNVERIFIED')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1
    WHERE airport_key='GROUP2_PROHIBITED' AND source_group='GROUP_2'
      AND NOT admitted_to_world AND NOT dispatch_eligible_by_airport_admission
      AND admission_status='DOCUMENTED_PROHIBITION')
 THEN RAISE EXCEPTION 'Group2 admission/prohibition logic changed';END IF;
 IF NOT EXISTS(
    SELECT 1 FROM pg_class v JOIN pg_namespace n ON n.oid=v.relnamespace
    WHERE n.nspname='airlinerra_game'
      AND v.relname='section9_airport_game_restriction_alignment_v1'
      AND v.reloptions @> ARRAY['security_invoker=true'])
 OR NOT EXISTS(
    SELECT 1 FROM pg_class v JOIN pg_namespace n ON n.oid=v.relnamespace
    WHERE n.nspname='airlinerra_game'
      AND v.relname='airport_unified_operations_v1'
      AND v.reloptions @> ARRAY['security_invoker=true'])
 OR has_table_privilege('anon','airlinerra_game.section9_airport_game_restriction_alignment_v1','SELECT')
 OR has_table_privilege('authenticated','airlinerra_game.section9_airport_game_restriction_alignment_v1','SELECT')
 OR has_table_privilege('service_role','airlinerra_game.section9_airport_game_restriction_alignment_v1','SELECT')
 THEN RAISE EXCEPTION 'Invoker RLS or audit-view private grants regressed';END IF;

 -- Actual PRODUCTION Section5 screen, unchanged: same aircraft and MUC.
 m:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'MUC',16,'arrival','2026-11-28T12:00:00Z'::timestamptz);
 IF m->>'noiseCertificateNeedsReview'<>'true'
 OR m->>'gameHardBlocked'<>'false' OR m->>'needsReview'<>'true'
 THEN RAISE EXCEPTION 'Missing exact A319 noise certificate was silently approved: %',m;END IF;
 m:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'MUC',16,'arrival','2026-11-28T02:00:00Z'::timestamptz);
 IF m->>'blockedBySimplifiedNighttimeBan'<>'true' OR m->>'gameHardBlocked'<>'true'
 THEN RAISE EXCEPTION 'MUC game nighttime curfew no longer blocks flights: %',m;END IF;
 -- Synthetic *certified* Chapter 2 (disallowed) must block MUC by noise.
 UPDATE airlinerra_game.section5_icao_aircraft_certification_v2
 SET official_icao_chapter=2,noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED'
 WHERE configuration_id=16;
 m:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'MUC',16,'arrival','2026-11-28T12:00:00Z'::timestamptz);
 IF m->>'blockedBySimplifiedNoiseChapter'<>'true' OR m->>'gameHardBlocked'<>'true'
 THEN RAISE EXCEPTION 'Ineligible certified noise chapter was not blocked: %',m;END IF;
 -- Synthetic *certified* Chapter 4 during daytime can clear only the simplified screen.
 UPDATE airlinerra_game.section5_icao_aircraft_certification_v2
 SET official_icao_chapter=4 WHERE configuration_id=16;
 m:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'MUC',16,'arrival','2026-11-28T12:00:00Z'::timestamptz);
 IF m->>'blockedBySimplifiedNoiseChapter'<>'false'
 OR m->>'blockedBySimplifiedNighttimeBan'<>'false' OR m->>'needsReview'<>'false'
 THEN RAISE EXCEPTION 'Valid synthetic daytime Chapter 4 did not clear simplified game gate: %',m;END IF;
 IF (SELECT official_icao_chapter FROM airlinerra_game.section5_icao_aircraft_certification_v2
     WHERE configuration_id=16)<>4
 THEN RAISE EXCEPTION 'Synthetic chapter wrong'; END IF;
 RAISE NOTICE 'PASS: 8 source intact airports, MUC visibility, 2+2 disagreements, missing row, Group2 admission, invoker/private grants, actual Section5 curfew+noise+unknown-cert guards. No game authorization.';
END $verify$;
