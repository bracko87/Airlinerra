
BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.section5_airlinesim_review_batch_queue_v1(
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL,
 airport_code text NOT NULL,
 country_iso text NOT NULL,
 batch_no integer NOT NULL CHECK(batch_no BETWEEN 1 AND 25),
 row_no integer NOT NULL CHECK(row_no BETWEEN 1 AND 1216),
 review_status text NOT NULL DEFAULT 'PENDING' CHECK(review_status IN('PENDING','AIRLINESIM_PAGE_OBSERVED','AIRLINESIM_NOT_FOUND')),
 review_source_url text,
 reviewed_on date,
 PRIMARY KEY(world_id,airport_key),
 UNIQUE(world_id,row_no),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.airport_reference_profiles(world_id,airport_key)
);
ALTER TABLE airlinerra_game.section5_airlinesim_review_batch_queue_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section5_airlinesim_review_batch_queue_v1 FROM PUBLIC,anon,authenticated;
WITH preferred(country_iso,airport_code,first_batch_position) AS (
 VALUES
 ('ES','AGP',1),
 ('ES','BJZ',2),
 ('ES','CDT',3),
 ('ES','EAS',4),
 ('ES','GRX',5),
 ('ES','ILD',6),
 ('ES','LCG',7),
 ('ES','LEI',8),
 ('ES','LEN',9),
 ('ES','LEU',10),
 ('ES','MAD',11),
 ('ES','ODB',12),
 ('ES','OVD',13),
 ('ES','REU',14),
 ('ES','RJL',15),
 ('ES','RMU',16),
 ('ES','SDR',17),
 ('ES','SLM',18),
 ('ES','VGO',19),
 ('ES','VLL',20),
 ('ES','XRY',21),
 ('ES','ZAZ',22),
 ('NO','ALF',23),
 ('NO','ANX',24),
 ('NO','BDU',25),
 ('NO','EVE',26),
 ('NO','FRO',27),
 ('NO','HAU',28),
 ('NO','KKN',29),
 ('NO','KRS',30),
 ('NO','KSU',31),
 ('NO','LKL',32),
 ('NO','MOL',33),
 ('NO','OLA',34),
 ('NO','OSL',35),
 ('NO','RRS',36),
 ('NO','SSJ',37),
 ('NO','TOS',38),
 ('NO','TRD',39),
 ('NO','TRF',40),
 ('DK','AAL',41),
 ('DK','BLL',42),
 ('DK','CPH',43),
 ('DK','EBJ',44),
 ('DK','ODE',45),
 ('DK','RNN',46),
 ('DK','SGD',47),
 ('IT','BGY',48),
 ('IT','BLQ',49),
 ('IT','CIA',50)
), remaining AS (
 SELECT n.world_id,n.airport_key,n.airport_code,n.country_iso, preferred.first_batch_position,
 row_number() OVER(ORDER BY CASE WHEN preferred.first_batch_position IS NULL THEN 1 ELSE 0 END,
   preferred.first_batch_position NULLS LAST,n.country_iso,n.airport_code,n.airport_key)::integer AS rn
 FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1 n
 JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
 LEFT JOIN preferred ON preferred.airport_code=n.airport_code AND preferred.country_iso=n.country_iso
 WHERE n.world_id=1 AND n.normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING'
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED'
)
INSERT INTO airlinerra_game.section5_airlinesim_review_batch_queue_v1
 (world_id,airport_key,airport_code,country_iso,batch_no,row_no)
