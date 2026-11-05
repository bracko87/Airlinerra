-- Read-only operational reference for every Section 5 airport research batch.
-- Runway inventory counts and historical lengths are not automatically authority verified.
-- Competitor slot quotas must not be interpreted as physical hourly movements.
CREATE OR REPLACE VIEW airlinerra_game.section5_airport_batch50_operational_reference_v1 WITH (security_invoker=true) AS
SELECT b.world_id,b.airport_key,b.batch_no,b.batch_position,b.airport_code,b.airport_name,b.country_iso,
p.icao_reported AS icao_code,p.timezone_iana,p.timezone_verified_on,
r.runway_inventory_count,e.expected_physical_runway_pairs AS officially_reviewed_runway_count,
e.evidence_grade AS reviewed_runway_count_evidence_grade,
r.longest_in_inventory_m,r.runways AS runway_inventory,
CASE WHEN e.expected_physical_runway_pairs IS NOT NULL THEN 'RUNWAY_COUNT_HAS_SEPARATE_REVIEW'
WHEN r.runway_inventory_count IS NOT NULL THEN 'RUNWAY_INVENTORY_ONLY_NOT_AUTHORITY_VERIFIED'
ELSE 'MISSING_RUNWAYS' END AS runway_count_evidence_status,
cap.observation_kind AS capacity_observation_kind,
cap.movements_per_hour AS capacity_movements_per_hour,
cap.movements_per_day AS capacity_movements_per_day,
cap.source_authority AS capacity_source_authority,
cap.source_url AS capacity_source_url,
cap.verification AS capacity_verification,
b.curfew_result AS curfew_research_result,b.curfew_rule_summary,b.curfew_source_url,
b.chapter_result AS noise_chapter_research_result,b.chapter_rule_summary,b.chapter_source_url
FROM airlinerra_game.section5_airport_batch50_screen_v1 b
JOIN airlinerra_game.airport_reference_profiles p USING(world_id,airport_key)
LEFT JOIN airlinerra_game.airport_runway_completeness_evidence e USING(world_id,airport_key)
LEFT JOIN LATERAL (
SELECT count(*)::integer runway_inventory_count,max(i.length_m) longest_in_inventory_m,
jsonb_agg(jsonb_build_object('designator',i.runway_designator,'length_m',i.length_m,'width_m',i.width_m,'source',i.source_identifier,'verification',i.verification,'operational_status',i.operational_status) ORDER BY i.runway_designator) runways
FROM airlinerra_game.airport_runway_inventory i
WHERE i.world_id=b.world_id AND i.airport_key=b.airport_key
) r ON TRUE
LEFT JOIN LATERAL (
SELECT c.observation_kind,c.movements_per_hour,c.movements_per_day,c.source_authority,c.source_url,c.verification
FROM airlinerra_game.airport_capacity_observations c
WHERE c.world_id=b.world_id AND c.airport_key=b.airport_key
ORDER BY c.reviewed_on DESC NULLS LAST,c.id DESC LIMIT 1
) cap ON TRUE;
REVOKE ALL ON airlinerra_game.section5_airport_batch50_operational_reference_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.section5_airport_batch50_operational_reference_v1 IS
'Joined Section 5 batches with existing runway and IANA timezone facts plus movement-capacity observations. NULL capacity means no source. External-game slot quotas are not real movement capacities.';