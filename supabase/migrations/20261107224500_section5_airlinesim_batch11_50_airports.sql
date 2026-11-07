-- Airlinerra World1 Section5 simplified AirlineSim research Batch11.
-- 45 public AirlineSim pages IATA-matched (HR,HT,HU,ID). Five Indonesian codes
-- absent from all seven public Indonesian region airport lists => neutral GAME fallback.
-- Do not override official source-backed airport restrictions.
BEGIN;
WITH source_data(country_iso,airport_code,airlinesim_id,ban,noise,source_status,source_url) AS (
VALUES
('HR','BWK',1877,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1877'),
('HR','OSI',1879,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1879'),
('HR','PUY',1880,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1880'),
('HR','SPU',1882,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1882'),
('HR','ZAD',1883,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1883'),
('HR','ZAG',1884,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1884'),
('HT','CAP',1108,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1108'),
('HT','PAP',1110,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1110'),
('HU','DEB',3048,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=3048'),
('HU','PEV',4808,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4808'),
('HU','QGY',4198,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4198'),
('HU','SOB',3049,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=3049'),
('ID','AAP',1245,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1245'),
('ID','ARD',4652,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4652'),
('ID','BDJ',1203,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1203'),
('ID','BTJ',1200,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1200'),
('ID','BUU',4676,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4676'),
('ID','BWX',4320,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4320'),
('ID','DJJ',1218,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1218'),
('ID','ENE',1212,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1212'),
('ID','HLP',1215,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1215'),
('ID','KBU',1222,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1222'),
('ID','KDI',1220,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1220'),
('ID','KRC',5024,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=5024'),
('ID','LBJ',1224,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1224'),
('ID','LLO',4329,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4329'),
('ID','LSW',4669,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4669'),
('ID','MOF',1230,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1230'),
('ID','PDG',1236,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1236'),
('ID','PKN',1240,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1240'),
('ID','PKU',1242,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1242'),
('ID','PLM',1238,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1238'),
('ID','PNK',1243,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1243'),
('ID','RTG',4686,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4686'),
('ID','RTI',4685,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4685'),
('ID','SMQ',1246,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1246'),
('ID','SOC',1249,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1249'),
('ID','SRG',1247,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1247'),
('ID','SWQ',1251,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1251'),
('ID','SXK',4688,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4688'),
('ID','TJQ',1254,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1254'),
('ID','TKG',1201,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1201'),
('ID','TLI',4698,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=4698'),
('ID','TMC',1253,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1253'),
('ID','TRK',1257,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1257'),
('ID','MOH',NULL,false,false,'AIRLINESIM_NOT_FOUND','https://free1.airlinesim.aero/action/info/country?id=62'),
('ID','NBR',NULL,false,false,'AIRLINESIM_NOT_FOUND','https://free1.airlinesim.aero/action/info/country?id=62'),
('ID','RJM',NULL,false,false,'AIRLINESIM_NOT_FOUND','https://free1.airlinesim.aero/action/info/country?id=62'),
('ID','RKI',NULL,false,false,'AIRLINESIM_NOT_FOUND','https://free1.airlinesim.aero/action/info/country?id=62'),
('ID','TQG',NULL,false,false,'AIRLINESIM_NOT_FOUND','https://free1.airlinesim.aero/action/info/country?id=62')
), identified AS(
 SELECT q.world_id,q.airport_key,d.*
 FROM source_data d JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 ON q.world_id=1 AND q.batch_no=11 AND q.review_status='PENDING'
 AND q.country_iso=d.country_iso AND q.airport_code=d.airport_code
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
SET nighttime_ban=d.ban,noise_restrictions=d.noise,
 permitted_noise_chapters=CASE WHEN d.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=CASE WHEN d.ban THEN '0:01 and 5:59' ELSE NULL END,
 source_status=d.source_status, source_url=d.source_url,captured_on=DATE '2026-11-07',
 note=CASE WHEN d.airlinesim_id IS NOT NULL THEN
 'AirlineSim Free1 individual airport source page checked on 2026-11-07 in Batch11; simple game nighttime/noise flags, not official aviation permission.'
 ELSE 'IATA code not listed in any of 7 complete regional AirlineSim Indonesia airport directories (Jawa/Kalimantan/Maluku/Nusa Tenggara/Papua/Sulawesi/Sumatera) on 2026-11-07. Owner-approved neutral No/None game default, not independently verified airport restrictions.' END
FROM identified d WHERE s.world_id=d.world_id AND s.airport_key=d.airport_key AND s.source_status='GAME_DEFAULT_NOT_CHECKED';

UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status=CASE WHEN s.source_status='AIRLINESIM_NOT_FOUND' THEN 'AIRLINESIM_NOT_FOUND' ELSE 'AIRLINESIM_PAGE_OBSERVED' END,
reviewed_on=DATE '2026-11-07',review_source_url=s.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
WHERE q.world_id=1 AND q.batch_no=11 AND q.review_status='PENDING'
 AND q.world_id=s.world_id AND q.airport_key=s.airport_key
 AND s.source_status IN('AIRLINESIM_PAGE_OBSERVED','AIRLINESIM_NOT_FOUND');

DO $validate$
DECLARE n integer; source_count integer; unfound_count integer; waiting integer; ban_count integer; noise_count integer;
BEGIN
SELECT count(*), count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
 count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),count(*) FILTER(WHERE review_status='PENDING')
INTO n,source_count,unfound_count,waiting
FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=11;
IF n<>50 OR source_count<>45 OR unfound_count<>5 OR waiting<>0
THEN RAISE EXCEPTION 'Batch11 incomplete % pages%,notfound%,pending%',n,source_count,unfound_count,waiting;END IF;
SELECT count(*) FILTER(WHERE s.nighttime_ban),count(*) FILTER(WHERE s.noise_restrictions)
INTO ban_count,noise_count FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
WHERE q.world_id=1 AND q.batch_no=11;
IF ban_count<>2 OR noise_count<>3 THEN RAISE EXCEPTION 'Batch11 game flags incorrect %/%',ban_count,noise_count;END IF;
IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216 THEN
 RAISE EXCEPTION 'Original tracked queue modified';END IF;
IF(SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91 THEN
 RAISE EXCEPTION 'Existing official precise curfew rules altered';END IF;
IF(SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246 THEN
 RAISE EXCEPTION 'Historical detailed source research queue altered';END IF;
END $validate$;
COMMIT;