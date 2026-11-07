BEGIN;
-- Reprioritize untouched queue for the researched Brazil region list;
-- preserve first two checked 50-airport batches.
DELETE FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1
 WHERE world_id=1 AND review_status='PENDING';
WITH prioritized(country_iso,airport_code,priority_pos) AS (
 VALUES ('BR','AAX',1),
('BR','AQA',2),
('BR','ARU',3),
('BR','ATM',4),
('BR','AUX',5),
('BR','BRA',6),
('BR','BSB',7),
('BR','BYO',8),
('BR','CFB',9),
('BR','CKS',10),
('BR','CMG',11),
('BR','CXJ',12),
('BR','CZS',13),
('BR','FBE',14),
('BR','FEN',15),
('BR','GRU',16),
('BR','GVR',17),
('BR','IMP',18),
('BR','IPN',19),
('BR','ITB',20),
('BR','IZA',21),
('BR','JDF',22),
('BR','JDO',23),
('BR','JJD',24),
('BR','JJG',25),
('BR','JOI',26),
('BR','JPR',27),
('BR','JTC',28),
('BR','LAJ',29),
('BR','LDB',30),
('BR','LEC',31),
('BR','MAO',32),
('BR','MGF',33),
('BR','MII',34),
('BR','MVF',35),
('BR','NVT',36),
('BR','OAL',37),
('BR','OPS',38),
('BR','PAV',39),
('BR','PET',40),
('BR','PFB',41),
('BR','PGZ',42),
('BR','PHB',43),
('BR','PMG',44),
('BR','POA',45),
('BR','RIA',46),
('BR','SDU',47),
('BR','SJK',48),
('BR','SSA',49),
('BR','TBT',50)
), remaining AS (
 SELECT n.world_id,n.airport_key,n.airport_code,n.country_iso,
 (row_number() OVER(ORDER BY CASE WHEN pr.priority_pos IS NULL THEN 1 ELSE 0 END,
 pr.priority_pos NULLS LAST,n.country_iso,n.airport_code,n.airport_key)+100)::integer rn
 FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1 n
 JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
 LEFT JOIN prioritized pr ON pr.country_iso=n.country_iso AND pr.airport_code=n.airport_code
 WHERE n.world_id=1 AND n.normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING'
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED'
)
INSERT INTO airlinerra_game.section5_airlinesim_review_batch_queue_v1
(world_id,airport_key,airport_code,country_iso,batch_no,row_no)
SELECT world_id,airport_key,airport_code,country_iso,((rn-1)/50)+1,rn FROM remaining;
DO $assert$ BEGIN
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
 THEN RAISE EXCEPTION 'AirlineSim batch plan count changed'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1
 WHERE world_id=1 AND batch_no=3 AND review_status='PENDING')<>50
 THEN RAISE EXCEPTION 'Batch3 incorrect'; END IF;
END $assert$;
WITH confirmed(country_iso,code,as_id,ban) AS (
 VALUES
('BR','AAX',400,false),
('BR','AQA',399,false),
('BR','ARU',397,false),
('BR','ATM',395,false),
('BR','AUX',398,false),
('BR','BRA',401,false),
('BR','BSB',407,false),
('BR','BYO',4095,false),
('BR','CFB',408,false),
('BR','CKS',414,false),
('BR','CMG',418,false),
('BR','CXJ',416,false),
('BR','CZS',420,false),
('BR','FBE',4102,false),
('BR','FEN',424,false),
('BR','GRU',480,false),
('BR','GVR',429,false),
('BR','IMP',432,false),
('BR','IPN',433,false),
('BR','ITB',434,false),
('BR','IZA',4453,false),
('BR','JDF',439,false),
('BR','JDO',438,false),
('BR','JJD',4448,false),
('BR','JJG',4450,false),
('BR','JOI',437,false),
('BR','JPR',435,false),
('BR','JTC',4094,false),
('BR','LAJ',440,false),
('BR','LDB',442,false),
('BR','LEC',441,false),
('BR','MAO',445,false),
('BR','MGF',448,false),
('BR','MII',447,false),
('BR','MVF',451,true),
('BR','NVT',454,false),
('BR','OAL',4446,false),
('BR','OPS',481,false),
('BR','PAV',4455,false),
('BR','PET',459,false),
('BR','PFB',458,false),
('BR','PGZ',4456,false),
('BR','PHB',457,false),
('BR','PMG',461,false),
('BR','POA',462,false),
('BR','RIA',474,false),
('BR','SDU',470,true),
('BR','SJK',473,false),
('BR','SSA',472,false),
('BR','TBT',483,false)
), selected AS (
 SELECT n.world_id,n.airport_key,c.*
 FROM confirmed c JOIN airlinerra_game.section5_airport_restriction_normalization_queue_v1 n
 ON n.world_id=1 AND n.country_iso=c.country_iso AND n.airport_code=c.code
 JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
 ON q.world_id=n.world_id AND q.airport_key=n.airport_key AND q.batch_no=3
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 g
SET nighttime_ban=s.ban, noise_restrictions=false, permitted_noise_chapters='{}'::smallint[],
 simplified_nighttime_window=CASE WHEN s.ban THEN '0:01 and 5:59' ELSE NULL END,
 source_status='AIRLINESIM_PAGE_OBSERVED',
 source_url='https://free1.airlinesim.aero/action/info/airport?id='||s.as_id::text,
 captured_on=DATE '2026-11-07',
 note='AirlineSim Brazil public airport Information page individually checked in Batch3 2026-11-07: all 50 say no noise restrictions; two say nighttime ban 0:01–5:59. Simplified game classification, not legal clearance.'
FROM selected s WHERE g.world_id=s.world_id AND g.airport_key=s.airport_key
 AND g.source_status='GAME_DEFAULT_NOT_CHECKED';
UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status='AIRLINESIM_PAGE_OBSERVED', reviewed_on=DATE '2026-11-07',review_source_url=s.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
WHERE q.world_id=1 AND q.world_id=s.world_id AND q.airport_key=s.airport_key
 AND q.batch_no=3 AND s.source_status='AIRLINESIM_PAGE_OBSERVED';
DO $verify$
BEGIN
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=3 AND review_status='AIRLINESIM_PAGE_OBSERVED')<>50
 THEN RAISE EXCEPTION 'Batch3 did not finish 50'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=3 AND review_status='PENDING')<>0
 THEN RAISE EXCEPTION 'Batch3 still pending'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
  WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Existing official research queue was modified'; END IF;
END $verify$;
COMMIT;