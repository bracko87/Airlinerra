-- User policy: Local and Regional Group 2 airports use simple game defaults;
-- detailed Section 5 curfew/noise rule modelling is reserved for 26 Medium airports.
-- Historical AirlineSim evidence for SBBH and KAFW remains in earlier migrations.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE owner_category IN ('Local','Regional'))<>1092
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_game_policy_v1 p
   JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
   WHERE g.owner_category='Regional' AND p.rule_origin='AIRLINESIM_SOURCE_REVIEWED_GAME_RULE')<>2
 THEN RAISE EXCEPTION 'GROUP2_LOWER_CATEGORY_POLICY_PREFLIGHT_FAILED'; END IF;
END $$;

UPDATE airlinerra_game.airport_group2_section5_game_policy_v1 p
SET game_nighttime_ban=false,game_noise_restrictions=false,
 rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT',
 airline_sim_checked=false,
 source_review_status=CASE WHEN EXISTS (
   SELECT 1 FROM airlinerra_game.airport_group2_section5_source_findings_v1 f
   WHERE f.airport_key=p.airport_key
 ) THEN 'PARTIAL_PUBLIC_SOURCE_REVIEW' ELSE 'NO_REVIEW_RECORDED' END,
 source_url=NULL,source_observed_on=NULL,nighttime_ban_hours=NULL,noise_chapter_rule=NULL
FROM airlinerra_game.airport_group2_game_profiles_v1 g
WHERE g.airport_key=p.airport_key AND g.owner_category IN ('Local','Regional')
AND p.rule_origin<>'UNVERIFIED_NEUTRAL_GAME_DEFAULT';

UPDATE airlinerra_game.airport_group2_game_profiles_v1
SET game_nighttime_ban=false,game_noise_restrictions=false
WHERE owner_category IN ('Local','Regional')
AND (game_nighttime_ban OR game_noise_restrictions);

DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1 g
 JOIN airlinerra_game.airport_group2_section5_game_policy_v1 p USING(airport_key)
 WHERE g.owner_category IN ('Local','Regional')
 AND (p.rule_origin<>'UNVERIFIED_NEUTRAL_GAME_DEFAULT'
   OR p.game_nighttime_ban OR p.game_noise_restrictions
   OR g.game_nighttime_ban OR g.game_noise_restrictions))<>0
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_medium_screen_v1)<>26
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_medium_screen_v1
 WHERE game_nighttime_ban OR game_noise_restrictions)<>2
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>'game_complete_estimated'
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'GROUP2_LOWER_CATEGORY_POLICY_POSTCHECK_FAILED';END IF;
END $$;