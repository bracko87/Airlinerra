-- AIRLINERRA Section5 simplifed AirlineSim night/noise classification Batch10, World1.
-- 48 AirlineSim source pages individually verified by code; SUI and UAK absent
-- from their Georgia and Greenland public directories => neutral game defaults.
-- Never overwrite original sourced airport rules or interpret defaults as legal clearance.
BEGIN;
WITH observed(country_iso,airport_code,as_id,ban,noise,source_status,source_url) AS(
 VALUES
 ('FI','RVN',824,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=824'),
 ('FI','SVL',825,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=825'),
 ('FI','TKU',828,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=828'),
 ('FJ','SUV',804,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=804'),
 ('FK','MPN',1088,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1088'),
 ('FM','KSA',2128,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=2128'),
 ('FM','TKK',2130,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=2130'),
 ('FM','YAP',2131,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=2131'),
 ('FO','FAE',674,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=674'),
 ('GA','POG',966,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=966'),
 ('GD','GND',974,true,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=974'),
 ('GG','GCI',1040,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1040'),
 ('GH','KMS',972,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=972'),
 ('GH','TML',973,true,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=973'),
 ('GI','GIB',1089,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1089'),
 ('GL','GOH',686,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=686'),
 ('GL','SFJ',679,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=679'),
 ('GP','PTP',909,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=909'),
 ('GR','AOK',984,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=984'),
 ('GR','ATH',977,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=977'),
 ('GR','AXD',975,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=975'),
 ('GR','JIK',981,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=981'),
 ('GR','JKH',979,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=979'),
 ('GR','JMK',996,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=996'),
 ('GR','JSH',1006,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1006'),
 ('GR','JSI',1007,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1007'),
 ('GR','JTR',1005,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1005'),
 ('GR','KIT',991,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=991'),
 ('GR','KLX',983,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=983'),
 ('GR','KSO',987,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=987'),
 ('GR','KVA',988,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=988'),
 ('GR','KZI',993,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=993'),
 ('GR','LXS',994,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=994'),
 ('GR','MJT',998,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=998'),
 ('GR','PAS',1000,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1000'),
 ('GR','PVK',1002,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1002'),
 ('GR','RHO',1003,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1003'),
 ('GR','SKU',1008,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1008'),
 ('GR','SMI',1004,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1004'),
 ('GR','VOL',1011,false,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1011'),
 ('GR','ZTH',1012,true,true,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1012'),
 ('GW','OXB',1106,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1106'),
 ('GY','GEO',1107,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1107'),
 ('HK','HKG',649,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=649'),
 ('HN','LCE',1116,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1116'),
 ('HN','RTB',1119,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1119'),
 ('HN','SAP',1120,false,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1120'),
 ('HN','TGU',1121,true,false,'AIRLINESIM_PAGE_OBSERVED','https://free1.airlinesim.aero/action/info/airport?id=1121'),
 ('GE','SUI',NULL,false,false,'AIRLINESIM_NOT_FOUND','https://free1.airlinesim.aero/action/info/country?id=50'),
 ('GL','UAK',NULL,false,false,'AIRLINESIM_NOT_FOUND','https://free1.airlinesim.aero/action/info/county?id=12')
), verified AS(
 SELECT q.world_id,q.airport_key,o.*
 FROM observed o
 JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 ON q.world_id=1 AND q.batch_no=10 AND q.review_status='PENDING'
 AND q.country_iso=o.country_iso AND q.airport_code=o.airport_code
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
 SET nighttime_ban=v.ban,noise_restrictions=v.noise,
 permitted_noise_chapters=CASE WHEN v.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=CASE WHEN v.ban THEN '0:01 and 5:59' ELSE NULL END,
 source_status=v.source_status,source_url=v.source_url,captured_on=DATE '2026-11-07',
 note=CASE WHEN v.as_id IS NOT NULL THEN
 'AirlineSim Free1 individual public airport page checked on 2026-11-07 in Batch10; airport IATA/ICAO identity confirmed; simplified Yes/No nighttime and permitted Chapter game rules only. This is not official aviation approval.'
 ELSE
 'AirlineSim country/region directory checked on 2026-11-07: SUI absent from Georgia listing, or UAK absent from Greenland listing. Neutral No/None owner-approved GAME default; not proof of real-world unrestricted airport operation.'
 END
 FROM verified v WHERE s.world_id=v.world_id AND s.airport_key=v.airport_key
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED';
UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 SET review_status=CASE WHEN s.source_status='AIRLINESIM_NOT_FOUND' THEN 'AIRLINESIM_NOT_FOUND' ELSE 'AIRLINESIM_PAGE_OBSERVED' END,
 reviewed_on=DATE '2026-11-07',review_source_url=s.source_url
 FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
 WHERE q.world_id=1 AND q.batch_no=10 AND q.review_status='PENDING'
 AND q.world_id=s.world_id AND q.airport_key=s.airport_key
 AND s.source_status IN ('AIRLINESIM_PAGE_OBSERVED','AIRLINESIM_NOT_FOUND');
DO $check$
DECLARE row_count integer;checked integer;notfound integer;pending integer;night integer;noise integer;
BEGIN
 SELECT count(*),count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
 count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),count(*) FILTER(WHERE review_status='PENDING')
 INTO row_count,checked,notfound,pending
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=10;
 IF row_count<>50 OR checked<>48 OR notfound<>2 OR pending<>0
 THEN RAISE EXCEPTION 'Section5 Batch10 source coverage failed: %/checked%/notfound%/pending%',row_count,checked,notfound,pending; END IF;
 SELECT count(*) FILTER(WHERE s.nighttime_ban),count(*) FILTER(WHERE s.noise_restrictions)
 INTO night,noise
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
 WHERE q.world_id=1 AND q.batch_no=10;
 IF night<>22 OR noise<>29 THEN RAISE EXCEPTION 'Batch10 parsed flags mismatch % %',night,noise;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
 THEN RAISE EXCEPTION 'Batch queue changed size'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
 THEN RAISE EXCEPTION 'Official precise airport restrictions changed'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Independent source-based research queue modified'; END IF;
END $check$;
COMMIT;