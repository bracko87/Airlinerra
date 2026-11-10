-- Group 2 Section 5: preserve unsourced operating restrictions, 23 fixed review batches.
-- No invented curfew/noise facts and no game or commercial admission.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section4_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION5_PREFLIGHT_FAILED'; END IF;
END $$;
CREATE VIEW airlinerra_game.airport_group2_section5_restrictions_review_v1
 WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,r.airport_key,
 r.game_nighttime_ban,r.game_noise_restrictions,
 r.game_restriction_basis,r.dispatch_restrictions_status,
 (r.game_nighttime_ban IS NOT NULL AND r.game_noise_restrictions IS NOT NULL
  AND r.game_restriction_basis<>'UNSOURCED_NO_OPERATIONAL_CLEARANCE'
  AND r.dispatch_restrictions_status<>'NOT_VERIFIED_FOR_DISPATCH') AS section5_restriction_source_ready,
 (r.game_nighttime_ban IS NULL OR r.game_noise_restrictions IS NULL) AS source_research_required,
 false AS independently_operationally_verified,
 false AS commercially_admitted,false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section5_restrictions_v1 r
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section5_restrictions_review_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section5_batch_review_status_v1
 WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER(WHERE section5_restriction_source_ready)::integer AS source_ready,
 count(*) FILTER(WHERE source_research_required)::integer AS unresolved_restrictions,
 count(*) FILTER(WHERE NOT live_flight_authorized)::integer AS dispatch_blocked,
 CASE WHEN bool_and(section5_restriction_source_ready) THEN 'review_ready_pending_operations_approval'
 ELSE 'source_research_required' END::text AS review_status,
 false AS game_data_complete,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section5_restrictions_review_v1
GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section5_batch_review_status_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section5_overall_status_v1
 WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(source_ready),0)::integer AS source_ready_airports,
 coalesce(sum(unresolved_restrictions),0)::integer AS source_research_required_airports,
 coalesce(sum(dispatch_blocked),0)::integer AS dispatch_blocked_airports,
 CASE WHEN count(*)=23 AND sum(airports)=1118 AND sum(source_ready)=1118
 THEN 'review_ready_pending_operations_approval'
 ELSE 'source_research_required' END::text AS section5_status,
 false AS game_data_complete,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section5_batch_review_status_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section5_overall_status_v1 FROM PUBLIC,anon,authenticated;
DO $$
BEGIN
 IF (SELECT batches FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>23
 OR (SELECT group2_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR (SELECT dispatch_blocked_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section5_batch_review_status_v1
  WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section5_restrictions_review_v1
  WHERE section5_restriction_source_ready OR commercially_admitted OR live_flight_authorized)
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
  WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION5_SAFE_REVIEW_ACCEPTANCE_FAILED';END IF;
END $$;