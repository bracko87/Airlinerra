BEGIN;
-- Reorder only 1,166 untouched queue rows into Batch2 Italy/UK/Germany;
-- existing 50 checked Batch1 entries remain unchanged.
DELETE FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND review_status='PENDING';
WITH prioritized(country_iso,airport_code,priority_pos) AS (
VALUES ('IT','CIY',1),
('IT','CRV',2),
('IT','CUF',3),
('IT','FLR',4),
('IT','LMP',5),
('IT','MXP',6),
('IT','NAP',7),
('IT','OLB',8),
('IT','PEG',9),
('IT','PMF',10),
('IT','PMO',11),
('IT','PNL',12),
('IT','PSR',13),
('IT','QSR',14),
('IT','REG',15),
('IT','RMI',16),
('IT','SUF',17),
('IT','TPS',18),
('IT','TRN',19),
('IT','TRS',20),
('IT','TSF',21),
('IT','VBS',22),
('GB','BEB',23),
('GB','BHD',24),
('GB','BHX',25),
('GB','BOH',26),
('GB','CAL',27),
('GB','DND',28),
('GB','EXT',29),
('GB','HUY',30),
('GB','ILY',31),
('GB','INV',32),
('GB','KOI',33),
('GB','LBA',34),
('GB','LPL',35),
('GB','LSI',36),
('GB','LWK',37),
('GB','MAN',38),
('GB','MME',39),
('GB','NQY',40),
('GB','OBN',41),
('GB','PIK',42),
('GB','SEN',43),
('GB','SOU',44),
('GB','SYY',45),
('GB','TRE',46),
('GB','WIC',47),
('DE','BRE',48),
('DE','CGN',49),
('DE','DRS',50)
), unprocessed AS (
SELECT n.world_id,n.airport_key,n.airport_code,n.country_iso,pr.priority_pos,
 (row_number() OVER(ORDER BY CASE WHEN pr.priority_pos IS NULL THEN 1 ELSE 0 END,
   pr.priority_pos NULLS LAST,n.country_iso,n.airport_code,n.airport_key)+50)::integer AS rn
 FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1 n
 JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
 LEFT JOIN prioritized pr ON pr.country_iso=n.country_iso AND pr.airport_code=n.airport_code
 WHERE n.world_id=1 AND n.normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING'
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED'
)
INSERT INTO airlinerra_game.section5_airlinesim_review_batch_queue_v1(world_id,airport_key,airport_code,country_iso,batch_no,row_no)
SELECT world_id,airport_key,airport_code,country_iso,((rn-1)/50)+1,rn FROM unprocessed;
DO $verify_reorder$ BEGIN
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
 THEN RAISE EXCEPTION 'Queue lost rows'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=2 AND review_status='PENDING')<>50
 THEN RAISE EXCEPTION 'Batch2 queue incorrect'; END IF;
END $verify_reorder$;
WITH observed(country_iso,code,as_id,ban,noise,ban_window) AS (
VALUES
('IT','CIY',4283,false,true,NULL),
('IT','CRV',1358,false,true,NULL),
('IT','CUF',1359,true,true,'0:01 and 5:59'),
('IT','FLR',1361,true,true,'0:01 and 5:59'),
('IT','LMP',1367,true,true,'0:01 and 5:59'),
('IT','MXP',1369,false,true,NULL),
('IT','NAP',1371,true,true,'0:01 and 5:59'),
('IT','OLB',1372,false,true,NULL),
('IT','PEG',1376,false,true,NULL),
('IT','PMF',1375,false,true,NULL),
('IT','PMO',1373,false,true,NULL),
('IT','PNL',1374,false,true,NULL),
('IT','PSR',1377,false,true,NULL),
('IT','QSR',5008,false,false,NULL),
('IT','REG',1379,false,true,NULL),
('IT','RMI',1380,false,true,NULL),
('IT','SUF',1366,false,true,NULL),
('IT','TPS',1386,false,true,NULL),
('IT','TRN',1388,false,true,NULL),
('IT','TRS',1387,false,true,NULL),
('IT','TSF',1390,false,true,NULL),
('IT','VBS',1354,false,true,NULL),
('GB','BEB',1019,true,true,'0:01 and 5:59'),
('GB','BHD',1016,true,true,'0:01 and 5:59'),
('GB','BHX',1020,false,true,NULL),
('GB','BOH',1022,false,true,NULL),
('GB','CAL',1025,true,true,'0:01 and 5:59'),
('GB','DND',1029,false,true,NULL),
('GB','EXT',1032,true,true,'0:01 and 5:59'),
('GB','HUY',1041,false,true,NULL),
('GB','ILY',1043,false,true,NULL),
('GB','INV',1042,false,true,NULL),
('GB','KOI',1046,false,true,NULL),
('GB','LBA',1049,false,true,NULL),
('GB','LPL',1051,false,true,NULL),
('GB','LSI',1080,false,true,NULL),
('GB','LWK',1050,false,true,NULL),
('GB','MAN',1059,false,true,NULL),
('GB','MME',1082,false,true,NULL),
('GB','NQY',1062,false,true,NULL),
('GB','OBN',4226,false,true,NULL),
('GB','PIK',1038,false,true,NULL),
('GB','SEN',1076,false,true,NULL),
('GB','SOU',1075,false,true,NULL),
('GB','SYY',1078,false,true,NULL),
('GB','TRE',1083,false,true,NULL),
('GB','WIC',1086,false,true,NULL),
('DE','BRE',704,true,true,'0:01 and 5:59'),
('DE','CGN',724,false,true,NULL),
('DE','DRS',707,true,true,'0:01 and 5:59')
), verified AS (
SELECT n.world_id,n.airport_key,o.*
FROM observed o JOIN airlinerra_game.section5_airport_restriction_normalization_queue_v1 n ON n.world_id=1 AND n.country_iso=o.country_iso AND n.airport_code=o.code
JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 queue ON queue.world_id=n.world_id AND queue.airport_key=n.airport_key AND queue.batch_no=2
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 g
SET nighttime_ban=v.ban,noise_restrictions=v.noise,
 permitted_noise_chapters=CASE WHEN v.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=v.ban_window,
 source_status='AIRLINESIM_PAGE_OBSERVED',
 source_url='https://free1.airlinesim.aero/action/info/airport?id='||v.as_id::text,
 captured_on=DATE '2026-11-07',
 note='AirlineSim Free1 airport page checked in Section5 Batch2 on 2026-11-07; simplified game flag only, not certified operating rules.'
FROM verified v WHERE g.world_id=v.world_id AND g.airport_key=v.airport_key AND g.source_status='GAME_DEFAULT_NOT_CHECKED';
UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status='AIRLINESIM_PAGE_OBSERVED',reviewed_on=DATE '2026-11-07',review_source_url=g.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 g
WHERE q.world_id=1 AND q.world_id=g.world_id AND q.airport_key=g.airport_key AND q.batch_no=2 AND g.source_status='AIRLINESIM_PAGE_OBSERVED';
DO $verify$
DECLARE d integer;pending integer; total integer;
BEGIN
 SELECT count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),count(*) FILTER(WHERE review_status='PENDING')
 INTO d,pending FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=2;
 IF d<>50 OR pending<>0 THEN RAISE EXCEPTION 'Batch2 update failed % %',d,pending; END IF;
 SELECT count(*) INTO total FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1;
 IF total<>1216 THEN RAISE EXCEPTION 'Total batch queue %',total; END IF;
END $verify$;
COMMIT;