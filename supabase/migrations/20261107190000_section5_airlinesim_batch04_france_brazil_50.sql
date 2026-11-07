BEGIN;
-- Checked 40 airport detail pages, and 10 BR IATA codes confirmed absent from
-- five AirlineSim Brazilian regional directory listings. Neutral = GAME default only.
ALTER TABLE airlinerra_game.section5_airport_simplified_game_rules_v1
 DROP CONSTRAINT section5_airport_simplified_game_rules_v1_source_status_check;
ALTER TABLE airlinerra_game.section5_airport_simplified_game_rules_v1
 ADD CONSTRAINT section5_airport_simplified_game_rules_v1_source_status_check
 CHECK (source_status IN('GAME_DEFAULT_NOT_CHECKED','AIRLINESIM_PAGE_OBSERVED',
   'USER_AIRLINESIM_SCREENSHOT','AIRLINESIM_NOT_FOUND'));

DELETE FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1
 WHERE world_id=1 AND review_status='PENDING';
WITH prioritized(country_iso,airport_code,priority_pos) AS (
 VALUES ('BR','TJL',1),
('BR','TMT',2),
('BR','TOW',3),
('BR','UDI',4),
('BR','UNA',5),
('BR','URG',6),
('BR','VAL',7),
('BR','VDC',8),
('FR','AJA',9),
('FR','AUR',10),
('FR','AVN',11),
('FR','BIQ',12),
('FR','BVA',13),
('FR','BVE',14),
('FR','BZR',15),
('FR','CCF',16),
('FR','CFR',17),
('FR','CLY',18),
('FR','CMF',19),
('FR','DCM',20),
('FR','DLE',21),
('FR','DOL',22),
('FR','EGC',23),
('FR','ETZ',24),
('FR','FNI',25),
('FR','LIG',26),
('FR','LRH',27),
('FR','LYS',28),
('FR','MPL',29),
('FR','MRS',30),
('FR','NCE',31),
('FR','NCY',32),
('FR','PGF',33),
('FR','PIS',34),
('FR','RDZ',35),
('FR','RNS',36),
('FR','SXB',37),
('FR','TLN',38),
('FR','TUF',39),
('FR','XCR',40),
('BR','BVS',41),
('BR','CAU',42),
('BR','CEL',43),
('BR','CJZ',44),
('BR','GGJ',45),
('BR','JPE',46),
('BR','MNX',47),
('BR','OPP',48),
('BR','SMT',49),
('BR','TGQ',50)
), remaining AS(
 SELECT n.world_id,n.airport_key,n.airport_code,n.country_iso,
 (row_number() OVER(ORDER BY CASE WHEN pr.priority_pos IS NULL THEN 1 ELSE 0 END,
   pr.priority_pos NULLS LAST,n.country_iso,n.airport_code,n.airport_key)+150)::integer rn
 FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1 n
 JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 s USING(world_id,airport_key)
 LEFT JOIN prioritized pr ON pr.country_iso=n.country_iso AND pr.airport_code=n.airport_code
 WHERE n.world_id=1 AND n.normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING'
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED'
)
INSERT INTO airlinerra_game.section5_airlinesim_review_batch_queue_v1
(world_id,airport_key,airport_code,country_iso,batch_no,row_no)
SELECT world_id,airport_key,airport_code,country_iso,((rn-1)/50)+1,rn FROM remaining;
DO $check$ BEGIN
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1)<>1216
 THEN RAISE EXCEPTION 'Queue row count incorrect'; END IF;
 IF(SELECT count(*) FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1 WHERE world_id=1 AND batch_no=4)<>50
 THEN RAISE EXCEPTION 'Batch 4 selection incorrect'; END IF;
END $check$;

