-- Group 2 Section 2: classification GAME-data acceptance only.
-- Preserve the owner-selected tier and traffic intention; no source certification or flight authorization.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1) <> 1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1) <> 3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_batch_acceptance_v1) <> 23
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1) <> 'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION2_PREFLIGHT_FAILED'; END IF;
END $$;

CREATE VIEW airlinerra_game.airport_group2_section2_game_registry_v1
 WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,g.airport_key,
 g.owner_category AS game_category,g.game_traffic_type,
 g.owner_decision,g.preapproved_at,
 (g.owner_category IN('Local','Regional','Medium','Large','Major Hub','Mega Hub')
  AND g.game_traffic_type IN('Passenger','Cargo','Both')
  AND g.owner_decision IS NOT NULL AND g.preapproved_at IS NOT NULL) AS section2_game_data_complete,
 'OWNER_PREAPPROVED_GAME_CLASSIFICATION_UNVERIFIED'::text AS classification_basis,
 false AS independently_source_verified,
 false AS commercially_admitted,
 false AS live_flight_authorized
FROM airlinerra_game.airport_group2_game_profiles_v1 g
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING (airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section2_game_registry_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section2_batch_completion_v1
 WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER (WHERE section2_game_data_complete)::integer AS game_complete,
 count(*) FILTER (WHERE game_category='Local')::integer AS local_airports,
 count(*) FILTER (WHERE game_category='Regional')::integer AS regional_airports,
 count(*) FILTER (WHERE game_category='Medium')::integer AS medium_airports,
 count(*) FILTER (WHERE game_category='Large')::integer AS large_airports,
 count(*) FILTER (WHERE game_category='Major Hub')::integer AS major_hub_airports,
 count(*) FILTER (WHERE game_category='Mega Hub')::integer AS mega_hub_airports,
 count(*) FILTER (WHERE game_traffic_type='Passenger')::integer AS passenger_airports,
 count(*) FILTER (WHERE game_traffic_type='Cargo')::integer AS cargo_airports,
 count(*) FILTER (WHERE game_traffic_type='Both')::integer AS mixed_airports,
 CASE WHEN bool_and(section2_game_data_complete) THEN 'game_complete_estimated'
 ELSE 'game_incomplete' END::text AS game_data_result,
 false AS independently_source_verified,
 false AS live_airport_operations_enabled
FROM airlinerra_game.airport_group2_section2_game_registry_v1
GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section2_batch_completion_v1 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.airport_group2_section2_batch_acceptance_v1 (
 batch_number smallint PRIMARY KEY CHECK(batch_number BETWEEN 1 AND 23),
 airports integer NOT NULL CHECK(airports BETWEEN 1 AND 50),
 complete_game_profiles integer NOT NULL CHECK(complete_game_profiles=airports),
 game_data_result text NOT NULL CHECK(game_data_result='game_complete_estimated'),
 local_airports integer NOT NULL, regional_airports integer NOT NULL,
 medium_airports integer NOT NULL,large_airports integer NOT NULL,
 major_hub_airports integer NOT NULL,mega_hub_airports integer NOT NULL,
 passenger_airports integer NOT NULL,cargo_airports integer NOT NULL,mixed_airports integer NOT NULL,
 independently_source_verified boolean NOT NULL DEFAULT false CHECK(NOT independently_source_verified),
 operationally_authorized boolean NOT NULL DEFAULT false CHECK(NOT operationally_authorized),
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10',
 CHECK(local_airports+regional_airports+medium_airports+large_airports+major_hub_airports+mega_hub_airports=airports),
 CHECK(passenger_airports+cargo_airports+mixed_airports=airports)
);
ALTER TABLE airlinerra_game.airport_group2_section2_batch_acceptance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section2_batch_acceptance_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section2_batch_acceptance_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section2_batch_acceptance_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();

INSERT INTO airlinerra_game.airport_group2_section2_batch_acceptance_v1
(batch_number,airports,complete_game_profiles,game_data_result,
local_airports,regional_airports,medium_airports,large_airports,major_hub_airports,mega_hub_airports,
passenger_airports,cargo_airports,mixed_airports)
SELECT batch_number,airports,game_complete,game_data_result,
local_airports,regional_airports,medium_airports,large_airports,major_hub_airports,mega_hub_airports,
passenger_airports,cargo_airports,mixed_airports
FROM airlinerra_game.airport_group2_section2_batch_completion_v1
WHERE game_data_result='game_complete_estimated';

CREATE VIEW airlinerra_game.airport_group2_section2_overall_status_v1
 WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(complete_game_profiles),0)::integer AS game_complete_airports,
 coalesce(sum(local_airports),0)::integer AS local_airports,
 coalesce(sum(regional_airports),0)::integer AS regional_airports,
 coalesce(sum(medium_airports),0)::integer AS medium_airports,
 coalesce(sum(large_airports),0)::integer AS large_airports,
 coalesce(sum(major_hub_airports),0)::integer AS major_hub_airports,
 coalesce(sum(mega_hub_airports),0)::integer AS mega_hub_airports,
 coalesce(sum(passenger_airports),0)::integer AS passenger_airports,
 coalesce(sum(cargo_airports),0)::integer AS cargo_airports,
 coalesce(sum(mixed_airports),0)::integer AS mixed_airports,
 CASE WHEN count(*)=23 AND sum(airports)=1118 AND sum(complete_game_profiles)=1118
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,
 false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section2_batch_acceptance_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section2_overall_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section2_batch_acceptance_v1) <> 23
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section2_overall_status_v1) <> 'game_complete_estimated'
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section2_batch_completion_v1
           WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section2_game_registry_v1
           WHERE NOT section2_game_data_complete OR commercially_admitted OR live_flight_authorized)
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
           WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1) <> 3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1) <> 'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION2_GAME_ACCEPTANCE_FAILED'; END IF;
END $$;