-- Group 2 Section 5: targeted research for the 26 Medium game-category airports.
-- Preserve simple Local and Regional game defaults. Airport restrictions are GAME settings,
-- not regulatory certification or a substitute for current NOTAM/AIP dispatch checks.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE owner_category='Medium')<>26
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_game_policy_v1 p
     JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING (airport_key)
     WHERE g.owner_category='Medium' AND p.rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT')<>26
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'GROUP2_MEDIUM_RESTRICTIONS_PREFLIGHT_FAILED'; END IF;
END $$;

-- Exact ICAO matches, using the AirlineSim airport information pages.
WITH observed(airport_key,source_url,night_ban,noise_ban,hours,chapter_rule) AS (
 VALUES
 ('OURAIRPORTS:46583','https://free1.airlinesim.aero/app/info/airports/3872?0=&tabs=0',false,true,NULL::text,'AirlineSim: only ICAO Chapter III and IV aircraft permitted'),
 ('OURAIRPORTS:5780','https://ellinikon.airlinesim.aero/app/info/airports/99?3=&tabs=0',false,false,NULL::text,'AirlineSim: no noise restrictions'),
 ('OURAIRPORTS:6467','https://kaitak.airlinesim.aero/app/info/airports/3034?0=&tabs=0',false,false,NULL::text,'AirlineSim: no noise restrictions; does NOT override Ukrainian civil-airspace closure'),
 ('OURAIRPORTS:6474','https://junkers.airlinesim.aero/app/info/airports/3043?0=&tabs=0',false,false,NULL::text,'AirlineSim: no noise restrictions; does NOT override Ukrainian civil-airspace closure'),
 ('OURAIRPORTS:4512','https://yeouido.airlinesim.aero/app/info/airports/2984?2=&tabs=0',false,false,NULL::text,'AirlineSim: no noise restrictions')
)
UPDATE airlinerra_game.airport_group2_section5_game_policy_v1 p
SET game_nighttime_ban=o.night_ban,game_noise_restrictions=o.noise_ban,
 rule_origin='AIRLINESIM_SOURCE_REVIEWED_GAME_RULE',
 airline_sim_checked=true,source_review_status='SOURCE_CHECKED_WITH_BOTH_FIELDS',
 source_url=o.source_url,source_observed_on=DATE '2026-11-10',
 nighttime_ban_hours=o.hours,noise_chapter_rule=o.chapter_rule
FROM observed o
WHERE p.airport_key=o.airport_key;

-- Official French AIP and law: jet departure prohibition 22:15-06:00,
-- plus additional aircraft-type-specific arrival and noise restrictions.
UPDATE airlinerra_game.airport_group2_section5_game_policy_v1
SET game_nighttime_ban=true,game_noise_restrictions=true,
 rule_origin='OFFICIAL_SOURCE_REVIEWED_GAME_RULE',airline_sim_checked=false,
 source_review_status='SOURCE_CHECKED_WITH_BOTH_FIELDS',
 source_url='https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_29_OCT_2026/FRANCE/AIRAC-2026-10-29/html/eAIP/FR-AD-2.LFPB-fr-FR.html',
 source_observed_on=DATE '2026-11-10',
 nighttime_ban_hours='Jet departures: no leaving parking stand 22:15-06:00 local; additional aircraft-type arrival/prop restrictions 23:15/23:30-06:00/06:15. Exceptions apply.',
 noise_chapter_rule='Official French law: conditional aircraft noise restrictions using ICAO Annex 16 Chapters 3, 4, 14 and aircraft weight/type; see AIP AD 2.21 and 2011 order.'
WHERE airport_key='OURAIRPORTS:4183';

-- Bankstown operates H24 with noise-abatement procedures, not a
-- confirmed blanket airport curfew or Chapter-based aircraft prohibition.
UPDATE airlinerra_game.airport_group2_section5_game_policy_v1
SET game_nighttime_ban=false,game_noise_restrictions=false,
 rule_origin='OFFICIAL_SOURCE_REVIEWED_GAME_RULE',airline_sim_checked=false,
 source_review_status='PARTIAL_PUBLIC_SOURCE_REVIEW',
 source_url='https://aircraftnoise.airservicesaustralia.com/2020/04/30/bankstown-airport-flight-paths/',
 source_observed_on=DATE '2026-11-10',
 nighttime_ban_hours=NULL,
 noise_chapter_rule='Airservices Australia says Bankstown operates 24 hours with noise-abatement procedures. No specific ICAO Chapter ban confirmed in checked source.'
