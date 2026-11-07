-- Section 5 simplified Yes/No GAME fields acceptance test.
-- This must never claim the 3,111 not-checked defaults were verified on AirlineSim.
DO $audit$
DECLARE
 n integer; pages integer; screenshots integer; defaults integer;
 official_research integer; timed_rules integer; game_source_count integer;
BEGIN
 SELECT total_airports,airline_sim_pages_checked,screenshots_checked,game_defaults_not_source_checked
 INTO n,pages,screenshots,defaults
 FROM airlinerra_game.section5_airport_simplified_game_progress_v1;
 IF n<>3141 OR pages<>28 OR screenshots<>2 OR defaults<>3111
 THEN RAISE EXCEPTION 'Simplified Source counts mismatch % %, %, %',n,pages,screenshots,defaults; END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
   WHERE s.world_id=1 AND (s.nighttime_ban IS NULL OR s.noise_restrictions IS NULL
   OR (NOT s.noise_restrictions AND cardinality(s.permitted_noise_chapters)>0)))
 THEN RAISE EXCEPTION 'Missing or inconsistent binary game setting'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_game_restriction_catalog_v1 WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'Existing authoritative restriction catalog changed'; END IF;
 SELECT count(*) INTO official_research
 FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING';
 IF official_research<>1246 THEN RAISE EXCEPTION 'Official source research queue was altered'; END IF;
 SELECT count(*) INTO timed_rules FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1;
 IF timed_rules<>91 THEN RAISE EXCEPTION 'Existing source-based hard/review time restrictions changed'; END IF;
 SELECT count(*) INTO game_source_count
 FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
 JOIN airlinerra_game.airport_reference_profiles p USING(world_id,airport_key)
 WHERE s.world_id=1 AND
   (p.game_display_code='BUD' AND s.nighttime_ban AND s.permitted_noise_chapters=ARRAY[3,4]::smallint[]
     OR p.game_display_code='ARN' AND NOT s.nighttime_ban AND s.permitted_noise_chapters=ARRAY[3,4]::smallint[]
     OR p.game_display_code='BCN' AND NOT s.nighttime_ban AND s.permitted_noise_chapters=ARRAY[3,4]::smallint[]
     OR p.game_display_code='KRN' AND s.nighttime_ban
     OR p.game_display_code='SCR' AND NOT s.nighttime_ban AND NOT s.noise_restrictions);
 IF game_source_count<>5 THEN RAISE EXCEPTION 'Sample checked night/noise mapping incorrect'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
 WHERE source_status='GAME_DEFAULT_NOT_CHECKED' AND source_url IS NOT NULL)
 THEN RAISE EXCEPTION 'Unverified default has fake source'; END IF;
 RAISE NOTICE 'PASS 3141 binary game airport flags; 30 checked sources; 3111 explicitly unverified defaults; 1246 historical normalization cases and 91 source-backed time rules preserved.';
END $audit$;