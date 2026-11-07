-- AIRLINERRA Section 5: AirlineSim Batch 6 (50 airport game classifications)
-- 47 IATA/ICAO-verified AirlineSim airport pages, 3 explicit not-found cases.
-- Keep official sourced rules unchanged; neutral defaults are not authoritative permission.
BEGIN;
WITH observed(country_iso,code,as_id,ban,noise,status,country_id) AS (
 VALUES
 ('BE','OST',360,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BG','BOJ',498,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BI','BJM',504,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BN','BWN',497,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BO','ORU',4440,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BO','RBQ',379,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BO','SRE',381,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BO','UYU',4442,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BQ','BON',2254,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BQ','EUX',2257,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BS','ELH',337,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BS','FPO',328,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BS','GGT',329,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BS','GHB',330,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BS','LGI',327,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BS','MYG',334,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BS','TZN',325,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BS','ZSA',340,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BT','PBH',372,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BW','FRW',389,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BW','GBE',390,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BW','MUB',392,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BY','BQT',4177,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YAG',1664,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YBC',1709,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YBG',1708,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YCD',1532,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YCG',1518,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YDA',1757,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YDF',1588,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YHU',4176,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YLW',1529,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YQD',1579,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YQG',1703,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YQM',1609,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YQQ',1519,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YQR',1752,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YRL',1688,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YUL',1730,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YVC',1749,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YVR',1551,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YWG',1581,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YWK',1602,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YXE',1753,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YYF',1535,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YYJ',1553,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YYY',1728,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BO','CCA',NULL,false,false,'AIRLINESIM_NOT_FOUND',21),
 ('BW','SWX',NULL,false,false,'AIRLINESIM_NOT_FOUND',23),
 ('BR','UMU',NULL,false,false,'AIRLINESIM_NOT_FOUND',24)
), selected AS (
 SELECT q.world_id,q.airport_key,o.*
 FROM observed o JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 ON q.world_id=1 AND q.country_iso=o.country_iso AND q.airport_code=o.code
 AND q.batch_no=6 AND q.review_status='PENDING'
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
SET nighttime_ban=v.ban,
 noise_restrictions=v.noise,
 permitted_noise_chapters=CASE WHEN v.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=CASE WHEN v.ban THEN '0:01 and 5:59' ELSE NULL END,
 source_status=v.status,
 source_url=CASE WHEN v.as_id IS NOT NULL THEN
 'https://free1.airlinesim.aero/action/info/airport?id='||v.as_id::text
 ELSE 'https://free1.airlinesim.aero/action/info/country?id='||v.country_id::text END,
 captured_on=DATE '2026-11-07',
 note=CASE WHEN v.as_id IS NOT NULL THEN
 'AirlineSim Free1 airport Information page checked on 2026-11-07 (Section5 Batch6); simplified nighttime ban + ICAO Chapter game flag, not official aviation regulatory clearance.'
 ELSE
 'No matching IATA airport on the relevant AirlineSim complete country/regional airport list (Bolivia CCA, Botswana SWX, Brazil UMU) on 2026-11-07; owner-approved No/None GAME default, not proof of no real restrictions.' END
FROM selected v WHERE s.world_id=v.world_id AND s.airport_key=v.airport_key
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED';

UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status=CASE WHEN s.source_status='AIRLINESIM_NOT_FOUND' THEN 'AIRLINESIM_NOT_FOUND'
  ELSE 'AIRLINESIM_PAGE_OBSERVED' END,
 reviewed_on=DATE '2026-11-07',review_source_url=s.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
WHERE q.world_id=1 AND q.batch_no=6 AND q.review_status='PENDING'
AND s.world_id=q.world_id AND s.airport_key=q.airport_key
AND s.source_status IN('AIRLINESIM_PAGE_OBSERVED','AIRLINESIM_NOT_FOUND');

DO $verify$
DECLARE total integer; checked integer; unfound integer; unprocessed integer;
BEGIN
 SELECT count(*),
 count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
 count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),
 count(*) FILTER(WHERE review_status='PENDING')
 INTO total,checked,unfound,unprocessed
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1
 WHERE world_id=1 AND batch_no=6;
 IF total<>50 OR checked<>47 OR unfound<>3 OR unprocessed<>0 THEN
 RAISE EXCEPTION 'Batch6 invalid rows %,checked %,notfound %,pending %',total,checked,unfound,unprocessed; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
 THEN RAISE EXCEPTION 'Batch queue size changed'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
 THEN RAISE EXCEPTION 'Precise airport time rules modified'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Existing airport research not preserved'; END IF;
END $verify$;
COMMIT;