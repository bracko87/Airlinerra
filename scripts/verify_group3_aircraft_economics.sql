-- Airlinerra Group 3: 39-aircraft research economics and passenger popularity test.
-- Estimates are game-balancing inputs only; this script never enables aircraft sale/lease/flight.
DO $verify$
DECLARE n bigint;
BEGIN
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1;
 IF n<>39 THEN RAISE EXCEPTION 'Group 3 economics must have 39 records, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economy_readiness_v1
 WHERE has_complete_research_economic_game_fields;
 IF n<>39 THEN RAISE EXCEPTION 'Only %/39 aircraft have complete game economy data',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economy_readiness_v1
 WHERE use_type IN ('passenger','combi')
 AND passenger_popularity_score BETWEEN 1 AND 6
 AND passenger_demand_multiplier BETWEEN 0.60 AND 1.30;
 IF n<>31 THEN RAISE EXCEPTION 'Only %/31 passenger/combi have valid 1–6 popularity data',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economy_readiness_v1
 WHERE use_type='cargo'
 AND passenger_popularity_score IS NULL
 AND passenger_demand_multiplier IS NULL;
 IF n<>8 THEN RAISE EXCEPTION 'Cargo-only aircraft popularity should be N/A, found %/8',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3 g
 JOIN airlinerra_game.aircraft_passenger_popularity_v1 pop ON pop.configuration_id=g.configuration_id
 WHERE g.use_type='cargo';
 IF n<>0 THEN RAISE EXCEPTION 'Cargo passenger popularity was mistakenly assigned to % entries',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1
 WHERE total_reference_operating_cost_excluding_lease_usd_per_flight_hour
 IS DISTINCT FROM maintenance_reserve_usd_per_flight_hour
 +crew_and_cabin_usd_per_flight_hour+insurance_and_other_usd_per_flight_hour
 +fuel_cost_at_assumed_price_usd_per_flight_hour
 OR fuel_cost_at_assumed_price_usd_per_flight_hour
 IS DISTINCT FROM ROUND(estimated_cruise_fuel_kg_per_hour*fuel_price_assumption_usd_per_kg,2);
 IF n<>0 THEN RAISE EXCEPTION 'Fuel/maintenance/cost totals inconsistent for % models',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1 e
 JOIN airlinerra.aircraft_expansion_group3_planning_seed s USING(entry_no)
 WHERE e.estimated_cruise_fuel_kg_per_hour IS DISTINCT FROM s.burn_kg_h;
 IF n<>0 THEN RAISE EXCEPTION 'Fuel burn mismatched between finance and performance for % models',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1 e
 JOIN airlinerra.aircraft_technical_specs t ON t.configuration_id=e.configuration_id AND t.spec_label='base'
 WHERE t.expected_service_life_years IS DISTINCT FROM e.expected_economic_service_life_years
 OR t.limit_flight_hours IS DISTINCT FROM e.reference_airframe_utilization_life_hours
 OR t.limit_flight_cycles IS DISTINCT FROM e.reference_economic_lifetime_cycles;
 IF n<>0 THEN RAISE EXCEPTION 'Service life and economic aircraft wear limits mismatch on %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1
 WHERE game_model_reference_acquisition_usd<=0 OR game_model_monthly_lease_usd<=0
 OR maintenance_reserve_usd_per_flight_hour<=0
 OR total_reference_operating_cost_excluding_lease_usd_per_flight_hour<=0
 OR currency_code<>'USD' OR price_basis_year<>2026
 OR financing_data_class<>'GAME_ECONOMICS_ESTIMATE_NOT_BANK_OR_LESSOR_QUOTE';
 IF n<>0 THEN RAISE EXCEPTION 'Invalid finance reference data on % models',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1
 WHERE published_benchmark_price_usd IS NOT NULL
 AND (published_benchmark_price_year IS NULL
 OR published_benchmark_source_url IS NULL
 OR published_benchmark_aircraft_model IS NULL
 OR published_benchmark_is_exact_group3_aircraft_price);
 IF n<>0 THEN RAISE EXCEPTION 'Unlabeled or misleading real-world price benchmarks on % entries',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1
 WHERE published_benchmark_source_url IS NOT NULL;
 IF n<>10 THEN RAISE EXCEPTION 'Expect 10 separately dated source-backed family/model price benchmark rows, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1
 WHERE game_model_used_aircraft_usd IS NULL AND entry_no IN(2,20,24,25,27);
 IF n<>5 THEN RAISE EXCEPTION 'Future/unlaunched or unconfirmed aircraft must lack used-sale quotes'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economy_readiness_v1
 WHERE unavailable_until_release_or_model_year_verified AND entry_no IN(2,20,24,25,27);
 IF n<>5 THEN RAISE EXCEPTION 'Availability locks for undeployed aircraft are incomplete'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economics_v1
 WHERE approved_for_live_sale OR approved_for_live_leasing OR approved_for_live_operating_costs;
 IF n<>0 THEN RAISE EXCEPTION 'Research estimate incorrectly activated for % aircraft',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economy_readiness_v1
 WHERE pricing_engine_live OR aircraft_market_purchase_enabled OR aircraft_leasing_enabled
 OR operating_cost_engine_live;
 IF n<>0 THEN RAISE EXCEPTION 'Live game economics incorrectly enabled for % aircraft',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_release_gate_v1
 WHERE game_aircraft_orderable OR game_flight_operations_enabled OR automatically_released;
 IF n<>0 THEN RAISE EXCEPTION 'Group 3 aircraft gameplay release unexpectedly enabled'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economy_readiness_v1
 WHERE entry_no=2 AND passenger_popularity_score=6
 AND passenger_demand_multiplier=1.30;
 IF n<>1 THEN RAISE EXCEPTION 'A350-1000ULR premium passenger popularity estimate missing'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_economy_readiness_v1
 WHERE entry_no=25 AND passenger_popularity_score=5 AND game_model_used_aircraft_usd IS NULL;
 IF n<>1 THEN RAISE EXCEPTION 'D328eco future price and popularity assumptions incorrect'; END IF;
END $verify$;
SELECT 'GROUP3_39_ECONOMICS_AND_POPULARITY_TESTS_PASSED' AS result;