WHERE airport_key='OURAIRPORTS:27130';

-- Mirror booleans into existing Group 2 game profiles. Do not alter the
-- invariant UNSOURCED_NO_OPERATIONAL_CLEARANCE / commercial flags.
UPDATE airlinerra_game.airport_group2_game_profiles_v1 g
SET game_nighttime_ban=p.game_nighttime_ban,
 game_noise_restrictions=p.game_noise_restrictions
FROM airlinerra_game.airport_group2_section5_game_policy_v1 p
WHERE g.airport_key=p.airport_key
AND g.owner_category='Medium'
AND (g.game_nighttime_ban IS DISTINCT FROM p.game_nighttime_ban
  OR g.game_noise_restrictions IS DISTINCT FROM p.game_noise_restrictions);

-- Preserve column signatures for existing dependent overall view.
CREATE OR REPLACE VIEW airlinerra_game.airport_group2_section5_game_batch_completion_v1
WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER(WHERE rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT'
  AND NOT game_nighttime_ban AND NOT game_noise_restrictions)::integer AS neutral_assumption_airports,
 count(*) FILTER(WHERE source_review_status='PARTIAL_PUBLIC_SOURCE_REVIEW')::integer AS partial_source_review_airports,
 count(*) FILTER(WHERE source_review_status='NO_REVIEW_RECORDED')::integer AS no_source_review_airports,
 count(*) FILTER(WHERE airline_sim_checked)::integer AS airline_sim_checked_airports,
 CASE WHEN bool_and(
   (rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT' AND NOT game_nighttime_ban AND NOT game_noise_restrictions)
   OR (rule_origin IN ('AIRLINESIM_SOURCE_REVIEWED_GAME_RULE','OFFICIAL_SOURCE_REVIEWED_GAME_RULE')
     AND source_url IS NOT NULL AND source_observed_on IS NOT NULL)
 ) THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS real_world_verified,false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section5_game_policy_v1
GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section5_game_batch_completion_v1 FROM PUBLIC,anon,authenticated;

-- Update overall summary for the seven official/game sourced medium rules.
CREATE OR REPLACE VIEW airlinerra_game.airport_group2_section5_game_overall_status_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(neutral_assumption_airports),0)::integer AS neutral_assumption_airports,
 coalesce(sum(partial_source_review_airports),0)::integer AS partial_source_review_airports,
 coalesce(sum(no_source_review_airports),0)::integer AS no_source_review_airports,
 coalesce(sum(airline_sim_checked_airports),0)::integer AS airline_sim_checked_airports,
 CASE WHEN count(*)=23 AND sum(airports)=1118
 AND bool_and(game_data_result='game_complete_estimated')
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS real_world_verified,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section5_game_batch_completion_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section5_game_overall_status_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section5_medium_screen_v1
WITH (security_invoker=true) AS
SELECT b.batch_number,g.airport_key,g.game_airport_name,g.source_gps_code,
 p.game_nighttime_ban,p.game_noise_restrictions,p.rule_origin,p.source_review_status,
 p.source_url,p.nighttime_ban_hours,p.noise_chapter_rule,
 false AS independently_legally_verified,false AS dispatch_authorized
FROM airlinerra_game.airport_group2_game_profiles_v1 g
JOIN airlinerra_game.airport_group2_section5_game_policy_v1 p USING(airport_key)
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key)
WHERE g.owner_category='Medium';
REVOKE ALL ON airlinerra_game.airport_group2_section5_medium_screen_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section5_medium_screen_v1)<>26
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_medium_screen_v1
  WHERE rule_origin='AIRLINESIM_SOURCE_REVIEWED_GAME_RULE')<>5
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_medium_screen_v1
  WHERE rule_origin='OFFICIAL_SOURCE_REVIEWED_GAME_RULE')<>2
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_medium_screen_v1
  WHERE rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT')<>19
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_medium_screen_v1
  WHERE game_nighttime_ban OR game_noise_restrictions)<>2
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>'game_complete_estimated'
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_MEDIUM_RESTRICTIONS_POSTCHECK_FAILED'; END IF;
END $$;