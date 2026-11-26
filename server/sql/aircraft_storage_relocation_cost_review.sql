-- REVIEW ONLY: zero-payload storage relocation estimates. No dispatch or posting.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_relocation_tariffs_v1 (
 world_id smallint NOT NULL CHECK(world_id=1), airport_key text NOT NULL,
 remote_parking_per_day_usd numeric(14,2) NOT NULL CHECK(remote_parking_per_day_usd>=0),
 departure_ground_handling_usd numeric(14,2) NOT NULL CHECK(departure_ground_handling_usd>=0),
 terminal_navigation_usd numeric(14,2) NOT NULL CHECK(terminal_navigation_usd>=0),
 tariff_reference text NOT NULL CHECK(btrim(tariff_reference)<>''),
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_airport_operational_profiles_v1(world_id,airport_key)
);
ALTER TABLE airlinerra_game.aircraft_storage_relocation_tariffs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_relocation_tariffs_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.aircraft_storage_relocation_fee_endpoint_v1(p_key text,p_storage boolean)
RETURNS TABLE(landing numeric,departure numeric,handling numeric,parking_per_day numeric,navigation numeric,tariff_reference text)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT p.landing_fee_usd,p.departure_fee_usd,t.departure_ground_handling_usd,t.remote_parking_per_day_usd,t.terminal_navigation_usd,t.tariff_reference
 FROM airlinerra_game.aircraft_storage_facilities_v1 f
 JOIN airlinerra_game.aircraft_storage_airport_operational_profiles_v1 p USING(world_id,airport_key)
 JOIN airlinerra_game.aircraft_storage_relocation_tariffs_v1 t USING(world_id,airport_key)
 WHERE current_user='postgres' AND p_storage IS TRUE AND f.world_id=1 AND f.airport_key=p_key
 AND f.review_state='approved' AND f.admission_scope='relocation_only'
 UNION ALL
 SELECT t.landing_base_for_reference_aircraft_usd,
 round(t.landing_base_for_reference_aircraft_usd*t.departure_movement_fraction,2),
 round(t.landing_base_for_reference_aircraft_usd*t.ground_handling_fraction*t.remote_stand_multiplier,2),
 t.remote_parking_reference_per_day_usd*t.remote_stand_multiplier,
 t.terminal_navigation_unit_usd,t.price_model_version::text
 FROM airlinerra_game.section8_airport_operating_tariffs_v1 t
 JOIN airlinerra_game.airport_unified_operations_v1 u USING(world_id,airport_key)
 WHERE current_user='postgres' AND t.world_id=1 AND t.airport_key=p_key
 AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission
 AND t.evidence_class='GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'
 AND t.remote_stand_multiplier>0
 AND (p_storage IS FALSE OR (p_storage IS TRUE AND EXISTS(
 SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 f
 WHERE f.world_id=t.world_id AND f.airport_key=t.airport_key AND f.review_state='approved' AND f.admission_scope='existing_commercial')));
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_relocation_fee_endpoint_v1(text,boolean) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.aircraft_storage_relocation_cost_v1(p_configuration bigint,p_origin text,p_destination text,p_purpose text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE phases jsonb; fuel jsonb; o record; d record; price numeric; burn numeric; fees numeric; lines jsonb; fuel_cost numeric;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 phases:=airlinerra_game.aircraft_storage_route_phase_profile_v1(p_configuration,p_origin,p_destination,p_purpose);
 IF phases IS NULL THEN RETURN jsonb_build_object('status','storage_phase_unavailable','bookable',false);END IF;
 SELECT * INTO o FROM airlinerra_game.aircraft_storage_relocation_fee_endpoint_v1(p_origin,p_purpose='storage_reactivation');
 SELECT * INTO d FROM airlinerra_game.aircraft_storage_relocation_fee_endpoint_v1(p_destination,p_purpose='storage_inbound');
 IF o.departure IS NULL OR o.handling IS NULL OR o.navigation IS NULL OR d.landing IS NULL OR d.parking_per_day IS NULL OR d.navigation IS NULL
 OR least(o.departure,o.handling,o.navigation,d.landing,d.parking_per_day,d.navigation)<0
 OR o.tariff_reference IS NULL OR d.tariff_reference IS NULL
 THEN RETURN jsonb_build_object('status','storage_tariff_unavailable','bookable',false,'phases',phases);END IF;
 fuel:=airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(p_configuration,0,
 (phases->>'taxiOutMinutes')::int,(phases->>'climbMinutes')::int,(phases->>'cruiseMinutes')::int,
 (phases->>'descentMinutes')::int,(phases->>'taxiInMinutes')::int);
 SELECT min(fuel_price_assumption_usd_per_kg) INTO price FROM airlinerra.aircraft_expansion_group3_economics_v1 WHERE fuel_price_assumption_usd_per_kg>0;
 IF price IS NULL OR EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3_economics_v1 WHERE fuel_price_assumption_usd_per_kg IS DISTINCT FROM price)
 OR fuel->>'status' IS DISTINCT FROM 'game_reserve_aware_fuel_estimate_only' OR fuel->>'tripBurnKg' IS NULL
 THEN RETURN jsonb_build_object('status','storage_fuel_model_unavailable','bookable',false,'phases',phases);END IF;
 burn:=(fuel->>'tripBurnKg')::numeric;
 IF burn<0 THEN RETURN jsonb_build_object('status','storage_fuel_invalid','bookable',false);END IF;
 fuel_cost:=round(burn*price,2);
 lines:=jsonb_build_object('departureAirportMovementUsd',round(o.departure,2),'arrivalLandingUsd',round(d.landing,2),
 'departureGroundHandlingUsd',round(o.handling,2),'arrivalStandParkingUsd',round(d.parking_per_day*45/1440,2),
 'departureTerminalAirTrafficControlUsd',round(o.navigation+d.navigation,2),
 'enrouteAirTrafficControlUsd',round((o.navigation+d.navigation)*0.35,2));
 SELECT sum(value::numeric) INTO fees FROM jsonb_each_text(lines);
 RETURN jsonb_build_object('status','storage_relocation_cost_estimate','bookable',false,'phases',phases,'fuel',fuel,
 'fuelRangeConfirmed',coalesce(fuel->>'withinGameTankIncludingReserve'='true',false),'fuelCostUsd',fuel_cost,
 'airportFeesUsd',fees,'feeLinesUsd',lines,'directOperatingCostUsd',fees+fuel_cost,
 'originTariffReference',o.tariff_reference,'destinationTariffReference',d.tariff_reference,
 'passengers',0,'cargoTonnes',0,'ticketRevenueUsd',0,'storageCapacityUnlimited',true,
 'ledgerPosted',false,'dispatchAuthorized',false,'excludesCrewAndMonthlyStorage',true);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_relocation_cost_v1(bigint,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
