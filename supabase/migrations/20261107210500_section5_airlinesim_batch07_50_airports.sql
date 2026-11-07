-- World1 Section5 AirlineSim Batch7: 49 airport detail pages, 1 not found game fallback (Chile LMF).
-- The simplified result never overrides existing official/source-backed hard restrictions.
BEGIN;
WITH observed(country_iso,code,airlinesim_id,ban,noise,source_status,source_country_id) AS(
 VALUES
 ('CA','YYZ',1701,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','YZF',1632,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CA','ZBF',1607,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CC','CCK',163,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CD','FKI',763,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CD','GOM',760,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CD','MDK',766,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CH','ACH',2758,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CH','BRN',2760,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CH','LUG',2762,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CK','AIT',2235,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','BBA',507,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','CPO',511,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','ESR',512,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','IPC',514,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','MHC',4317,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','ZAL',522,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','ZOS',516,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','ZPC',517,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','AAT',524,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','DLC',541,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','HET',562,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','HFE',561,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','HIA',4286,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','HLD',557,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','HRB',560,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','HSN',647,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','JGN',567,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','JHG',571,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','JJN',572,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','KHG',575,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','KWL',554,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','LJG',582,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','LXA',580,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','LYA',586,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','NNG',594,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','NTG',595,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','PEK',598,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','PKX',4413,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','SHA',604,true,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','SHE',608,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','SJW',610,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','SYX',603,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','TNA',569,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','WUX',3919,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','XNN',632,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','XUZ',633,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','YIW',642,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CN','YNT',637,false,false,'AIRLINESIM_PAGE_OBSERVED',NULL),
 ('CL','LMF',NULL,false,false,'AIRLINESIM_NOT_FOUND',29)
), matched AS(
 SELECT q.world_id,q.airport_key,o.*
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 JOIN observed o ON o.country_iso=q.country_iso AND o.code=q.airport_code
 WHERE q.world_id=1 AND q.batch_no=7 AND q.review_status='PENDING'
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
SET nighttime_ban=m.ban,
 noise_restrictions=m.noise,
 permitted_noise_chapters=CASE WHEN m.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=CASE WHEN m.ban THEN '0:01 and 5:59' ELSE NULL END,
 source_status=m.source_status,
 source_url=CASE WHEN m.airlinesim_id IS NOT NULL THEN
  'https://free1.airlinesim.aero/action/info/airport?id='||m.airlinesim_id::text
 ELSE 'https://free1.airlinesim.aero/action/info/country?id='||m.source_country_id::text END,
 captured_on=DATE '2026-11-07',
 note=CASE WHEN m.airlinesim_id IS NOT NULL THEN
 'AirlineSim Free1 public airport information page observed and airport IATA/ICAO identity confirmed, 2026-11-07, Batch7. Simple nighttime ban and noise game rules, not real-world flight clearance.'
 ELSE 'LMF not listed in complete AirlineSim Chile airport directory 2026-11-07; owner-approved neutral No/None game fallback; not an assertion about real airport operating restrictions.'
 END
FROM matched m
WHERE s.world_id=m.world_id AND s.airport_key=m.airport_key
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED';
UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status=CASE WHEN s.source_status='AIRLINESIM_NOT_FOUND' THEN 'AIRLINESIM_NOT_FOUND' ELSE 'AIRLINESIM_PAGE_OBSERVED' END,
 reviewed_on=DATE '2026-11-07', review_source_url=s.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
WHERE q.world_id=1 AND q.batch_no=7 AND q.review_status='PENDING'
 AND q.world_id=s.world_id AND q.airport_key=s.airport_key
 AND s.source_status IN('AIRLINESIM_PAGE_OBSERVED','AIRLINESIM_NOT_FOUND');
DO $verify$
DECLARE r integer; checked integer; notfound integer; pending integer;
BEGIN
 SELECT count(*),count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
  count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),
  count(*) FILTER(WHERE review_status='PENDING')
 INTO r,checked,notfound,pending
 FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=7;
 IF r<>50 OR checked<>49 OR notfound<>1 OR pending<>0 THEN
  RAISE EXCEPTION 'Batch7 invalid progress %/checked %/missing %/pending %',r,checked,notfound,pending; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
 THEN RAISE EXCEPTION 'Batch queue changed'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1 WHERE world_id=1)<>91
 THEN RAISE EXCEPTION 'Historical source-backed time restrictions modified'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Original research queue modified'; END IF;
END $verify$;
COMMIT;