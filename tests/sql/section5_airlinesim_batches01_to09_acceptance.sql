-- Airlinerra Section5 AirlineSim Batches 1-9 acceptance (READ-ONLY).
-- 450 batch decisions: 431 individually observed pages and 19 explicit not-found game defaults.
-- This simplified game data does NOT certify real aviation operating permissions.
DO $checks$
DECLARE
 all_count integer;
 source_checked integer;
 not_found integer;
 still_pending integer;
 global_airports integer;
 global_checked integer;
 global_screenshots integer;
 global_defaults integer;
 global_not_found integer;
 ban_count integer;
 noise_count integer;
BEGIN
 SELECT count(*),
   count(*) FILTER (WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
   count(*) FILTER (WHERE review_status='AIRLINESIM_NOT_FOUND'),
   count(*) FILTER (WHERE review_status='PENDING')
 INTO all_count,source_checked,not_found,still_pending
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1;
 IF all_count<>1216 OR source_checked<>431 OR not_found<>19 OR still_pending<>766 THEN
  RAISE EXCEPTION 'Batch 1-9 queue mismatch %, %, %, %',all_count,source_checked,not_found,still_pending; END IF;

 IF EXISTS (SELECT 1 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1
 AND batch_no<=9 AND review_status='PENDING')
 THEN RAISE EXCEPTION 'Incomplete airport in batches 1-9'; END IF;

 SELECT count(*) FILTER (WHERE s.nighttime_ban),count(*) FILTER (WHERE s.noise_restrictions)
 INTO ban_count,noise_count
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
 WHERE q.world_id=1 AND q.batch_no=9;
 IF ban_count<>10 OR noise_count<>22 THEN
  RAISE EXCEPTION 'Batch9 night/noise values mismatch % %',ban_count,noise_count; END IF;

 IF EXISTS (SELECT 1 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
 WHERE q.world_id=1 AND (
 (q.review_status='AIRLINESIM_PAGE_OBSERVED' AND (s.source_status<>'AIRLINESIM_PAGE_OBSERVED' OR s.source_url IS NULL))
 OR (q.review_status='AIRLINESIM_NOT_FOUND' AND
   (s.source_status<>'AIRLINESIM_NOT_FOUND' OR s.nighttime_ban OR s.noise_restrictions))
 OR (q.review_status='PENDING' AND s.source_status<>'GAME_DEFAULT_NOT_CHECKED')
 OR (s.noise_restrictions AND s.permitted_noise_chapters<>ARRAY[3,4]::smallint[])
 OR (NOT s.noise_restrictions AND cardinality(s.permitted_noise_chapters)<>0)
 )) THEN RAISE EXCEPTION 'Provenance or noise Chapter inconsistency'; END IF;

 SELECT total_airports,airline_sim_pages_checked,screenshots_checked,
 game_defaults_not_source_checked,airline_sim_not_found
 INTO global_airports,global_checked,global_screenshots,global_defaults,global_not_found
 FROM airlinerra_game.section5_airport_simplified_game_progress_v1;
 IF global_airports<>3141 OR global_checked<>459 OR global_screenshots<>2
 OR global_defaults<>2661 OR global_not_found<>19 THEN
  RAISE EXCEPTION 'Global game source coverage incorrect'; END IF;

 IF (SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
 THEN RAISE EXCEPTION 'Original source-backed airport curfew rules modified';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Historical detailed research queue altered';END IF;
 IF (SELECT status FROM airlinerra_game.airport_data_master_categories WHERE world_id=1 AND category_number=5)<>'partially_populated'
 THEN RAISE EXCEPTION 'Section5 incorrectly marked complete before remaining research';END IF;
 RAISE NOTICE 'PASS: Batches1-9 = 450 cases processed (431 pages,19 notfound), 766 pending; 91 precise time rules unchanged.';
END $checks$;