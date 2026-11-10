-- Group 2 Batch 1: replace two provisional defaults with explicitly sourced AirlineSim GAME rules.
-- This does not certify real aviation regulations or authorize commercial dispatch.
DO $$
BEGIN
 IF (SELECT game_data_result FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT airline_sim_checked_airports FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_game_policy_v1
 WHERE airport_key IN ('OURAIRPORTS:5869','OURAIRPORTS:3366') AND batch_number=1
 AND rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT')<>2
 THEN RAISE EXCEPTION 'GROUP2_SECTION5_AIRLINESIM_SOURCE_PREFLIGHT_FAILED';END IF;
END $$;

UPDATE airlinerra_game.airport_group2_section5_game_policy_v1 SET
 game_nighttime_ban=true, game_noise_restrictions=false,
 rule_origin='AIRLINESIM_SOURCE_REVIEWED_GAME_RULE',
 airline_sim_checked=true,
 source_review_status='SOURCE_CHECKED_WITH_BOTH_FIELDS',
 source_url='https://kaitak.airlinesim.aero/app/info/airports/405?0=&tabs=0',
 source_observed_on=DATE '2026-11-10',
 nighttime_ban_hours='00:01-05:59 (AirlineSim game local time)',
 noise_chapter_rule='AirlineSim: no noise restrictions'
WHERE airport_key='OURAIRPORTS:5869';

UPDATE airlinerra_game.airport_group2_section5_game_policy_v1 SET
 game_nighttime_ban=false, game_noise_restrictions=false,
 rule_origin='AIRLINESIM_SOURCE_REVIEWED_GAME_RULE',
 airline_sim_checked=true,
 source_review_status='SOURCE_CHECKED_WITH_BOTH_FIELDS',
 source_url='https://tristar.airlinesim.aero/app/info/airports/4141?2=&tabs=0',
 source_observed_on=DATE '2026-11-10',
 nighttime_ban_hours=NULL,
 noise_chapter_rule='AirlineSim: no noise restrictions'
WHERE airport_key='OURAIRPORTS:3366';

UPDATE airlinerra_game.airport_group2_game_profiles_v1
SET game_nighttime_ban=true,game_noise_restrictions=false
WHERE airport_key='OURAIRPORTS:5869' AND game_nighttime_ban=false AND game_noise_restrictions=false;

-- Preserve the existing columns and order so downstream views remain valid.
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
    OR (rule_origin='AIRLINESIM_SOURCE_REVIEWED_GAME_RULE' AND airline_sim_checked
        AND source_review_status='SOURCE_CHECKED_WITH_BOTH_FIELDS'
        AND source_url IS NOT NULL)
  ) THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS real_world_verified,false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section5_game_policy_v1
GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section5_game_batch_completion_v1 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE VIEW airlinerra_game.airport_group2_section5_game_overall_status_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(neutral_assumption_airports),0)::integer AS neutral_assumption_airports,
 coalesce(sum(partial_source_review_airports),0)::integer AS partial_source_review_airports,
 coalesce(sum(no_source_review_airports),0)::integer AS no_source_review_airports,
 coalesce(sum(airline_sim_checked_airports),0)::integer AS airline_sim_checked_airports,
 CASE WHEN count(*)=23 AND sum(airports)=1118
  AND sum(neutral_assumption_airports)+sum(airline_sim_checked_airports)=1118
  AND bool_and(game_data_result='game_complete_estimated')
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS real_world_verified,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section5_game_batch_completion_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section5_game_overall_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT game_data_result FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT neutral_assumption_airports FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>1116
 OR (SELECT airline_sim_checked_airports FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>2
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE game_nighttime_ban=true)<>1
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION5_AIRLINESIM_SOURCE_POSTCHECK_FAILED'; END IF;
END $$;