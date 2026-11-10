-- Group 2 Section 7: estimated passenger and cargo demand acceptance.
-- This does NOT verify real demand, seasonal distribution or live flight permissions.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section6_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION7_PREFLIGHT_FAILED'; END IF;
END $$;

CREATE VIEW airlinerra_game.airport_group2_section7_game_registry_v1
WITH (security_invoker=true) AS
SELECT b.batch_number,b.case_number,d.airport_key,d.game_traffic_type,
 d.game_daily_outbound_passengers,d.game_daily_outbound_cargo_tonnes,
 d.game_season_profile,d.model_basis,
 (d.model_basis='GROUP1_CATEGORY_MEDIAN_NEUTRAL_SEASON_GAME_ESTIMATE'
  AND d.game_season_profile='neutral_unverified_game_default_v1') AS demand_is_game_estimate,
 (d.game_traffic_type IN ('Passenger','Cargo','Both')
 AND d.game_daily_outbound_passengers IS NOT NULL
 AND d.game_daily_outbound_passengers>=0
 AND d.game_daily_outbound_cargo_tonnes IS NOT NULL
 AND d.game_daily_outbound_cargo_tonnes>=0
 AND d.model_basis='GROUP1_CATEGORY_MEDIAN_NEUTRAL_SEASON_GAME_ESTIMATE'
 AND d.game_season_profile='neutral_unverified_game_default_v1'
 AND (d.game_traffic_type<>'Cargo' OR d.game_daily_outbound_passengers=0)
 AND (d.game_traffic_type<>'Passenger' OR d.game_daily_outbound_cargo_tonnes=0)
 AND (d.game_traffic_type='Cargo' OR d.game_daily_outbound_passengers>0)
 AND (d.game_traffic_type='Passenger' OR d.game_daily_outbound_cargo_tonnes>0)
 AND d.game_traffic_type=g.game_traffic_type
 AND d.game_daily_outbound_passengers=g.game_daily_outbound_passengers
 AND d.game_daily_outbound_cargo_tonnes=g.game_daily_outbound_cargo_tonnes) AS section7_game_data_complete,
 false AS independent_traffic_source_verified,
 false AS independent_seasonality_verified,
 false AS restrictions_cleared,
 false AS commercially_admitted,
 false AS live_flight_authorized
FROM airlinerra_game.airport_group2_section7_demand_v1 d
JOIN airlinerra_game.airport_group2_fixed_batch_members_v1 b USING(airport_key)
JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section7_game_registry_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_section7_batch_completion_v1
WITH (security_invoker=true) AS
SELECT batch_number,count(*)::integer AS airports,
 count(*) FILTER (WHERE section7_game_data_complete)::integer AS game_complete,
 count(*) FILTER (WHERE demand_is_game_estimate)::integer AS estimated_demand_profiles,
 count(*) FILTER (WHERE game_traffic_type='Passenger')::integer AS passenger_only,
 count(*) FILTER (WHERE game_traffic_type='Cargo')::integer AS cargo_only,
 count(*) FILTER (WHERE game_traffic_type='Both')::integer AS mixed,
 CASE WHEN bool_and(section7_game_data_complete) THEN 'game_complete_estimated'
 ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,false AS live_operations_enabled
FROM airlinerra_game.airport_group2_section7_game_registry_v1 GROUP BY batch_number;
REVOKE ALL ON airlinerra_game.airport_group2_section7_batch_completion_v1 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.airport_group2_section7_batch_acceptance_v1(
 batch_number smallint PRIMARY KEY CHECK(batch_number BETWEEN 1 AND 23),
 airports integer NOT NULL CHECK(airports BETWEEN 1 AND 50),
 complete_game_profiles integer NOT NULL CHECK(complete_game_profiles=airports),
 estimated_demand_profiles integer NOT NULL CHECK(estimated_demand_profiles=airports),
 passenger_only integer NOT NULL CHECK(passenger_only>=0),
 cargo_only integer NOT NULL CHECK(cargo_only>=0),
 mixed integer NOT NULL CHECK(mixed>=0),
 game_data_result text NOT NULL CHECK(game_data_result='game_complete_estimated'),
 independently_source_verified boolean NOT NULL DEFAULT false CHECK(NOT independently_source_verified),
 operationally_authorized boolean NOT NULL DEFAULT false CHECK(NOT operationally_authorized),
 accepted_on date NOT NULL DEFAULT DATE '2026-11-10',
 CHECK(passenger_only+cargo_only+mixed=airports)
);
ALTER TABLE airlinerra_game.airport_group2_section7_batch_acceptance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section7_batch_acceptance_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section7_batch_acceptance_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section7_batch_acceptance_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
INSERT INTO airlinerra_game.airport_group2_section7_batch_acceptance_v1
(batch_number,airports,complete_game_profiles,estimated_demand_profiles,passenger_only,cargo_only,mixed,game_data_result)
SELECT batch_number,airports,game_complete,estimated_demand_profiles,passenger_only,cargo_only,mixed,game_data_result
FROM airlinerra_game.airport_group2_section7_batch_completion_v1
WHERE game_data_result='game_complete_estimated';

CREATE VIEW airlinerra_game.airport_group2_section7_overall_status_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer AS batches,
 coalesce(sum(airports),0)::integer AS group2_airports,
 coalesce(sum(complete_game_profiles),0)::integer AS game_complete_airports,
 coalesce(sum(estimated_demand_profiles),0)::integer AS estimated_demand_profiles,
 coalesce(sum(passenger_only),0)::integer AS passenger_only,
 coalesce(sum(cargo_only),0)::integer AS cargo_only,
 coalesce(sum(mixed),0)::integer AS mixed,
 CASE WHEN count(*)=23 AND sum(airports)=1118 AND sum(complete_game_profiles)=1118
 THEN 'game_complete_estimated' ELSE 'game_incomplete' END::text AS game_data_result,
 false AS source_verified_complete,false AS independently_verified_seasonality,
 false AS restrictions_cleared,false AS commercial_flight_access_enabled
FROM airlinerra_game.airport_group2_section7_batch_acceptance_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section7_overall_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT game_data_result FROM airlinerra_game.airport_group2_section7_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT estimated_demand_profiles FROM airlinerra_game.airport_group2_section7_overall_status_v1)<>1118
 OR (SELECT passenger_only FROM airlinerra_game.airport_group2_section7_overall_status_v1)<>953
 OR (SELECT cargo_only FROM airlinerra_game.airport_group2_section7_overall_status_v1)<>43
 OR (SELECT mixed FROM airlinerra_game.airport_group2_section7_overall_status_v1)<>122
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section7_batch_completion_v1
 WHERE (batch_number<23 AND airports<>50) OR (batch_number=23 AND airports<>18))
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section7_game_registry_v1
 WHERE NOT section7_game_data_complete OR commercially_admitted OR live_flight_authorized)
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_SECTION7_GAME_ACCEPTANCE_FAILED'; END IF;
END $$;