SELECT world_id,airport_key,airport_code,country_iso,((rn-1)/50)+1,rn FROM remaining
ON CONFLICT(world_id,airport_key) DO NOTHING;
DO $assert$ BEGIN
IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
THEN RAISE EXCEPTION 'Expected exact 1216 review queue airports'; END IF;
IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=1)<>50
THEN RAISE EXCEPTION 'Batch1 must have 50 airports'; END IF;
END $assert$;
WITH observed(country_iso,code,as_id,ban,noise,ban_window) AS (
VALUES
('ES','AGP',2807,false,true,NULL),
('ES','BJZ',2796,false,true,NULL),
('ES','CDT',4644,false,false,NULL),
('ES','EAS',2814,false,true,NULL),
('ES','GRX',2800,false,true,NULL),
('ES','ILD',4170,true,true,'0:01 and 5:59'),
('ES','LCG',2803,false,true,NULL),
('ES','LEI',2794,false,true,NULL),
('ES','LEN',2804,false,true,NULL),
('ES','LEU',4805,false,false,NULL),
('ES','MAD',2806,false,true,NULL),
('ES','ODB',5012,true,false,'0:01 and 5:59'),
('ES','OVD',2795,false,true,NULL),
('ES','REU',2812,false,true,NULL),
('ES','RJL',2805,false,true,NULL),
('ES','RMU',2809,false,true,NULL),
('ES','SDR',2815,false,true,NULL),
('ES','SLM',2813,false,true,NULL),
('ES','VGO',2820,false,true,NULL),
('ES','VLL',2819,false,true,NULL),
('ES','XRY',2802,false,true,NULL),
('ES','ZAZ',2822,false,true,NULL),
('NO','ALF',2273,true,false,'0:01 and 5:59'),
('NO','ANX',2274,true,false,'0:01 and 5:59'),
('NO','BDU',2275,true,false,'0:01 and 5:59'),
('NO','EVE',2286,true,false,'0:01 and 5:59'),
('NO','FRO',2282,true,false,'0:01 and 5:59'),
('NO','HAU',2288,true,false,'0:01 and 5:59'),
('NO','KKN',2290,true,false,'0:01 and 5:59'),
('NO','KRS',2291,true,false,'0:01 and 5:59'),
('NO','KSU',2292,true,false,'0:01 and 5:59'),
('NO','LKL',2293,true,false,'0:01 and 5:59'),
('NO','MOL',2298,true,false,'0:01 and 5:59'),
('NO','OLA',2302,false,false,NULL),
('NO','OSL',2304,false,false,NULL),
('NO','RRS',2307,true,false,'0:01 and 5:59'),
('NO','SSJ',2310,true,false,'0:01 and 5:59'),
('NO','TOS',2318,true,false,'0:01 and 5:59'),
('NO','TRD',2319,true,false,'0:01 and 5:59'),
('NO','TRF',2305,true,false,'0:01 and 5:59'),
('DK','AAL',664,false,true,NULL),
('DK','BLL',666,false,true,NULL),
('DK','CPH',670,false,true,NULL),
('DK','EBJ',668,false,true,NULL),
('DK','ODE',3879,true,true,'0:01 and 5:59'),
('DK','RNN',667,false,true,NULL),
('DK','SGD',672,false,true,NULL),
('IT','BGY',1370,false,true,NULL),
('IT','BLQ',1352,false,true,NULL),
('IT','CIA',1381,false,true,NULL)
), verified AS (
SELECT n.world_id,n.airport_key,o.*
FROM observed o JOIN airlinerra_game.section5_airport_restriction_normalization_queue_v1 n
 ON n.world_id=1 AND n.country_iso=o.country_iso AND n.airport_code=o.code
JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 queue
 ON queue.world_id=n.world_id AND queue.airport_key=n.airport_key AND queue.batch_no=1
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 g
SET nighttime_ban=v.ban, noise_restrictions=v.noise,
 permitted_noise_chapters=CASE WHEN v.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=v.ban_window,
 source_status='AIRLINESIM_PAGE_OBSERVED',
 source_url='https://free1.airlinesim.aero/action/info/airport?id='||v.as_id::text,
 captured_on=DATE '2026-11-07',
 note='AirlineSim Free1 public airport page checked in Section5 Batch1 on 2026-11-07; two simple game flags (No/Yes) and permitted noise Chapters; this does not assert real-world legal clearance.'
FROM verified v WHERE g.world_id=v.world_id AND g.airport_key=v.airport_key
 AND g.source_status='GAME_DEFAULT_NOT_CHECKED';

UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status='AIRLINESIM_PAGE_OBSERVED',
 reviewed_on=DATE '2026-11-07',
 review_source_url=g.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 g
WHERE q.world_id=1 AND q.world_id=g.world_id AND q.airport_key=g.airport_key
 AND q.batch_no=1 AND g.source_status='AIRLINESIM_PAGE_OBSERVED';

DO $verify$
DECLARE done integer; pending integer;
BEGIN
SELECT count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED'),
       count(*) FILTER(WHERE review_status='PENDING')
INTO done,pending
FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=1;
IF done<>50 OR pending<>0 THEN
 RAISE EXCEPTION 'Batch 1 incomplete checked %, pending %',done,pending; END IF;
IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Historical researched restrictions were modified'; END IF;
END $verify$;
COMMIT;