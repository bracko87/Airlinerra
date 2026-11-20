-- World 1 Group 1 first commercial-flight release checkpoint.
-- READ-ONLY, NO LIVE FLIGHT OR SCHEDULE CREATED.
-- Uses confirmed authorized FRA / MUC as a safe potential test route.
-- This is a RELEASE-GATE REPORT, not a simulator or certificate.
WITH airports AS (
 SELECT airport_key,game_lookup_code,source_group,
 included_in_unified_catalogue,admitted_to_world,
 operationally_authorized,dispatch_eligible_by_airport_admission
 FROM airlinerra_game.airport_player_game_roster_v1
 WHERE world_id=1 AND airport_key IN('OURAIRPORTS:2212','OURAIRPORTS:2218')
),
pair AS (
 SELECT count(*)=2 AND
 count(*) FILTER (WHERE source_group='GROUP_1' AND
 included_in_unified_catalogue AND admitted_to_world AND
 operationally_authorized AND dispatch_eligible_by_airport_admission)=2
 AS group1_airport_admission_ready,
 count(*) FILTER (WHERE airport_key='OURAIRPORTS:2212' AND game_lookup_code='FRA')=1
 AS origin_frankfurt_verified,
 count(*) FILTER (WHERE airport_key='OURAIRPORTS:2218' AND game_lookup_code='MUC')=1
 AS destination_munich_verified FROM airports
),
release AS (
 SELECT a.world_id,a.release_state AS activation_state,a.crew_mode,
 e.release_state AS execution_state,f.release_state AS finance_state,
 r.world_state,r.authoritative_clock_connected,r.clock_producer_enabled,
 r.trusted_flight_execution_release,r.fuel_transaction_release,
 r.automatic_flight_and_fuel_settlement_enabled,
 r.saved_flight_schedules,r.active_flight_schedules,
 r.operational_certification_records,r.verified_movement_records,
 r.settled_flight_records
 FROM airlinerra_game.section9_activation_release_policy_v1 a
 JOIN airlinerra_game.section9_trusted_execution_release_policy_v1 e
  ON e.world_id=a.world_id
 JOIN airlinerra_game.section9_flight_finance_posting_release_v1 f
  ON f.world_id=a.world_id
 JOIN airlinerra_game.section9_flight_engine_readiness_audit_v1 r
  ON r.world_id=a.world_id
 WHERE a.world_id=1
)
SELECT release.*,pair.*,
 CASE WHEN NOT pair.group1_airport_admission_ready OR
 NOT pair.origin_frankfurt_verified OR NOT pair.destination_munich_verified
 THEN 'BLOCKED_AIRPORT_ADMISSION'
 WHEN release.activation_state<>'enabled' OR
 release.execution_state<>'enabled' OR
 release.finance_state<>'approved' OR
 release.trusted_flight_execution_release<>'ACTIVATED' OR
 release.fuel_transaction_release<>'ACTIVATED' OR
 release.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN 'BLOCKED_FLIGHT_ENGINE_AND_FINANCE_RELEASE'
 ELSE 'RELEASE_FLAGS_PRESENT_STILL_REQUIRES_VERIFIED_OWNER_AIRCRAFT_LICENCE_CERTIFICATES_SLOTS_CREW'
 END AS group1_test_route_release_gate
FROM release CROSS JOIN pair;

-- Check every service involved in the atomic pair-and-ticket release.
-- This checks policy status ONLY, not individual aircraft, AOC or actual
-- air-traffic permissions, airport slot bookings or staff certifications.
