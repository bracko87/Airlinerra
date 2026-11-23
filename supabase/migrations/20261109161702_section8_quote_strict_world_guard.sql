-- Strict null/world isolation for non-posting Section 8 quote.
-- Do not edit the already-applied historical migration; replace only this
-- function using an idempotent follow-on migration.
CREATE OR REPLACE FUNCTION airlinerra_game.section8_quote_flight_operating_fees_v1(
 p_world smallint,
 p_origin_airport_key text,
 p_destination_airport_key text,
 p_configuration_id bigint,
 p_departure_stand_type text,
 p_arrival_stand_type text,
 p_departing_passengers integer,
 p_cargo_tonnes numeric,
 p_arrival_parking_minutes integer
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path=pg_catalog,airlinerra_game,airlinerra
AS $quote$
DECLARE o record; d record; v_ac record; v_service record; v_policy record;
 v_gc numeric; v_h numeric; v_mass numeric; v_nav_mass numeric;
 v_origin_stand numeric;v_destination_stand numeric;
 v_departure numeric;v_arrival numeric;v_handling numeric;v_parking numeric;
 v_terminal_atc numeric;v_enroute_atc numeric;v_passenger numeric;
 v_security numeric;v_border numeric;v_cargo_out numeric;v_cargo_in numeric;
 v_total numeric;v_international boolean; v_aircraft_capacity integer;
 v_cargo_capacity_kg numeric;
BEGIN
 IF p_world IS DISTINCT FROM 1 OR p_origin_airport_key IS NULL OR
    p_destination_airport_key IS NULL OR
    p_origin_airport_key=p_destination_airport_key OR
    p_configuration_id IS NULL OR
    p_departure_stand_type IS NULL OR
    p_departure_stand_type NOT IN ('terminal','remote','cargo') OR
    p_arrival_stand_type IS NULL OR
    p_arrival_stand_type NOT IN ('terminal','remote','cargo') OR
    p_departing_passengers IS NULL OR p_departing_passengers<0 OR
    p_departing_passengers>1000 OR p_cargo_tonnes IS NULL OR
    p_cargo_tonnes<0 OR p_cargo_tonnes>500 OR
    p_arrival_parking_minutes IS NULL OR
    p_arrival_parking_minutes<0 OR p_arrival_parking_minutes>44640
 THEN RAISE EXCEPTION 'SECTION8_INVALID_FLIGHT_COST_PREVIEW_ARGUMENTS'
 USING ERRCODE='22023'; END IF;

 SELECT t.*,p.country_iso,p.latitude_deg,p.longitude_deg,
    s.terminal_stands,s.remote_stands,s.cargo_stands
 INTO o FROM airlinerra_game.section8_airport_operating_tariffs_v1 t
 JOIN airlinerra_game.airport_reference_profiles p
  ON p.world_id=t.world_id AND p.airport_key=t.airport_key
 JOIN airlinerra_game.section6_airport_slot_capacity_v1 s
  ON s.world_id=t.world_id AND s.airport_key=t.airport_key
 WHERE t.world_id=1 AND t.airport_key=p_origin_airport_key;
 SELECT t.*,p.country_iso,p.latitude_deg,p.longitude_deg,
    s.terminal_stands,s.remote_stands,s.cargo_stands
 INTO d FROM airlinerra_game.section8_airport_operating_tariffs_v1 t
 JOIN airlinerra_game.airport_reference_profiles p
  ON p.world_id=t.world_id AND p.airport_key=t.airport_key
 JOIN airlinerra_game.section6_airport_slot_capacity_v1 s
  ON s.world_id=t.world_id AND s.airport_key=t.airport_key
 WHERE t.world_id=1 AND t.airport_key=p_destination_airport_key;
 IF o.airport_key IS NULL OR d.airport_key IS NULL OR
   o.latitude_deg IS NULL OR o.longitude_deg IS NULL OR
   d.latitude_deg IS NULL OR d.longitude_deg IS NULL OR
   o.country_iso IS NULL OR d.country_iso IS NULL THEN
  RAISE EXCEPTION 'SECTION8_NO_VERIFIED_GAME_AIRPORT_GEOMETRY'
   USING ERRCODE='22023';END IF;

 IF (p_departure_stand_type='terminal' AND o.terminal_stands=0)
 OR (p_departure_stand_type='remote' AND o.remote_stands=0)
 OR (p_departure_stand_type='cargo' AND o.cargo_stands=0)
 OR (p_arrival_stand_type='terminal' AND d.terminal_stands=0)
 OR (p_arrival_stand_type='remote' AND d.remote_stands=0)
 OR (p_arrival_stand_type='cargo' AND d.cargo_stands=0)
 OR (p_departing_passengers>0
 AND (p_departure_stand_type='cargo' OR p_arrival_stand_type='cargo'))
 THEN RAISE EXCEPTION 'SECTION8_STAND_NOT_COMPATIBLE_WITH_GAME_AIRPORT'
 USING ERRCODE='22023';END IF;

 SELECT configuration_id,mtow_kg,model_name,reference_passenger_capacity,
   maximum_cargo_payload_kg INTO v_ac
 FROM airlinerra.aircraft_catalog_configuration_inventory
 WHERE configuration_id=p_configuration_id;
 IF v_ac.configuration_id IS NULL OR v_ac.mtow_kg IS NULL OR v_ac.mtow_kg<=0
 THEN RAISE EXCEPTION 'SECTION8_NO_TRUSTED_GAME_AIRCRAFT_MASS'
 USING ERRCODE='22023';END IF;
 SELECT simultaneous_passenger_seats,simultaneous_freight_kg
 INTO v_service FROM airlinerra.aircraft_service_payload_game_v1
 WHERE configuration_id=p_configuration_id;
 v_aircraft_capacity:=coalesce(v_service.simultaneous_passenger_seats,
    v_ac.reference_passenger_capacity,0);
 v_cargo_capacity_kg:=coalesce(v_service.simultaneous_freight_kg,
    v_ac.maximum_cargo_payload_kg,0);
 IF p_departing_passengers>v_aircraft_capacity OR
   p_cargo_tonnes*1000>v_cargo_capacity_kg
 THEN RAISE EXCEPTION 'SECTION8_PREVIEW_EXCEEDS_CATALOG_AIRCRAFT_CAPACITY'
 USING ERRCODE='22023';END IF;

 SELECT * INTO v_policy
 FROM airlinerra_game.section8_airspace_navigation_policy_v1
 WHERE world_id=1;
 IF v_policy.tariff_model_version IS NULL
 THEN RAISE EXCEPTION 'SECTION8_NAVIGATION_GAME_POLICY_MISSING';END IF;

 v_origin_stand:=CASE p_departure_stand_type
  WHEN 'terminal' THEN o.terminal_stand_multiplier
  WHEN 'remote' THEN o.remote_stand_multiplier
  ELSE o.cargo_stand_multiplier END;
 v_destination_stand:=CASE p_arrival_stand_type
  WHEN 'terminal' THEN d.terminal_stand_multiplier
  WHEN 'remote' THEN d.remote_stand_multiplier
  ELSE d.cargo_stand_multiplier END;
 -- Airport's original USD landing fee is the category/background game
 -- reference for a 70-tonne aircraft. MTOW is read from server catalogue.
 v_mass:=greatest(.35::numeric,least(3.50::numeric,
   round(sqrt((v_ac.mtow_kg::numeric/70000)::double precision)::numeric,4)));
 v_nav_mass:=round(sqrt((v_ac.mtow_kg::numeric/50000)::double precision)::numeric,5);
 -- Haversine on persisted GAME coordinates; not an actual FIR route.
 v_h:=power(sin(radians((d.latitude_deg-o.latitude_deg)::double precision)/2),2)+
 cos(radians(o.latitude_deg::double precision))*
 cos(radians(d.latitude_deg::double precision))*
 power(sin(radians((d.longitude_deg-o.longitude_deg)::double precision)/2),2);
 v_gc:=round((6371*2*asin(sqrt(greatest(0::double precision,
     least(1::double precision,v_h::double precision)))))::numeric,2);
 v_international:=o.country_iso<>d.country_iso;

 v_departure:=round(o.landing_base_for_reference_aircraft_usd*
   o.departure_movement_fraction*v_mass,2);
 v_arrival:=round(d.landing_base_for_reference_aircraft_usd*v_mass,2);
 v_handling:=round(o.landing_base_for_reference_aircraft_usd*
   o.ground_handling_fraction*v_mass*v_origin_stand*
   o.new_service_background_factor,2);
 v_parking:=round(d.remote_parking_reference_per_day_usd*
   v_destination_stand*v_mass*d.new_service_background_factor*
   greatest(0,p_arrival_parking_minutes-v_policy.free_parking_minutes)/1440.0,2);
 v_terminal_atc:=round(o.terminal_navigation_unit_usd*
   power((v_ac.mtow_kg::numeric/50000),0.7::numeric),2);
 v_enroute_atc:=round(v_policy.route_charge_per_100km_at_50t_usd*
  v_nav_mass*greatest(0::numeric,
    v_gc-v_policy.terminal_excluded_distance_km)/100,2);
 v_passenger:=round(p_departing_passengers*
   o.passenger_facility_per_departure_usd,2);
 v_security:=round(p_departing_passengers*
   o.security_per_departing_passenger_usd,2);
 v_border:=CASE WHEN v_international
  THEN round(p_departing_passengers*
   o.international_processing_per_departing_passenger_usd,2)
  ELSE 0::numeric END;
 v_cargo_out:=round(p_cargo_tonnes*o.cargo_handling_per_tonne_usd,2);
 v_cargo_in:=round(p_cargo_tonnes*d.cargo_handling_per_tonne_usd,2);
 v_total:=v_departure+v_arrival+v_handling+v_parking+
   v_terminal_atc+v_enroute_atc+v_passenger+v_security+
   v_border+v_cargo_out+v_cargo_in;
 RETURN jsonb_build_object(
  'status','game_operating_fee_preview_only',
  'worldId',1,'modelVersion',v_policy.tariff_model_version,
  'currency','USD','fuelIncluded',false,
  'cashPosted',false,'canPostToLedger',false,
  'isOfficialAviationTariff',false,
  'operationAuthorized',false,
  'originAirportKey',o.airport_key,
  'destinationAirportKey',d.airport_key,
  'originCategory',o.game_category,
  'destinationCategory',d.game_category,
  'originBackground',o.game_airport_background,
  'destinationBackground',d.game_airport_background,
  'aircraftConfigurationId',v_ac.configuration_id,
  'aircraftModel',v_ac.model_name,
  'aircraftMtowKg',v_ac.mtow_kg,
  'departureStand',p_departure_stand_type,
  'arrivalStand',p_arrival_stand_type,
  'passengers',p_departing_passengers,
  'cargoTonnes',p_cargo_tonnes,
  'arrivalParkingMinutes',p_arrival_parking_minutes,
  'freeParkingMinutes',v_policy.free_parking_minutes,
  'greatCircleDistanceKm',v_gc,
  'gameDistanceForAirspaceBillingKm',greatest(0::numeric,
    v_gc-v_policy.terminal_excluded_distance_km),
  'international',v_international,
  'fees',jsonb_build_object(
   'departureAirportMovementUsd',v_departure,
   'arrivalLandingUsd',v_arrival,
   'departureGroundHandlingUsd',v_handling,
   'arrivalStandParkingUsd',v_parking,
   'departureTerminalAirTrafficControlUsd',v_terminal_atc,
   'enrouteAirTrafficControlUsd',v_enroute_atc,
   'departingPassengerFacilityUsd',v_passenger,
   'departingPassengerSecurityUsd',v_security,
   'internationalPassengerProcessingUsd',v_border,
   'originCargoHandlingUsd',v_cargo_out,
   'destinationCargoHandlingUsd',v_cargo_in
  ),
  'totalGameOperatingFeesUsd',v_total,
  'unpricedItems',jsonb_build_array(
    'fuel_and_refuelling','conditional_deicing','aircraft_maintenance',
    'crew_salary','real_country_airspace_tarrifs','taxes_and_optional_services'),
  'costBasis','airlinerra_game_model_only',
  'note','No money is charged by this quote. Final actual-flight fees require separately verified operated-flight data and Section 9 settlement.'
 );
END $quote$;

DO $test$
DECLARE denied boolean;
BEGIN
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section8_quote_flight_operating_fees_v1(
   NULL::smallint,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,
   'terminal','terminal',100,0::numeric,180);
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'NULL_WORLD_MUST_NOT_BECOME_WORLD1';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section8_quote_flight_operating_fees_v1(
   2::smallint,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,
   'terminal','terminal',100,0::numeric,180);
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'WRONG_WORLD_MUST_NOT_BECOME_WORLD1';END IF;
 IF (SELECT (airlinerra_game.section8_quote_flight_operating_fees_v1(
  1::smallint,'OURAIRPORTS:2212','OURAIRPORTS:4013',2,
  'terminal','terminal',100,0::numeric,180)->>'cashPosted')::boolean)
 THEN RAISE EXCEPTION 'FEE_QUOTE_MUST_NOT_POST_MONEY';END IF;
END $test$;
