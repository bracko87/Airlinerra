-- Group 2 Section 4: GAME facilities closure, not independently verified airport infrastructure.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section3_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section2_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION4_PREFLIGHT_FAILED'; END IF;
END $$;

CREATE VIEW airlinerra_game.airport_group2_section4_game_registry_v1
WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,f.airport_key,
 f.game_terminal_count,f.game_terminal_stands,f.game_remote_stands,f.game_cargo_stands,
 f.game_traffic_type,f.facility_basis,
 (f.facility_basis='CATEGORY_MEDIAN_GAME_ESTIMATE_NOT_VERIFIED_FACILITY') AS facilities_are_game_estimates,
 (f.game_terminal_count IS NOT NULL AND f.game_terminal_count>=0
 AND f.game_terminal_stands IS NOT NULL AND f.game_terminal_stands>=0
 AND f.game_remote_stands IS NOT NULL AND f.game_remote_stands>=0
 AND f.game_cargo_stands IS NOT NULL AND f.game_cargo_stands>=0
 AND f.facility_basis='CATEGORY_MEDIAN_GAME_ESTIMATE_NOT_VERIFIED_FACILITY'
 AND (
  (f.game_traffic_type='Passenger' AND f.game_terminal_count>0 AND f.game_terminal_stands>0 AND f.game_cargo_stands=0)
  OR (f.game_traffic_type='Cargo' AND f.game_terminal_count=0 AND f.game_terminal_stands=0 AND f.game_remote_stands=0 AND f.game_cargo_stands>0)
  OR (f.game_traffic_type='Both' AND f.game_terminal_count>0 AND f.game_terminal_stands>0 AND f.game_cargo_stands>0)
 )) AS section4_game_data_complete,
 false AS independently_source_verified,false AS commercially_admitted,false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section4_facilities_v1 f
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section4_game_registry_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section4_batch_completion_v1
WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER (WHERE section4_game_data_complete)::integer AS game_complete,
 count(*) FILTER (WHERE facilities_are_game_estimates)::integer AS estimated_facilities,
 count(*) FILTER (WHERE game_traffic_type='Passenger')::integer AS passenger_airports,
 count(*) FILTER (WHERE game_traffic_type='Cargo')::integer AS cargo_airports,
 count(*) FILTER (WHERE game_traffic_type='Both')::integer AS mixed_airports,
 CASE WHEN bool_and(section4_game_data_complete) THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS independently_source_verified,false AS live_airport_operations_enabled
FROM airlinerra_game.airport_group2_section4_game_registry_v1 GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section4_batch_completion_v1 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.airport_group2_section4_batch_acceptance_v1 (
 batch_number smallint PRIMARY KEY CHECK(batch_number BETWEEN 1 AND 23),
 airports integer NOT NULL CHECK(airports BETWEEN 1 AND 50),
 complete_game_profiles integer NOT NULL CHECK(complete_game_profiles=airports),
 estimated_facilities integer NOT NULL CHECK(estimated_facilities=airports),
 passenger_airports integer NOT NULL CHECK(passenger_airports>=0),
 cargo_airports integer NOT NULL CHECK(cargo_airports>=0),
 mixed_airports integer NOT NULL CHECK(mixed_airports>=0),
 game_data_result text NOT NULL CHECK(game_data_result='game_complete_estimated'),
 independently_source_verified boolean NOT NULL DEFAULT false CHECK(NOT independently_source_verified),
 operationally_authorized boolean NOT NULL DEFAULT false CHECK(NOT operationally_authorized),
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10',
 CHECK(passenger_airports+cargo_airports+mixed_airports=airports)
);
ALTER TABLE airlinerra_game.airport_group2_section4_batch_acceptance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section4_batch_acceptance_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section4_batch_acceptance_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section4_batch_acceptance_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();

INSERT INTO airlinerra_game.airport_group2_section4_batch_acceptance_v1
(batch_number,airports,complete_game_profiles,estimated_facilities,passenger_airports,cargo_airports,mixed_airports,game_data_result)
SELECT batch_number,airports,game_complete,estimated_facilities,passenger_airports,cargo_airports,mixed_airports,game_data_result
FROM airlinerra_game.airport_group2_section4_batch_completion_v1 WHERE game_data_result='game_complete_estimated';

CREATE VIEW airlinerra_game.airport_group2_section4_overall_status_v1
 WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(complete_game_profiles),0)::integer AS game_complete_airports,
 coalesce(sum(estimated_facilities),0)::integer AS estimated_facilities,
 coalesce(sum(passenger_airports),0)::integer AS passenger_airports,
 coalesce(sum(cargo_airports),0)::integer AS cargo_airports,
 coalesce(sum(mixed_airports),0)::integer AS mixed_airports,
 CASE WHEN count(*)=23 AND sum(airports)=1118 AND sum(complete_game_profiles)=1118
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section4_batch_acceptance_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section4_overall_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT game_data_result FROM airlinerra_game.airport_group2_section4_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT estimated_facilities FROM airlinerra_game.airport_group2_section4_overall_status_v1)<>1118
 OR (SELECT passenger_airports FROM airlinerra_game.airport_group2_section4_overall_status_v1)<>953
 OR (SELECT cargo_airports FROM airlinerra_game.airport_group2_section4_overall_status_v1)<>43
 OR (SELECT mixed_airports FROM airlinerra_game.airport_group2_section4_overall_status_v1)<>122
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section4_batch_completion_v1
    WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section4_game_registry_v1
    WHERE NOT section4_game_data_complete OR commercially_admitted OR live_flight_authorized)
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
    WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION4_GAME_ACCEPTANCE_FAILED'; END IF;
END $$;