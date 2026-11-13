-- Versioned private Airlinerra game-only five-phase fuel estimate.
-- Phase coefficients are UNVERIFIED game assumptions, not aircraft reference rates.
-- No aircraft changes, fuel charges, flight execution, bookings or release flags.
BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_five_phase_fuel_quote_v1(p_configuration_id bigint, p_load_percent numeric, p_taxi_out_minutes integer, p_climb_minutes integer, p_cruise_minutes integer, p_descent_minutes integer, p_taxi_in_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 m record;
 rate_per_100km numeric;
 cruise_kg_hour numeric;
 taxi_out_kg numeric;
 climb_kg numeric;
 cruise_kg numeric;
 descent_kg numeric;
 taxi_in_kg numeric;
 total_kg numeric;
 total_minutes integer;
BEGIN
 IF p_configuration_id IS NULL OR p_configuration_id <= 0
   OR p_load_percent IS NULL OR p_load_percent < 0 OR p_load_percent > 100
   OR p_taxi_out_minutes IS NULL OR p_taxi_out_minutes < 0 OR p_taxi_out_minutes > 180
   OR p_climb_minutes IS NULL OR p_climb_minutes < 0 OR p_climb_minutes > 180
   OR p_cruise_minutes IS NULL OR p_cruise_minutes < 1 OR p_cruise_minutes > 1800
   OR p_descent_minutes IS NULL OR p_descent_minutes < 0 OR p_descent_minutes > 180
   OR p_taxi_in_minutes IS NULL OR p_taxi_in_minutes < 0 OR p_taxi_in_minutes > 180
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_FUEL_QUOTE_INPUT'; END IF;

 total_minutes := p_taxi_out_minutes+p_climb_minutes+p_cruise_minutes+
   p_descent_minutes+p_taxi_in_minutes;
 IF total_minutes > 1800 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_FUEL_QUOTE_DURATION_EXCEEDS_GAME_LIMIT'; END IF;

 SELECT * INTO m
 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=p_configuration_id
   AND model_version='AIRLINERRA_FIVE_PHASE_FUEL_GAME_V1_2026_11_12';
 IF NOT FOUND THEN
   RETURN jsonb_build_object('status','model_not_found',
     'configurationId',p_configuration_id,'previewOnly',true,
     'dispatchApproved',false,'accountingApproved',false,
     'fuelChargeUsd',NULL,'totalKg',NULL);
 END IF;
 IF m.game_calculation_ready IS DISTINCT FROM true
   OR m.tank_capacity_kg IS NULL THEN
   RETURN jsonb_build_object('status','model_incomplete',
     'configurationId',p_configuration_id,'modelVersion',m.model_version,
     'sourceKind',m.model_source_kind,'confidence',m.model_confidence_class,
     'missingInputs',jsonb_build_array('tank_capacity_kg'),
     'previewOnly',true,'dispatchApproved',false,
     'accountingApproved',false,'fuelChargeUsd',NULL,'totalKg',NULL);
 END IF;

 IF p_load_percent<=50 THEN
   rate_per_100km := m.empty_kg_per_100km+
      (m.half_kg_per_100km-m.empty_kg_per_100km)*p_load_percent/50;
 ELSE
   rate_per_100km := m.half_kg_per_100km+
      (m.full_kg_per_100km-m.half_kg_per_100km)*(p_load_percent-50)/50;
 END IF;
 cruise_kg_hour:=rate_per_100km*m.cruise_speed_kmh/100;
 -- These are provisional GAME multipliers (NOT manufacturer phase burn rates).
 -- Do not use them for actual dispatch, refuelling, or financial posting.
 taxi_out_kg:=round(cruise_kg_hour*0.18*p_taxi_out_minutes/60,2);
 climb_kg:=round(cruise_kg_hour*1.35*p_climb_minutes/60,2);
 cruise_kg:=round(cruise_kg_hour*p_cruise_minutes/60,2);
 descent_kg:=round(cruise_kg_hour*0.40*p_descent_minutes/60,2);
 taxi_in_kg:=round(cruise_kg_hour*0.18*p_taxi_in_minutes/60,2);
 total_kg:=taxi_out_kg+climb_kg+cruise_kg+descent_kg+taxi_in_kg;
 RETURN jsonb_build_object(
   'status','game_estimate_only',
   'configurationId',p_configuration_id,
   'modelVersion',m.model_version,
   'sourceKind',m.model_source_kind,
   'confidence',m.model_confidence_class,
   'phaseCoefficientBasis','GAME_ASSUMPTION_V1_UNVERIFIED_NOT_AIRCRAFT_SPECIFIC',
   'rateAtChosenLoadKgPer100Km',round(rate_per_100km,2),
   'loadPercentAssumption',p_load_percent,
   'durationMinutes',total_minutes,
   'phaseMinutes',jsonb_build_object(
       'taxiOut',p_taxi_out_minutes,'climb',p_climb_minutes,
       'cruise',p_cruise_minutes,'descent',p_descent_minutes,
       'taxiIn',p_taxi_in_minutes),
   'phaseKg',jsonb_build_object(
       'taxiOut',taxi_out_kg,'climb',climb_kg,
       'cruise',cruise_kg,'descent',descent_kg,'taxiIn',taxi_in_kg),
   'totalKg',total_kg,
   'tankCapacityKg',m.tank_capacity_kg,
   'withinModelTankWithoutReserve',total_kg<=m.tank_capacity_kg,
   'reserveFuelIncluded',false,
   'previewOnly',true,'dispatchApproved',false,
   'accountingApproved',false,'fuelChargeUsd',NULL,
   'flightCreated',false,'ledgerPosted',false
 );
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_game_five_phase_fuel_quote_v1(bigint,numeric,integer,integer,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION airlinerra_game.section9_game_five_phase_fuel_quote_v1(bigint,numeric,integer,integer,integer,integer,integer) IS 'Private read-only five-phase game estimate with explicit unverified phase coefficients. No route authorization, fuel dispatch, reserve, or financial posting.';
COMMIT;
