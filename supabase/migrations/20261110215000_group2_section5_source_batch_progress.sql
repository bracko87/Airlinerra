-- Group 2 Section 5: evidence progress by fixed 23 batches, not a dispatch approval.
CREATE VIEW airlinerra_game.airport_group2_section5_source_batch_progress_v1
WITH (security_invoker=true) AS
SELECT b.batch_number,COUNT(*)::integer AS airports,
 COUNT(*) FILTER(WHERE f.airport_key IS NOT NULL)::integer AS airports_with_source_review,
 COUNT(*) FILTER(WHERE f.airport_key IS NULL)::integer AS airports_without_source_review,
 COALESCE(SUM(COALESCE(f.source_finding_count,0)),0)::integer AS source_findings,
 COUNT(*) FILTER(WHERE r.game_nighttime_ban IS NOT NULL AND r.game_noise_restrictions IS NOT NULL
   AND r.dispatch_restrictions_status<>'NOT_VERIFIED_FOR_DISPATCH')::integer AS fully_sourced_restrictions,
 COUNT(*) FILTER(WHERE r.game_nighttime_ban IS NULL OR r.game_noise_restrictions IS NULL)::integer AS incomplete_restrictions,
 false AS operationally_cleared
FROM airlinerra_game.airport_group2_fixed_batch_members_v1 b
JOIN airlinerra_game.airport_group2_section5_restrictions_v1 r USING(airport_key)
LEFT JOIN (
  SELECT airport_key,COUNT(*)::integer AS source_finding_count
  FROM airlinerra_game.airport_group2_section5_source_findings_v1 GROUP BY airport_key
) f USING(airport_key)
GROUP BY b.batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section5_source_batch_progress_v1 FROM PUBLIC,anon,authenticated;
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section5_source_batch_progress_v1)<>23
 OR (SELECT sum(airports) FROM airlinerra_game.airport_group2_section5_source_batch_progress_v1)<>1118
 OR (SELECT sum(airports_with_source_review) FROM airlinerra_game.airport_group2_section5_source_batch_progress_v1)<>5
 OR (SELECT sum(source_findings) FROM airlinerra_game.airport_group2_section5_source_batch_progress_v1)<>6
 OR (SELECT sum(fully_sourced_restrictions) FROM airlinerra_game.airport_group2_section5_source_batch_progress_v1)<>0
 OR (SELECT sum(incomplete_restrictions) FROM airlinerra_game.airport_group2_section5_source_batch_progress_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'SECTION5_BATCH_PROGRESS_POSTCHECK_FAILED'; END IF;
END $$;