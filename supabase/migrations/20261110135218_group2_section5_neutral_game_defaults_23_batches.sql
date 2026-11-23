-- Group 2 Section 5: user-approved neutral GAME defaults by the 23 fixed 50-airport batches.
-- No airport rule below is a sourced claim. No real-world or flight authorization is granted.
-- Verified information may replace these defaults only in a separate source-evidenced revision.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT count(DISTINCT batch_number) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>23
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
     WHERE game_nighttime_ban IS NULL AND game_noise_restrictions IS NULL
     AND game_restriction_basis='UNSOURCED_NO_OPERATIONAL_CLEARANCE')<>1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION5_NEUTRAL_DEFAULT_PREFLIGHT_FAILED'; END IF;
END $$;

CREATE TABLE airlinerra_game.airport_group2_section5_game_policy_v1(
 airport_key text PRIMARY KEY REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 batch_number smallint NOT NULL CHECK(batch_number BETWEEN 1 AND 23),
 game_nighttime_ban boolean NOT NULL,
 game_noise_restrictions boolean NOT NULL,
 rule_origin text NOT NULL CHECK(rule_origin IN (
   'UNVERIFIED_NEUTRAL_GAME_DEFAULT',
   'AIRLINESIM_SOURCE_REVIEWED_GAME_RULE',
   'OFFICIAL_SOURCE_REVIEWED_GAME_RULE')),
 airline_sim_checked boolean NOT NULL DEFAULT false,
 source_review_status text NOT NULL CHECK(source_review_status IN
 ('NO_REVIEW_RECORDED','PARTIAL_PUBLIC_SOURCE_REVIEW','SOURCE_CHECKED_WITH_BOTH_FIELDS')),
 source_url text,
 source_observed_on date,
 nighttime_ban_hours text,
 noise_chapter_rule text,
 real_world_verified boolean NOT NULL DEFAULT false CHECK(NOT real_world_verified),
 dispatch_authorized boolean NOT NULL DEFAULT false CHECK(NOT dispatch_authorized),
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10',
 CHECK ((rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT'
   AND NOT game_nighttime_ban AND NOT game_noise_restrictions
   AND source_url IS NULL AND nighttime_ban_hours IS NULL AND noise_chapter_rule IS NULL
   AND NOT airline_sim_checked AND NOT real_world_verified)
  OR (rule_origin<>'UNVERIFIED_NEUTRAL_GAME_DEFAULT' AND source_url IS NOT NULL))
);
ALTER TABLE airlinerra_game.airport_group2_section5_game_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section5_game_policy_v1 FROM PUBLIC,anon,authenticated;

INSERT INTO airlinerra_game.airport_group2_section5_game_policy_v1
(airport_key,batch_number,game_nighttime_ban,game_noise_restrictions,
 rule_origin,airline_sim_checked,source_review_status)
SELECT b.airport_key,b.batch_number,false,false,
 'UNVERIFIED_NEUTRAL_GAME_DEFAULT',false,
 CASE WHEN EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section5_source_findings_v1 s
 WHERE s.airport_key=b.airport_key) THEN 'PARTIAL_PUBLIC_SOURCE_REVIEW'
 ELSE 'NO_REVIEW_RECORDED' END
FROM airlinerra_game.airport_group2_fixed_batch_members_v1 b;

-- Only fill previously NULL game flags. Preserve restrictions basis fixed by
-- the existing schema as UNSOURCED_NO_OPERATIONAL_CLEARANCE.
UPDATE airlinerra_game.airport_group2_game_profiles_v1 p
SET game_nighttime_ban=false,game_noise_restrictions=false
FROM airlinerra_game.airport_group2_section5_game_policy_v1 policy
WHERE p.airport_key=policy.airport_key
AND p.game_nighttime_ban IS NULL AND p.game_noise_restrictions IS NULL;

-- Keep the separate real-world source queue open after setting GAME defaults.
CREATE OR REPLACE VIEW airlinerra_game.airport_group2_section5_restrictions_review_v1
WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,r.airport_key,
 r.game_nighttime_ban,r.game_noise_restrictions,r.game_restriction_basis,
 r.dispatch_restrictions_status,
 (r.game_nighttime_ban IS NOT NULL AND r.game_noise_restrictions IS NOT NULL
  AND r.game_restriction_basis<>'UNSOURCED_NO_OPERATIONAL_CLEARANCE'
  AND r.dispatch_restrictions_status<>'NOT_VERIFIED_FOR_DISPATCH') AS section5_restriction_source_ready,
 (r.game_nighttime_ban IS NULL OR r.game_noise_restrictions IS NULL
  OR r.game_restriction_basis='UNSOURCED_NO_OPERATIONAL_CLEARANCE'
  OR r.dispatch_restrictions_status='NOT_VERIFIED_FOR_DISPATCH') AS source_research_required,
 false AS independently_operationally_verified,
 false AS commercially_admitted,false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section5_restrictions_v1 r
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section5_restrictions_review_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section5_game_batch_completion_v1
WITH (security_invoker=true) AS
SELECT batch_number, count(*)::integer airports,
 count(*) FILTER(WHERE game_nighttime_ban=false AND game_noise_restrictions=false
 AND rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT')::integer AS neutral_assumption_airports,
 count(*) FILTER(WHERE source_review_status='PARTIAL_PUBLIC_SOURCE_REVIEW')::integer AS partial_source_review_airports,
 count(*) FILTER(WHERE source_review_status='NO_REVIEW_RECORDED')::integer AS no_source_review_airports,
 count(*) FILTER(WHERE airline_sim_checked)::integer AS airline_sim_checked_airports,
 CASE WHEN bool_and(NOT game_nighttime_ban AND NOT game_noise_restrictions
   AND rule_origin='UNVERIFIED_NEUTRAL_GAME_DEFAULT')
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS real_world_verified,false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section5_game_policy_v1
GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section5_game_batch_completion_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section5_game_overall_status_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(neutral_assumption_airports),0)::integer AS neutral_assumption_airports,
 coalesce(sum(partial_source_review_airports),0)::integer AS partial_source_review_airports,
 coalesce(sum(no_source_review_airports),0)::integer AS no_source_review_airports,
 coalesce(sum(airline_sim_checked_airports),0)::integer AS airline_sim_checked_airports,
 CASE WHEN count(*)=23 AND sum(airports)=1118 AND sum(neutral_assumption_airports)=1118
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS real_world_verified,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section5_game_batch_completion_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section5_game_overall_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT group2_airports FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>1118
 OR (SELECT batches FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>23
 OR (SELECT neutral_assumption_airports FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>1118
 OR (SELECT partial_source_review_airports FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>5
 OR (SELECT no_source_review_airports FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>1113
 OR (SELECT airline_sim_checked_airports FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>0
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR (SELECT airports_still_unresolved FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>1118
 OR EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_section5_game_batch_completion_v1
   WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))
 OR EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION5_NEUTRAL_DEFAULT_POSTCHECK_FAILED'; END IF;
END $$;