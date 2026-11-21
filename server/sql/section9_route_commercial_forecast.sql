BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_route_commercial_forecast_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_origin text,p_destination text,
 p_depart_stand text,p_arrive_stand text,p_parking int,p_load_percent int,p_economy_fare numeric)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog' AS $fn$
DECLARE f record;phases jsonb;fuel jsonb;fees jsonb;capacity int;passengers int;
 price numeric;fuel_cost numeric;fee_cost numeric;income numeric;total numeric;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_ROUTE_FORECAST_ONLY';END IF;
 IF p_origin IS NULL OR p_destination IS NULL OR p_origin=p_destination
 OR p_load_percent IS NULL OR p_load_percent NOT BETWEEN 0 AND 100
 OR p_parking IS NULL OR p_parking NOT BETWEEN 0 AND 10080
 OR p_economy_fare IS NOT NULL AND p_economy_fare NOT BETWEEN 0 AND 100000
 THEN RETURN jsonb_build_object('status','invalid_route_forecast','readOnly',true,'ledgerPosted',false);END IF;
 SELECT i.configuration_id,c.use_type,c.maximum_passenger_seats,p.simultaneous_passenger_seats INTO f
 FROM airlinerra_game.airline_aircraft_inventory i
 JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 JOIN airlinerra.aircraft_configurations c ON c.id=i.configuration_id
 JOIN airlinerra.aircraft_service_payload_game_v1 p ON p.configuration_id=i.configuration_id
 WHERE i.id=p_aircraft AND i.airline_id=p_airline AND i.fleet_status='in_service' AND i.ownership_type IN ('owned','leased');
 IF NOT FOUND OR f.use_type<>'passenger' OR p_depart_stand NOT IN ('terminal','remote') OR p_arrive_stand NOT IN ('terminal','remote')
 THEN RETURN jsonb_build_object('status','unsupported_or_unowned_aircraft','readOnly',true,'ledgerPosted',false);END IF;
 capacity:=least(1000,f.maximum_passenger_seats,f.simultaneous_passenger_seats);
 IF capacity IS NULL OR capacity<=0 THEN RETURN jsonb_build_object('status','capacity_unavailable','readOnly',true,'ledgerPosted',false);END IF;
 passengers:=round(capacity::numeric*p_load_percent/100)::int;
 phases:=airlinerra_game.section9_game_route_phase_profile_v1(f.configuration_id,p_origin,p_destination,NULL);
 IF phases IS NULL THEN RETURN jsonb_build_object('status','phase_profile_unavailable','readOnly',true,'ledgerPosted',false);END IF;
 fuel:=airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(f.configuration_id,round(passengers::numeric/capacity*100,2),
 (phases->>'taxiOutMinutes')::int,(phases->>'climbMinutes')::int,(phases->>'cruiseMinutes')::int,(phases->>'descentMinutes')::int,(phases->>'taxiInMinutes')::int);
 fees:=airlinerra_game.section9_game_itemized_airport_fee_quote_v1(p_origin,p_destination,p_depart_stand,p_arrive_stand,passengers,p_parking,0);
 SELECT min(fuel_price_assumption_usd_per_kg) INTO price FROM airlinerra.aircraft_expansion_group3_economics_v1 WHERE fuel_price_assumption_usd_per_kg>0;
 IF price IS NULL OR EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3_economics_v1 WHERE fuel_price_assumption_usd_per_kg IS DISTINCT FROM price)
 OR fuel->>'status' IS DISTINCT FROM 'game_reserve_aware_fuel_estimate_only'
 OR fees->>'status' IS DISTINCT FROM 'game_airport_fee_breakdown_estimate_only'
 THEN RETURN jsonb_build_object('status','fare_or_cost_model_unavailable','readOnly',true,'ledgerPosted',false);END IF;
 fuel_cost:=round((fuel->>'tripBurnKg')::numeric*price,2);fee_cost:=(fees->>'totalFeeEstimateUsd')::numeric;
 total:=fuel_cost+fee_cost;income:=passengers*p_economy_fare;
 RETURN jsonb_build_object('status','route_phase1_forecast','worldId',1,'airlineId',p_airline,'aircraftInventoryId',p_aircraft,
 'originAirportKey',p_origin,'destinationAirportKey',p_destination,'readOnly',true,'ledgerPosted',false,
 'loadPercent',p_load_percent,'passengerCapacity',capacity,'estimatedPassengers',passengers,'economyFareUsd',p_economy_fare,
 'phases',phases,'fuel',fuel,'fuelPriceUsdPerKg',price,'fuelCostUsd',fuel_cost,'airportFeesUsd',fee_cost,'feeLinesUsd',fees->'feeLinesUsd',
 'directOperatingCostUsd',total,'ticketIncomeUsd',income,'estimatedDirectProfitUsd',income-total,
 'overheadsExcluded',jsonb_build_array('crew (deferred Phase 1)','separately booked maintenance','ownership or lease overhead','additional cabin or cargo services'));
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_route_commercial_forecast_v1(uuid,uuid,uuid,text,text,text,text,int,int,numeric) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
