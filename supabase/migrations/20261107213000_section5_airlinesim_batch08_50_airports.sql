-- Airlinerra Section5 AirlineSim batch08: 49 confirmed airport detail pages; 1 not found (JCL).
-- Binary game summary fields only: source-backed runway/curfew restrictions remain authoritative.
BEGIN;
WITH observed(country_iso,code,as_id,ban,noise,kind,country_id) AS(
 VALUES
 ('CN','YNZ',635,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','YTY',4201,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','APO',1814,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','BAQ',1820,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','EJA',1819,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','EOH',1842,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','MZL',1841,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','NVA',1846,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','PCR',1855,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','PDA',1856,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','PEI',1850,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','PPN',1851,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','PSO',1849,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','PUU',1853,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','RCH',1859,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','SMR',1863,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','SVI',1862,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','TLU',1866,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','VUP',1869,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CO','VVC',1870,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CR','GLF',653,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CR','LIO',3991,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CR','LIR',654,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CR','SJO',660,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CR','SYQ',3992,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CU','CMW',1885,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CU','HOG',1891,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CU','SCU',1893,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CU','SNU',1892,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CV','BVC',1760,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CV','RAI',1761,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CV','SID',1762,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CV','VXE',1766,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CW','CUR',2255,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CX','XCH',162,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CY','PFO',3854,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CZ','KLV',2980,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CZ','PED',3966,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CZ','PRG',2983,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','DTM',706,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','EME',709,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','ERF',710,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','FCN',737,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','FDH',713,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','FKB',721,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','FMM',3861,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','GWT',746,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','HDF',719,true,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('DE','KSF',722,false,true,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CZ','JCL',NULL,false,false,'AIRLINESIM_NOT_FOUND',173)
), verified AS (
 SELECT q.world_id,q.airport_key,o.*
 FROM observed o JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 ON q.world_id=1 AND q.batch_no=8 AND q.review_status='PENDING'
 AND q.airport_code=o.code AND q.country_iso=o.country_iso
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
SET nighttime_ban=v.ban,
 noise_restrictions=v.noise,
 permitted_noise_chapters=CASE WHEN v.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=CASE WHEN v.ban THEN '0:01 and 5:59' ELSE NULL END,
 source_status=v.kind,
 source_url=CASE WHEN v.as_id IS NOT NULL THEN 'https://free1.airlinesim.aero/action/info/airport?id='||v.as_id::text
 ELSE 'https://free1.airlinesim.aero/action/info/country?id='||v.country_id::text END,
 captured_on=DATE '2026-11-07',
 note=CASE WHEN v.as_id IS NOT NULL THEN
 'AirlineSim Free1 airport information page observed and IATA/ICAO checked for Section5 Batch8 on 2026-11-07. Simplified game noise/night classification; not real-world legal clearance.'
 ELSE 'Ceske Budejovice (JCL) not listed in complete 6-airport AirlineSim Czech Republic country list; owner-approved No/None game default. No claim about real-world aviation permissions.'
 END
FROM verified v WHERE s.world_id=v.world_id AND s.airport_key=v.airport_key AND s.source_status='GAME_DEFAULT_NOT_CHECKED';

UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status=CASE WHEN s.source_status='AIRLINESIM_NOT_FOUND' THEN 'AIRLINESIM_NOT_FOUND' ELSE 'AIRLINESIM_PAGE_OBSERVED' END,
 reviewed_on=DATE '2026-11-07',review_source_url=s.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
WHERE q.world_id=1 AND q.batch_no=8 AND q.review_status='PENDING'
AND q.world_id=s.world_id AND q.airport_key=s.airport_key
AND s.source_status IN('AIRLINESIM_PAGE_OBSERVED','AIRLINESIM_NOT_FOUND');
DO $verify$
DECLARE c integer;p integer;n integer;remain integer;
BEGIN
SELECT count(*),count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),
count(*) FILTER(WHERE review_status='PENDING')
INTO c,p,n,remain
FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=8;
IF c<>50 OR p<>49 OR n<>1 OR remain<>0 THEN
RAISE EXCEPTION 'Batch08 incomplete count %,pages %,notfound %,pending %',c,p,n,remain; END IF;
IF (SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
THEN RAISE EXCEPTION 'Original 1216 airport batch queue altered'; END IF;
IF (SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
THEN RAISE EXCEPTION 'Official source-backed time rules unexpectedly modified'; END IF;
IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
THEN RAISE EXCEPTION 'Original research-only normalization queue modified'; END IF;
END $verify$;
COMMIT;