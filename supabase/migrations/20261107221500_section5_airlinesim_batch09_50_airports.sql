-- Airlinerra World1 — Section5 AirlineSim simplified source review Batch9 (50 airports).
-- IATA/ICAO match checked against the 49 individual public AirlineSim pages.
-- EC IBB is absent from the Ecuador country list; only a NEUTRAL GAME fallback is assigned.
-- Source-backed official operating/curfew/noise restrictions remain separate and unchanged.
BEGIN;
WITH observed(country_iso,code,airlinesim_id,ban,noise,status,country_id) AS(
 VALUES
 ('DE','LBC',728,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','NUE',738,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','PAD',740,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','RLG',741,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','SCN',742,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DM','DOM',750,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DO','LRM',751,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DO','STI',755,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DZ','BSK',57,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DZ','DJG',61,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DZ','GJL',69,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DZ','LOO',70,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DZ','MZW',72,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DZ','TEE',77,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EC','CUE',769,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EC','ESM',770,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EC','GPS',782,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EC','SCY',781,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EC','SNC',780,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EE','KDL',787,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EE','TAY',3965,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EE','URE',788,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EG','ABS',1,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EG','DBB',4643,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EG','PSD',4126,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EG','RMF',11,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ES','FUE',2823,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ES','GMZ',2826,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ES','IBZ',2801,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ES','MAH',2808,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ES','MLN',2831,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ES','SPC',2827,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ES','TFN',2828,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ES','VDE',2830,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ET','ABK',36,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ET','AWA',4645,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('ET','JIJ',33,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','ENF',807,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','JOE',810,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','JYV',811,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','KAJ',812,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','KAO',818,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','KEM',814,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','KOK',816,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','KTT',815,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','LPP',819,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','MHQ',820,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','OUL',822,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('FI','POR',823,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('EC','IBB',NULL,false,false,'AIRLINESIM_NOT_FOUND',40)
), verified AS(
 SELECT q.world_id,q.airport_key,o.*
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 JOIN observed o ON o.country_iso=q.country_iso AND o.code=q.airport_code
 WHERE q.world_id=1 AND q.batch_no=9 AND q.review_status='PENDING'
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
SET nighttime_ban=v.ban,
 noise_restrictions=v.noise,
 permitted_noise_chapters=CASE WHEN v.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=CASE WHEN v.ban THEN '0:01 and 5:59' ELSE NULL END,
 source_status=v.status,
 source_url=CASE WHEN v.airlinesim_id IS NOT NULL
 THEN 'https://free1.airlinesim.aero/action/info/airport?id='||v.airlinesim_id::text
 ELSE 'https://free1.airlinesim.aero/action/info/country?id='||v.country_id::text END,
 captured_on=DATE '2026-11-07',
 note=CASE WHEN v.airlinesim_id IS NOT NULL THEN
 'AirlineSim Free1 public airport detail page checked on 2026-11-07 in Section5 Batch9; simple night ban and noise Chapter permitted flags only. Not a certified real-world aviation clearance.'
 ELSE
 'IBB/SEII not listed in all 18 airports on AirlineSim Ecuador country page on 2026-11-07; owner-approved neutral No nighttime ban / No noise restrictions GAME default, not real-world restriction verification.' END
FROM verified v WHERE s.world_id=v.world_id AND s.airport_key=v.airport_key
AND s.source_status='GAME_DEFAULT_NOT_CHECKED';

UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status=CASE WHEN s.source_status='AIRLINESIM_NOT_FOUND' THEN 'AIRLINESIM_NOT_FOUND' ELSE 'AIRLINESIM_PAGE_OBSERVED' END,
 reviewed_on=DATE '2026-11-07',review_source_url=s.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
WHERE q.world_id=1 AND q.batch_no=9 AND q.review_status='PENDING'
 AND s.world_id=q.world_id AND s.airport_key=q.airport_key
 AND s.source_status IN('AIRLINESIM_PAGE_OBSERVED','AIRLINESIM_NOT_FOUND');

DO $verify$
DECLARE n integer; checked integer; unfound integer; waiting integer; ban_count integer; noise_count integer;
BEGIN
 SELECT count(*),count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
 count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),count(*) FILTER(WHERE review_status='PENDING')
 INTO n,checked,unfound,waiting
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=9;
 IF n<>50 OR checked<>49 OR unfound<>1 OR waiting<>0 THEN
 RAISE EXCEPTION 'Section5 Batch9 incomplete count %,checked %,notfound %,pending %',n,checked,unfound,waiting; END IF;
 SELECT count(*) FILTER(WHERE s.nighttime_ban),count(*) FILTER(WHERE s.noise_restrictions)
 INTO ban_count,noise_count
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
 WHERE q.world_id=1 AND q.batch_no=9;
 IF ban_count<>10 OR noise_count<>22 THEN RAISE EXCEPTION 'Observed simple flags mismatch %/%',ban_count,noise_count;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
 THEN RAISE EXCEPTION 'Original 1216 airport review queue modified'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
 THEN RAISE EXCEPTION 'Existing source-backed airport time rules changed';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Historical separate operating research queue altered';END IF;
END $verify$;
COMMIT;