-- SECTION5 AIRLINESIM Batch5: verify 47 airport pages; 3 not found after complete source directory check.
-- Preserves source-backed official operating rules and keeps provenance distinct from game fallback.
BEGIN;
WITH observations(country_iso,airport_code,airlinesim_id,nighttime_ban,noise_restrictions,source_status,source_country_id) AS (
 VALUES
 ('AF','HEA',45,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AF','KBL',47,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AF','KDH',48,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AF','MZR',49,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AI','AXA',1090,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AM','LWN',156,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AR','AEP',97,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AR','BRC',139,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AR','IRJ',115,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AR','JUJ',114,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AR','RGA',133,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AR','SFN',145,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AR','UAQ',140,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AS','PPG',3606,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AT','GRZ',2322,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AT','INN',2323,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AT','KLU',2324,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AT','LNZ',2325,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AT','LOWW',2327,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AT','SZG',2326,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','BME',297,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','BQB',4427,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','EDR',233,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','HTI',236,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','KNS',287,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','MCV',206,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','MCY',264,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','MQL',292,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','NTL',189,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','OKY',255,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','OLP',279,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','PHE',319,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','ROK',259,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AU','WGA',196,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AZ','GNJ',159,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AZ','GYD',158,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AZ','LLK',4192,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AZ','NAJ',160,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BA','BNX',385,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BA','OMO',386,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BA','SJJ',387,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BA','TZL',388,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BD','CGP',348,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BD','CXB',349,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BD','ZYL',354,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BE','ANR',356,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('BE','LGG',359,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('AE','ZDY',NULL,false,false,'AIRLINESIM_NOT_FOUND',184),
 ('AR','EDP',NULL,false,false,'AIRLINESIM_NOT_FOUND',9),
 ('AU','KQR',NULL,false,false,'AIRLINESIM_NOT_FOUND',12)
), matched AS (
 SELECT q.world_id,q.airport_key,o.*
 FROM observations o
 JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
   ON q.world_id=1 AND q.batch_no=5 AND q.review_status='PENDING'
   AND q.country_iso=o.country_iso AND q.airport_code=o.airport_code
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
 SET nighttime_ban=m.nighttime_ban,
 noise_restrictions=m.noise_restrictions,
 permitted_noise_chapters=CASE WHEN m.noise_restrictions THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=CASE WHEN m.nighttime_ban THEN '0:01 and 5:59' ELSE NULL END,
 source_status=m.source_status,
 source_url=CASE WHEN m.airlinesim_id IS NOT NULL
  THEN 'https://free1.airlinesim.aero/action/info/airport?id='||m.airlinesim_id::text
  ELSE 'https://free1.airlinesim.aero/action/info/country?id='||m.source_country_id::text END,
 captured_on=DATE '2026-11-07',
 note=CASE WHEN m.airlinesim_id IS NOT NULL THEN
 'AirlineSim Free1 airport page individually observed on 2026-11-07, Section5 Batch5. Checked IATA/ICAO identity; simple game night ban and noise flags. Not official flight clearance.'
 ELSE
 'Not located in full AirlineSim country/region airport directory after lookup on 2026-11-07 (UAE ZDY, Argentina EDP or Australia KQR). Owner-approved neutral No night ban / No noise restrictions GAME default; not an official absence of restriction.'
 END
FROM matched m WHERE s.world_id=m.world_id AND s.airport_key=m.airport_key
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED';

UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 SET review_status=CASE WHEN s.source_status='AIRLINESIM_NOT_FOUND' THEN 'AIRLINESIM_NOT_FOUND'
 ELSE 'AIRLINESIM_PAGE_OBSERVED' END,
 reviewed_on=DATE '2026-11-07',
 review_source_url=s.source_url
 FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
 WHERE q.world_id=1 AND q.batch_no=5 AND q.review_status='PENDING'
 AND s.world_id=q.world_id AND s.airport_key=q.airport_key
 AND s.source_status IN('AIRLINESIM_PAGE_OBSERVED','AIRLINESIM_NOT_FOUND');

DO $verify$
DECLARE c integer; observed integer; notfound integer; pending integer;
BEGIN
 SELECT count(*), count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
 count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),
 count(*) FILTER(WHERE review_status='PENDING')
 INTO c, observed, notfound, pending
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=5;
 IF c<>50 OR observed<>47 OR notfound<>3 OR pending<>0
 THEN RAISE EXCEPTION 'Batch5 mismatch rows%, pages%, missing%, pending%', c,observed,notfound,pending; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
 THEN RAISE EXCEPTION 'Original 1216 batch queue changed'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
 THEN RAISE EXCEPTION 'Verified curfew time rules changed'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
  WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Historical research queue modified'; END IF;
END $verify$;
COMMIT;