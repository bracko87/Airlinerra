-- Section 5: owner-approved simplified AirlineSim-style GAME airport flags.
-- Source-provenance is REQUIRED: an unvisited page is a game default, never evidence of no ban.
-- Never overwrite documented mandatory airport time/runway/noise restrictions.
BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.section5_airport_simplified_game_rules_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK (world_id=1),
 airport_key text NOT NULL,
 nighttime_ban boolean NOT NULL DEFAULT false,
 noise_restrictions boolean NOT NULL DEFAULT false,
 permitted_noise_chapters smallint[] NOT NULL DEFAULT '{}'::smallint[],
 simplified_nighttime_window text,
 source_status text NOT NULL DEFAULT 'GAME_DEFAULT_NOT_CHECKED'
  CHECK (source_status IN ('GAME_DEFAULT_NOT_CHECKED','AIRLINESIM_PAGE_OBSERVED','USER_AIRLINESIM_SCREENSHOT')),
 source_url text,
 captured_on date,
 game_model_version text NOT NULL DEFAULT 'airlinerra_section5_simplified_night_noise_20261107',
 note text NOT NULL DEFAULT 'Provisional game No/None value where no AirlineSim value has yet been checked. Do not interpret as real airport absence of restrictions.',
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.airport_reference_profiles(world_id,airport_key),
 CHECK ((NOT noise_restrictions AND cardinality(permitted_noise_chapters)=0)
   OR (noise_restrictions AND cardinality(permitted_noise_chapters)>0)),
 CHECK (permitted_noise_chapters <@ ARRAY[1,2,3,4,5,14]::smallint[]),
 CHECK (source_status='GAME_DEFAULT_NOT_CHECKED' OR captured_on IS NOT NULL),
 CHECK (source_status='GAME_DEFAULT_NOT_CHECKED' OR source_url IS NOT NULL OR source_status='USER_AIRLINESIM_SCREENSHOT')
);
ALTER TABLE airlinerra_game.section5_airport_simplified_game_rules_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section5_airport_simplified_game_rules_v1 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.section5_airport_simplified_game_rules_v1(world_id,airport_key)
SELECT world_id,airport_key FROM airlinerra_game.airport_reference_profiles WHERE world_id=1
ON CONFLICT (world_id,airport_key) DO NOTHING;

-- Source pages checked 2026-11-07: Swedish entries individually read from AirlineSim,
-- plus two supplied AirlineSim screenshots (BCN/BUD). "Restricted to Chapter III and IV"
-- is an AirlineSim *allowed chapter list*, NOT a real-world legal certificate.
WITH observed(code,airlinesim_id,ban,noise,ban_window) AS (
 VALUES
 ('AGH',2716,false,true,NULL),
 ('AJR',2717,false,true,NULL),
 ('ARN',2745,false,true,NULL),
 ('EVG',2750,false,true,NULL),
 ('HAD',2723,false,true,NULL),
 ('HFS',2722,false,true,NULL),
 ('HMV',2724,false,true,NULL),
 ('JKG',2726,false,true,NULL),
 ('KLR',2727,false,true,NULL),
 ('KRN',2729,true,true,'00:01-05:59'),
 ('KSD',2728,false,true,NULL),
 ('LLA',2733,false,true,NULL),
 ('LPI',2732,false,true,NULL),
 ('NRK',2737,false,true,NULL),
 ('OER',2739,false,true,NULL),
 ('ORB',2738,false,true,NULL),
 ('OSD',2741,false,true,NULL),
 ('PJA',2742,false,true,NULL),
 ('SCR',4784,false,false,NULL),
 ('SDL',2749,false,true,NULL),
 ('SFT',2744,false,true,NULL),
 ('THN',2752,false,true,NULL),
 ('TYF',2751,false,true,NULL),
 ('UME',2753,false,true,NULL),
 ('VBY',2757,false,true,NULL),
 ('VHM',2756,false,true,NULL),
 ('VST',2754,false,true,NULL),
 ('VXO',2755,false,true,NULL)
), selected AS (
 SELECT p.world_id,p.airport_key, o.code,o.airlinesim_id,o.ban,o.noise,o.ban_window
 FROM observed o JOIN airlinerra_game.airport_reference_profiles p
   ON p.world_id=1 AND p.country_iso='SE' AND p.game_display_code=o.code
)
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
SET nighttime_ban=selected.ban,
 noise_restrictions=selected.noise,
 permitted_noise_chapters=CASE WHEN selected.noise THEN ARRAY[3,4]::smallint[] ELSE '{}'::smallint[] END,
 simplified_nighttime_window=selected.ban_window,
 source_status='AIRLINESIM_PAGE_OBSERVED',
 source_url='https://free1.airlinesim.aero/app/info/airports/'||selected.airlinesim_id::text,
 captured_on=DATE '2026-11-07',
 note='AirlineSim Free1 public airport Information page observed on 2026-11-07; its simplified game flags are not authoritative aviation operating permission.'
