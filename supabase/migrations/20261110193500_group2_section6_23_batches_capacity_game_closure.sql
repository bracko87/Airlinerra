-- Group 2 Section 6: game capacity/slot estimation acceptance, not real coordinator slot authority.
-- This does not override Section 5 unresolved restrictions.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section4_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT section5_status FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>'source_research_required'
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION6_PREFLIGHT_FAILED';END IF;
END $$;

CREATE VIEW airlinerra_game.airport_group2_section6_game_registry_v1
WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,c.airport_key,
 c.game_terminal_stands,c.game_remote_stands,c.game_cargo_stands,
 c.game_terminal_slot_per_10m,c.game_remote_slot_per_10m,c.game_cargo_slot_per_10m,
 c.capacity_basis,
 (c.capacity_basis='GROUP1_CATEGORY_MEDIAN_GAME_NOT_COORDINATOR_SLOTS') AS capacity_is_game_estimate,
 (c.game_terminal_stands=f.game_terminal_stands
 AND c.game_remote_stands=f.game_remote_stands
 AND c.game_cargo_stands=f.game_cargo_stands
 AND c.game_terminal_stands>=0 AND c.game_remote_stands>=0 AND c.game_cargo_stands>=0
 AND c.game_terminal_slot_per_10m>=0 AND c.game_remote_slot_per_10m>=0 AND c.game_cargo_slot_per_10m>=0
 AND (c.game_terminal_stands>0)=(c.game_terminal_slot_per_10m>0)
 AND (c.game_remote_stands>0)=(c.game_remote_slot_per_10m>0)
 AND (c.game_cargo_stands>0)=(c.game_cargo_slot_per_10m>0)
 AND c.capacity_basis='GROUP1_CATEGORY_MEDIAN_GAME_NOT_COORDINATOR_SLOTS') AS section6_game_data_complete,
 false AS real_slot_coordinator_verified,
 false AS source_restrictions_cleared,
 false AS commercially_admitted,
 false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section6_capacity_v1 c
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key)
JOIN airlinerra_game.airport_group2_section4_facilities_v1 f USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section6_game_registry_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section6_batch_completion_v1
WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER(WHERE section6_game_data_complete)::integer AS game_complete,
 count(*) FILTER(WHERE capacity_is_game_estimate)::integer AS estimated_capacity_profiles,
 count(*) FILTER(WHERE game_terminal_stands>0)::integer AS passenger_stand_airports,
 count(*) FILTER(WHERE game_cargo_stands>0)::integer AS cargo_stand_airports,
 CASE WHEN bool_and(section6_game_data_complete) THEN 'game_complete_estimated'
 ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,
 false AS restrictions_cleared,
 false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section6_game_registry_v1
GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section6_batch_completion_v1 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.airport_group2_section6_batch_acceptance_v1 (
 batch_number smallint PRIMARY KEY CHECK(batch_number BETWEEN 1 AND 23),
 airports integer NOT NULL CHECK(airports BETWEEN 1 AND 50),
 complete_game_profiles integer NOT NULL CHECK(complete_game_profiles=airports),
 estimated_capacity_profiles integer NOT NULL CHECK(estimated_capacity_profiles=airports),
 passenger_stand_airports integer NOT NULL CHECK(passenger_stand_airports>=0),
 cargo_stand_airports integer NOT NULL CHECK(cargo_stand_airports>=0),
 game_data_result text NOT NULL CHECK(game_data_result='game_complete_estimated'),
 independently_source_verified boolean NOT NULL DEFAULT false CHECK(NOT independently_source_verified),
 restrictions_cleared boolean NOT NULL DEFAULT false CHECK(NOT restrictions_cleared),
 operationally_authorized boolean NOT NULL DEFAULT false CHECK(NOT operationally_authorized),
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10'
);
ALTER TABLE airlinerra_game.airport_group2_section6_batch_acceptance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section6_batch_acceptance_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section6_batch_acceptance_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section6_batch_acceptance_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();

INSERT INTO airlinerra_game.airport_group2_section6_batch_acceptance_v1
(batch_number,airports,complete_game_profiles,estimated_capacity_profiles,passenger_stand_airports,cargo_stand_airports,game_data_result)
SELECT batch_number,airports,game_complete,estimated_capacity_profiles,passenger_stand_airports,cargo_stand_airports,game_data_result
FROM airlinerra_game.airport_group2_section6_batch_completion_v1
WHERE game_data_result='game_complete_estimated';

CREATE VIEW airlinerra_game.airport_group2_section6_overall_status_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(complete_game_profiles),0)::integer AS game_complete_airports,
 coalesce(sum(estimated_capacity_profiles),0)::integer AS estimated_capacity_profiles,
 coalesce(sum(passenger_stand_airports),0)::integer AS passenger_stand_airports,
 coalesce(sum(cargo_stand_airports),0)::integer AS cargo_stand_airports,
 CASE WHEN count(*)=23 AND sum(airports)=1118 AND sum(complete_game_profiles)=1118
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,false AS real_slot_coordinator_verified,
 false AS restrictions_cleared,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section6_batch_acceptance_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section6_overall_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT game_data_result FROM airlinerra_game.airport_group2_section6_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT estimated_capacity_profiles FROM airlinerra_game.airport_group2_section6_overall_status_v1)<>1118
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_section6_batch_completion_v1
   WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))
 OR EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_section6_game_registry_v1
   WHERE NOT section6_game_data_complete OR commercially_admitted OR live_flight_authorized
   OR real_slot_coordinator_verified OR source_restrictions_cleared)
 OR EXISTS (SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION6_GAME_ACCEPTANCE_FAILED';END IF;
END $$;