-- Read-only post-commit acceptance for World1 Section5 AirlineSim batches 1–8.
-- The game summary is NOT independent proof of actual airport operating permission.
DO $checks$
DECLARE total integer; page_count integer; notfound integer; pending integer;
        all_airports integer; global_pages integer; screenshots integer;
        defaults integer; global_notfound integer;
BEGIN
SELECT count(*),
count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),
count(*) FILTER(WHERE review_status='PENDING')
INTO total,page_count,notfound,pending
FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1;
IF total<>1216 OR page_count<>382 OR notfound<>18 OR pending<>816
THEN RAISE EXCEPTION 'Batches1–8 not at expected status: total %, page checks %, notfound %, pending %',total,page_count,notfound,pending; END IF;

IF (SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no<=8 AND review_status='PENDING')<>0
THEN RAISE EXCEPTION 'Unfinished airport in completed batches'; END IF;
IF EXISTS(SELECT 1 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
WHERE q.world_id=1 AND (
  (q.review_status='AIRLINESIM_PAGE_OBSERVED' AND (s.source_status<>'AIRLINESIM_PAGE_OBSERVED' OR s.source_url IS NULL))
 OR(q.review_status='AIRLINESIM_NOT_FOUND' AND (s.source_status<>'AIRLINESIM_NOT_FOUND' OR s.nighttime_ban OR s.noise_restrictions))
 OR(q.review_status='PENDING' AND s.source_status<>'GAME_DEFAULT_NOT_CHECKED')
 OR (s.noise_restrictions AND s.permitted_noise_chapters<>ARRAY[3,4]::smallint[])
 OR (NOT s.noise_restrictions AND cardinality(s.permitted_noise_chapters)<>0)
)) THEN RAISE EXCEPTION 'Binary game rules, Chapters or source metadata inconsistent'; END IF;

SELECT total_airports,airline_sim_pages_checked,screenshots_checked,
 game_defaults_not_source_checked,airline_sim_not_found
INTO all_airports,global_pages,screenshots,defaults,global_notfound
FROM airlinerra_game.section5_airport_simplified_game_progress_v1;
IF all_airports<>3141 OR global_pages<>410 OR screenshots<>2 OR defaults<>2711 OR global_notfound<>18
THEN RAISE EXCEPTION 'Global game source status inconsistent'; END IF;
IF (SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
THEN RAISE EXCEPTION 'Original precise time restrictions lost'; END IF;
IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
THEN RAISE EXCEPTION 'Detailed operating research altered'; END IF;
IF(SELECT status FROM airlinerra_game.airport_data_master_categories WHERE world_id=1 AND category_number=5)<>'partially_populated'
THEN RAISE EXCEPTION 'Section5 mistakenly closed'; END IF;
RAISE NOTICE 'PASS: batches1–8 processed400; AirlineSim pages382; notfound18; 816 remain. All3141 game defaults present. Official rules preserved.';
END $checks$;