FROM selected WHERE s.world_id=selected.world_id AND s.airport_key=selected.airport_key;

UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1 s
SET nighttime_ban=CASE p.game_display_code WHEN 'BUD' THEN true ELSE false END,
 noise_restrictions=true,permitted_noise_chapters=ARRAY[3,4]::smallint[],
 simplified_nighttime_window=CASE p.game_display_code WHEN 'BUD' THEN '01:01-05:59' ELSE NULL END,
 source_status='USER_AIRLINESIM_SCREENSHOT',
 source_url=CASE p.game_display_code WHEN 'BCN' THEN 'https://free1.airlinesim.aero/action/info/airport?id=2797' ELSE NULL END,
 captured_on=DATE '2026-11-07',
 note='User-provided 2026-11-07 AirlineSim airport screenshot; source label only, not official local curfew or noise regulation.'
FROM airlinerra_game.airport_reference_profiles p
WHERE p.world_id=1 AND s.world_id=p.world_id AND s.airport_key=p.airport_key
  AND p.game_display_code IN ('BCN','BUD');

CREATE OR REPLACE VIEW airlinerra_game.section5_airport_simplified_game_progress_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer total_airports,
 count(*) FILTER (WHERE s.nighttime_ban)::integer game_yes_nighttime_ban,
 count(*) FILTER (WHERE NOT s.nighttime_ban)::integer game_no_nighttime_ban,
 count(*) FILTER (WHERE s.noise_restrictions)::integer game_yes_noise_restrictions,
 count(*) FILTER (WHERE NOT s.noise_restrictions)::integer game_no_noise_restrictions,
 count(*) FILTER (WHERE source_status='AIRLINESIM_PAGE_OBSERVED')::integer airline_sim_pages_checked,
 count(*) FILTER (WHERE source_status='USER_AIRLINESIM_SCREENSHOT')::integer screenshots_checked,
 count(*) FILTER (WHERE source_status='GAME_DEFAULT_NOT_CHECKED')::integer game_defaults_not_source_checked
FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s WHERE s.world_id=1;
REVOKE ALL ON airlinerra_game.section5_airport_simplified_game_progress_v1 FROM PUBLIC,anon,authenticated;

DO $assert$
DECLARE verified integer; checked_se integer; all_rows integer; remaining integer;
BEGIN
 SELECT total_airports,airline_sim_pages_checked,game_defaults_not_source_checked
 INTO all_rows,checked_se,remaining FROM airlinerra_game.section5_airport_simplified_game_progress_v1;
 IF all_rows<>3141 OR checked_se<>28 OR remaining<>3111
 THEN RAISE EXCEPTION 'Section 5 binary game source coverage mismatch: %,%,%',all_rows,checked_se,remaining; END IF;
 SELECT count(*) INTO verified
 FROM airlinerra_game.section5_airport_simplified_game_rules_v1 s
 JOIN airlinerra_game.airport_reference_profiles p USING(world_id,airport_key)
 WHERE s.world_id=1 AND ((p.game_display_code='KRN' AND s.nighttime_ban AND s.permitted_noise_chapters=ARRAY[3,4]::smallint[])
 OR (p.game_display_code='SCR' AND NOT s.noise_restrictions)
 OR (p.game_display_code='BUD' AND s.nighttime_ban AND s.source_status='USER_AIRLINESIM_SCREENSHOT')
 OR (p.game_display_code='BCN' AND NOT s.nighttime_ban AND s.noise_restrictions)
 OR (p.game_display_code='ARN' AND NOT s.nighttime_ban AND s.noise_restrictions));
 IF verified<>5 THEN RAISE EXCEPTION 'Verified sample values failed'; END IF;
END $assert$;
COMMIT;