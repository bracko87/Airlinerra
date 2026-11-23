-- Group 2 Section 3: runway GAME-data closure. Source runway details remain unverified.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section2_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION3_PREFLIGHT_FAILED'; END IF;
END $$;
CREATE VIEW airlinerra_game.airport_group2_section3_game_registry_v1
 WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,r.airport_key,
 r.runway_registry_qualified_length_m AS game_runway_length_m,
 r.runway_registry_qualified_surface AS game_runway_surface,
 r.longest_detail_length_m AS observed_detail_length_m,
 r.detail_runway_width_m AS observed_detail_width_m,
 r.game_runway_width_m,r.runway_width_game_basis,
 r.detailed_runway_observation_count,
 (r.runway_width_game_basis='CATEGORY_MEDIAN_GAME_WIDTH_ESTIMATE') AS width_is_game_estimate,
 (r.longest_detail_length_m IS NULL OR r.detailed_runway_observation_count=0) AS detailed_runway_missing,
 (r.runway_registry_qualified_length_m>0
  AND nullif(btrim(r.runway_registry_qualified_surface),'') IS NOT NULL
  AND r.game_runway_width_m>0
  AND nullif(btrim(r.runway_width_game_basis),'') IS NOT NULL) AS section3_game_data_complete,
 false AS independently_source_verified,false AS commercially_admitted,false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section3_runways_v1 r
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section3_game_registry_v1 FROM PUBLIC,anon,authenticated;
CREATE VIEW airlinerra_game.airport_group2_section3_batch_completion_v1
 WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER(WHERE section3_game_data_complete)::integer AS game_complete,
 count(*) FILTER(WHERE width_is_game_estimate)::integer AS estimated_runway_widths,
 count(*) FILTER(WHERE detailed_runway_missing)::integer AS missing_detailed_runways,
 CASE WHEN bool_and(section3_game_data_complete) THEN 'game_complete_estimated'
 ELSE 'game_incomplete' END::text AS game_data_result,
 false AS independent_source_verification_complete,
 false AS live_airport_operations_enabled
FROM airlinerra_game.airport_group2_section3_game_registry_v1 GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section3_batch_completion_v1 FROM PUBLIC,anon,authenticated;
CREATE TABLE airlinerra_game.airport_group2_section3_batch_acceptance_v1(
 batch_number smallint PRIMARY KEY CHECK(batch_number BETWEEN 1 AND 23),
 airports integer NOT NULL CHECK(airports BETWEEN 1 AND 50),
 complete_game_profiles integer NOT NULL CHECK(complete_game_profiles=airports),
 estimated_runway_widths integer NOT NULL CHECK(estimated_runway_widths>=0),
 missing_detailed_runways integer NOT NULL CHECK(missing_detailed_runways>=0),
 game_data_result text NOT NULL CHECK(game_data_result='game_complete_estimated'),
 independently_source_verified boolean NOT NULL DEFAULT false CHECK(NOT independently_source_verified),
 operationally_authorized boolean NOT NULL DEFAULT false CHECK(NOT operationally_authorized),
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10'
);
ALTER TABLE airlinerra_game.airport_group2_section3_batch_acceptance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section3_batch_acceptance_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section3_batch_acceptance_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section3_batch_acceptance_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
INSERT INTO airlinerra_game.airport_group2_section3_batch_acceptance_v1
(batch_number,airports,complete_game_profiles,estimated_runway_widths,missing_detailed_runways,game_data_result)
SELECT batch_number,airports,game_complete,estimated_runway_widths,missing_detailed_runways,game_data_result
FROM airlinerra_game.airport_group2_section3_batch_completion_v1
WHERE game_data_result='game_complete_estimated';
CREATE VIEW airlinerra_game.airport_group2_section3_overall_status_v1
 WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(complete_game_profiles),0)::integer AS game_complete_airports,
 coalesce(sum(estimated_runway_widths),0)::integer AS estimated_runway_widths,
 coalesce(sum(missing_detailed_runways),0)::integer AS missing_detailed_runways,
 CASE WHEN count(*)=23 AND sum(airports)=1118 AND sum(complete_game_profiles)=1118
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section3_batch_acceptance_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section3_overall_status_v1 FROM PUBLIC,anon,authenticated;
DO $$
BEGIN
 IF (SELECT game_data_result FROM airlinerra_game.airport_group2_section3_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT estimated_runway_widths FROM airlinerra_game.airport_group2_section3_overall_status_v1)<>20
 OR (SELECT missing_detailed_runways FROM airlinerra_game.airport_group2_section3_overall_status_v1)<>9
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section3_batch_completion_v1
   WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section3_game_registry_v1
   WHERE NOT section3_game_data_complete OR commercially_admitted OR live_flight_authorized)
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION3_GAME_ACCEPTANCE_FAILED'; END IF;
END $$;