WITH data(country_iso,code,as_id,ban,noise,kind) AS (
VALUES ('BR','TJL',4458,false,false,'AIRLINESIM_PAGE_OBSERVED'),
('BR','TMT',487,false,false,'AIRLINESIM_PAGE_OBSERVED'),
('BR','TOW',486,false,false,'AIRLINESIM_PAGE_OBSERVED'),
('BR','UDI',490,false,false,'AIRLINESIM_PAGE_OBSERVED'),
('BR','UNA',491,false,false,'AIRLINESIM_PAGE_OBSERVED'),
('BR','URG',492,false,false,'AIRLINESIM_PAGE_OBSERVED'),
('BR','VAL',4459,false,false,'AIRLINESIM_PAGE_OBSERVED'),
('BR','VDC',496,false,false,'AIRLINESIM_PAGE_OBSERVED'),
('FR','AJA',832,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','AUR',836,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','AVN',837,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','BIQ',841,true,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','BVA',877,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','BVE',844,true,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','BZR',840,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','CCF',848,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','CFR',845,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','CLY',846,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','CMF',850,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','DCM',849,true,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','DLE',857,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','DOL',854,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','EGC',839,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','ETZ',872,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','FNI',875,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','LIG',867,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','LRH',861,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','LYS',870,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','MPL',873,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','MRS',871,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','NCE',876,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','NCY',835,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','PGF',883,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','PIS',884,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','RDZ',889,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','RNS',887,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','SXB',893,true,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','TLN',894,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','TUF',896,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('FR','XCR',898,false,true,'AIRLINESIM_PAGE_OBSERVED'),
('BR','BVS',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','CAU',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','CEL',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','CJZ',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','GGJ',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','JPE',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','MNX',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','OPP',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','SMT',NULL,false,false,'AIRLINESIM_NOT_FOUND'),
('BR','TGQ',NULL,false,false,'AIRLINESIM_NOT_FOUND')
), mapped AS(
 SELECT n.world_id,n.airport_key,d.*
 FROM data d JOIN airlinerra_game.section5_airport_restriction_normalization_queue_v1 n
   ON n.world_id=1 AND n.country_iso=d.country_iso AND n.airport_code=d.code
 JOIN airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
   ON q.world_id=n.world_id AND q.airport_key=n.airport_key AND q.batch_no=4
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
SET nighttime_ban=m.ban,noise_restrictions=m.noise,
permitted_noise_chapters=CASE WHEN m.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
simplified_nighttime_window=CASE WHEN m.ban THEN '0:01 and 5:59' ELSE NULL END,
source_status=m.kind,
source_url=CASE WHEN m.as_id IS NOT NULL
 THEN 'https://free1.airlinesim.aero/action/info/airport?id='||m.as_id::text
 ELSE 'https://free1.airlinesim.aero/action/info/country?id=24' END,
captured_on=DATE '2026-11-07',
note=CASE WHEN m.as_id IS NOT NULL THEN
 'AirlineSim public airport page individually checked in Section5 Batch4; simplified game yes/no, not real-world operating permission.'
 ELSE
 'IATA airport not found in any of the five Brazilian AirlineSim regional airport directories (North, Northeast, Center-West, Southeast, South). Owner-approved neutral game No/None. Real-world research remains separate.'
 END
FROM mapped m WHERE s.world_id=m.world_id AND s.airport_key=m.airport_key
 AND s.source_status='GAME_DEFAULT_NOT_CHECKED';

UPDATE airlinerra_game.section5_airlinesim_review_batch_queue_v1 q
SET review_status=CASE WHEN s.source_status='AIRLINESIM_NOT_FOUND' THEN 'AIRLINESIM_NOT_FOUND'
 ELSE 'AIRLINESIM_PAGE_OBSERVED' END,reviewed_on=DATE '2026-11-07',review_source_url=s.source_url
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
WHERE q.world_id=1 AND q.batch_no=4 AND s.world_id=q.world_id AND s.airport_key=q.airport_key
 AND s.source_status IN('AIRLINESIM_NOT_FOUND','AIRLINESIM_PAGE_OBSERVED');

-- Existing column order MUST be retained for PostgreSQL CREATE OR REPLACE VIEW.
CREATE OR REPLACE VIEW airlinerra_game.section5_airport_simplified_game_progress_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer total_airports,
count(*) FILTER (WHERE nighttime_ban)::integer game_yes_nighttime_ban,
count(*) FILTER (WHERE NOT nighttime_ban)::integer game_no_nighttime_ban,
count(*) FILTER (WHERE noise_restrictions)::integer game_yes_noise_restrictions,
count(*) FILTER (WHERE NOT noise_restrictions)::integer game_no_noise_restrictions,
count(*) FILTER (WHERE source_status='AIRLINESIM_PAGE_OBSERVED')::integer airline_sim_pages_checked,
count(*) FILTER (WHERE source_status='USER_AIRLINESIM_SCREENSHOT')::integer screenshots_checked,
count(*) FILTER (WHERE source_status='GAME_DEFAULT_NOT_CHECKED')::integer game_defaults_not_source_checked,
count(*) FILTER (WHERE source_status='AIRLINESIM_NOT_FOUND')::integer airline_sim_not_found
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 WHERE world_id=1;
REVOKE ALL ON airlinerra_game.section5_airport_simplified_game_progress_v1 FROM PUBLIC,anon,authenticated;

DO $verify$ DECLARE p integer;n integer;d integer;BEGIN
 SELECT count(*) FILTER(WHERE review_status='PENDING'),
 count(*) FILTER(WHERE review_status='AIRLINESIM_NOT_FOUND'),
 count(*) FILTER(WHERE review_status='AIRLINESIM_PAGE_OBSERVED')
 INTO p,n,d FROM airlinerra_game.section5_airlinesim_review_batch_queue_v1
 WHERE world_id=1 AND batch_no=4;
 IF p<>0 OR n<>10 OR d<>40
 THEN RAISE EXCEPTION 'Batch4 statuses invalid %,%,%',p,n,d; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1
 WHERE world_id=1 AND normalization_status='RESEARCH_ONLY_RULE_NORMALIZATION_PENDING')<>1246
 THEN RAISE EXCEPTION 'Official research rules were modified'; END IF;
END $verify$;
COMMIT;