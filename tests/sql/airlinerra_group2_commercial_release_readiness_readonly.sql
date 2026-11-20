-- Airlinerra World 1 commercial-flight airport readiness
-- READ ONLY: do not use simulation admissions as actual commercial authorizations.
-- No grants, permission changes, releases, airport admission or flight mutations.
-- Run individually in Supabase SQL editor to inspect current evidence.
WITH
roster AS (
 SELECT source_group, count(*) AS listed,
 count(*) FILTER (WHERE included_in_unified_catalogue) AS catalogued,
 count(*) FILTER (WHERE admitted_to_world) AS world_admitted,
 count(*) FILTER (WHERE operationally_authorized) AS commercially_authorized,
 count(*) FILTER (WHERE dispatch_eligible_by_airport_admission) AS dispatch_eligible_by_admission
 FROM airlinerra_game.airport_player_game_roster_v1
 WHERE world_id=1
 GROUP BY source_group
),
group2 AS (
 SELECT count(*) AS profiles,
 count(*) FILTER (WHERE readiness_status='HARD_HOLD_DOCUMENTED_PROHIBITION') AS hard_holds,
 count(*) FILTER (WHERE readiness_status='EVIDENCE_INCOMPLETE_NOT_PLAYABLE') AS incomplete,
 count(*) FILTER (WHERE ready_for_owner_release_review) AS review_ready,
 count(*) FILTER (WHERE can_activate_flights) AS activation_ready
 FROM airlinerra_game.airport_group2_admission_readiness_v1
),
counts AS (
 SELECT (SELECT count(*) FROM airlinerra_game.airport_group2_simulation_admissions_v1 WHERE world_id=1) AS simulation_admissions,
 (SELECT count(*) FROM airlinerra_game.airport_group2_operational_releases_v1 WHERE world_id=1) AS operational_release_records,
 (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1) AS draft_schedules,
 (SELECT count(*) FROM airlinerra_game.airline_route_planning_drafts_v1) AS route_planning_drafts
)
SELECT r.source_group,r.listed,r.catalogued,r.world_admitted,
 r.commercially_authorized,r.dispatch_eligible_by_admission,
 g.profiles AS group2_profiles,g.hard_holds AS group2_documented_prohibitions,
 g.incomplete AS group2_evidence_incomplete,
 g.review_ready AS group2_review_ready,g.activation_ready AS group2_activation_ready,
 c.simulation_admissions,c.operational_release_records,
 c.route_planning_drafts,c.draft_schedules,
 CASE WHEN r.source_group='GROUP_2' AND (
  g.hard_holds>0 OR g.incomplete>0 OR g.review_ready<>g.profiles
  OR c.operational_release_records<>g.profiles
 ) THEN 'NOT_READY_FOR_BLANKET_COMMERCIAL_RELEASE'
 WHEN r.source_group='GROUP_1' THEN 'EXISTING_GROUP1_ADMISSION_ONLY'
 ELSE 'CHECK_INDIVIDUAL_RESTRICTIONS_AND_ALL_OTHER_FLIGHT_GATES' END AS readiness_summary
FROM roster r CROSS JOIN group2 g CROSS JOIN counts c
ORDER BY r.source_group;

-- Explicit evidence-hold report; no writes.
SELECT airport_key,game_airport_name,country_iso,readiness_status,
 documented_commercial_prohibition,unresolved_gates
FROM airlinerra_game.airport_group2_admission_readiness_v1
WHERE readiness_status='HARD_HOLD_DOCUMENTED_PROHIBITION'
ORDER BY airport_key;
