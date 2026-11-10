-- Group 2 Section 8: estimated economics game-data acceptance, NOT real airport tariffs.
-- Same immutable 23 batches. Section 5 restrictions remain unresolved and no airport becomes operational.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section7_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION8_PREFLIGHT_FAILED'; END IF;
END $$;

CREATE VIEW airlinerra_game.airport_group2_section8_game_registry_v1
WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,e.airport_key,e.game_category,e.game_airport_background,
 e.background_verified,e.game_landing_fee_usd,e.game_parking_per_day_usd,
 e.game_departing_pax_fee_usd,e.terminal_stand_multiplier,e.remote_stand_multiplier,
 e.cargo_stand_multiplier,e.terminal_navigation_unit_usd,e.cargo_handling_per_tonne_usd,
 e.ground_handling_fraction,e.security_per_departing_passenger_usd,
 e.international_processing_per_departing_passenger_usd,e.pricing_basis,
 (e.pricing_basis='GROUP1_CATEGORY_MEDIAN_GAME_RATE_NOT_REAL_TARIFF') AS prices_are_game_estimates,
 (e.pricing_basis='GROUP1_CATEGORY_MEDIAN_GAME_RATE_NOT_REAL_TARIFF'
 AND e.game_category IN ('Local','Regional','Medium','Large','Major Hub','Mega Hub')
 AND e.game_category=g.owner_category
 AND e.game_landing_fee_usd IS NOT NULL AND e.game_landing_fee_usd>=0
 AND e.game_parking_per_day_usd IS NOT NULL AND e.game_parking_per_day_usd>=0
 AND e.game_departing_pax_fee_usd IS NOT NULL AND e.game_departing_pax_fee_usd>=0
 AND e.game_landing_fee_usd=g.game_landing_fee_usd
 AND e.game_parking_per_day_usd=g.game_parking_per_day_usd
 AND e.game_departing_pax_fee_usd=g.game_departing_pax_fee_usd
 AND nullif(btrim(e.game_airport_background),'') IS NOT NULL
 AND e.background_verified=false
 AND e.terminal_stand_multiplier>0 AND e.remote_stand_multiplier>0
 AND e.cargo_stand_multiplier>0 AND e.terminal_navigation_unit_usd>=0
 AND e.cargo_handling_per_tonne_usd>=0
 AND e.ground_handling_fraction BETWEEN 0 AND 1
 AND e.security_per_departing_passenger_usd>=0
 AND e.international_processing_per_departing_passenger_usd>=0
 ) AS section8_game_data_complete,
 false AS independently_real_tariff_verified,
 false AS restrictions_cleared,
 false AS commercially_admitted,
 false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section8_economics_v1 e
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key)
JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section8_game_registry_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section8_batch_completion_v1
WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER(WHERE section8_game_data_complete)::integer AS game_complete,
 count(*) FILTER(WHERE prices_are_game_estimates)::integer AS estimated_tariff_profiles,
 count(*) FILTER(WHERE game_category='Local')::integer AS local_airports,
 count(*) FILTER(WHERE game_category='Regional')::integer AS regional_airports,
 count(*) FILTER(WHERE game_category='Medium')::integer AS medium_airports,
 CASE WHEN bool_and(section8_game_data_complete) THEN 'game_complete_estimated'
 ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,false AS live_operations_enabled
FROM airlinerra_game.airport_group2_section8_game_registry_v1 GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section8_batch_completion_v1 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.airport_group2_section8_batch_acceptance_v1 (
 batch_number smallint PRIMARY KEY CHECK(batch_number BETWEEN 1 AND 23),
 airports integer NOT NULL CHECK(airports BETWEEN 1 AND 50),
 complete_game_profiles integer NOT NULL CHECK(complete_game_profiles=airports),
 estimated_tariff_profiles integer NOT NULL CHECK(estimated_tariff_profiles=airports),
 local_airports integer NOT NULL CHECK(local_airports>=0),
 regional_airports integer NOT NULL CHECK(regional_airports>=0),
 medium_airports integer NOT NULL CHECK(medium_airports>=0),
 game_data_result text NOT NULL CHECK(game_data_result='game_complete_estimated'),
 independently_source_verified boolean NOT NULL DEFAULT false CHECK(NOT independently_source_verified),
 operationally_authorized boolean NOT NULL DEFAULT false CHECK(NOT operationally_authorized),
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10',
 CHECK(local_airports+regional_airports+medium_airports=airports)
);
ALTER TABLE airlinerra_game.airport_group2_section8_batch_acceptance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section8_batch_acceptance_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section8_batch_acceptance_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section8_batch_acceptance_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
INSERT INTO airlinerra_game.airport_group2_section8_batch_acceptance_v1
(batch_number,airports,complete_game_profiles,estimated_tariff_profiles,local_airports,regional_airports,medium_airports,game_data_result)
SELECT batch_number,airports,game_complete,estimated_tariff_profiles,local_airports,regional_airports,medium_airports,game_data_result
FROM airlinerra_game.airport_group2_section8_batch_completion_v1
WHERE game_data_result='game_complete_estimated';

CREATE VIEW airlinerra_game.airport_group2_section8_overall_status_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(complete_game_profiles),0)::integer AS game_complete_airports,
 coalesce(sum(estimated_tariff_profiles),0)::integer AS estimated_tariff_profiles,
 coalesce(sum(local_airports),0)::integer AS local_airports,
 coalesce(sum(regional_airports),0)::integer AS regional_airports,
 coalesce(sum(medium_airports),0)::integer AS medium_airports,
 CASE WHEN count(*)=23 AND sum(airports)=1118 AND sum(complete_game_profiles)=1118
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,false AS real_airport_tariffs_verified,
 false AS restrictions_cleared,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section8_batch_acceptance_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section8_overall_status_v1 FROM PUBLIC,anon,authenticated;
DO $$
BEGIN
 IF (SELECT game_data_result FROM airlinerra_game.airport_group2_section8_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT estimated_tariff_profiles FROM airlinerra_game.airport_group2_section8_overall_status_v1)<>1118
 OR (SELECT local_airports FROM airlinerra_game.airport_group2_section8_overall_status_v1)<>754
 OR (SELECT regional_airports FROM airlinerra_game.airport_group2_section8_overall_status_v1)<>338
 OR (SELECT medium_airports FROM airlinerra_game.airport_group2_section8_overall_status_v1)<>26
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section8_batch_completion_v1
   WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section8_game_registry_v1
   WHERE NOT section8_game_data_complete OR commercially_admitted OR live_flight_authorized)
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
   WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION8_GAME_ACCEPTANCE_FAILED'; END IF;
END $$;