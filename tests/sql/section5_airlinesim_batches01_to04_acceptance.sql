-- Section 5 AirlineSim Batches 1–4 read-only acceptance, World 1.
DO $checks$
DECLARE total integer;done integer;unfound integer;pending integer;pages integer;screens integer;unverified integer;
BEGIN
SELECT count(*),count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),
count(*) FILTER(WHERE review_status='PENDING')
INTO total,done,unfound,pending
FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1;
IF total<>1216 OR done<>190 OR unfound<>10 OR pending<>1016
THEN RAISE EXCEPTION 'Batch progress wrong %/%/%/%',total,done,unfound,pending;END IF;

IF EXISTS(SELECT 1 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
WHERE q.world_id=1 AND (
(q.review_status='PENDING' AND s.source_status<>'GAME_DEFAULT_NOT_CHECKED')
OR (q.review_status='AIRLINESIM_PAGE_OBSERVED' AND (s.source_status<>'AIRLINESIM_PAGE_OBSERVED' OR s.source_url IS NULL))
OR (q.review_status='AIRLINESIM_NOT_FOUND' AND (s.source_status<>'AIRLINESIM_NOT_FOUND'
 OR s.nighttime_ban OR s.noise_restrictions OR s.source_url IS NULL))))
THEN RAISE EXCEPTION 'Batch statuses do not align with source provenance';END IF;

SELECT airline_sim_pages_checked,screenshots_checked,game_defaults_not_source_checked
INTO pages,screens,unverified FROM airlinerra_game.section5_airport_simplified_game_progress_v1;
IF pages<>218 OR screens<>2 OR unverified<>2911 THEN
RAISE EXCEPTION 'Game source summary mismatch %/%/%',pages,screens,unverified;END IF;
IF (SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
THEN RAISE EXCEPTION 'Existing official airport time rules changed';END IF;
IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
THEN RAISE EXCEPTION 'Independent research queue changed';END IF;
IF (SELECT count(*) FROM airlinerra_game.airport_data_master_categories WHERE world_id=1
AND category_number=5 AND status='partially_populated')<>1
THEN RAISE EXCEPTION 'Section 5 master prematurely closed';END IF;
RAISE NOTICE 'PASS Section5 batches1–4: 190 observed pages, 10 notfound with game defaults, 1016 still queued; 91 protected time rules unchanged';
END $checks$;