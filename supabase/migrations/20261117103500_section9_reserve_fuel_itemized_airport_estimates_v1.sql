-- Airlinerra World 1 - GAME ESTIMATES ONLY; NOT a flight or money release.
-- Use existing provisional A319 distance-rate and five-phase fuel model.
-- ADD 5% trip contingency plus 45-minute reserve at 60% game cruise burn.
-- Reserve protects plan/tank capacity and is NOT charged as consumed fuel.
-- This is not regulatory diversion/alternate fuel and does not establish
-- actual on-board fuel or grant airworthiness/dispatch clearance.
-- Airport fees have all 11 separately itemized keys required by the final
-- approval schema. Reference-aircraft tariffs and 35%-enroute ATC proxy
-- are game mechanics, NOT actual airport or ATC invoices.
-- Both projections are read-only; after arrival the historic quoted ticket
-- revenue, fuel burn cost and airport fee total may be PREPARED (UNPOSTED).
-- All existing operational and financial release flags remain unchanged.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(p_configuration_id bigint, p_load_percent numeric, p_taxi_out_minutes integer, p_climb_minutes integer, p_cruise_minutes integer, p_descent_minutes integer, p_taxi_in_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 model record;
 existing jsonb;
 trip_kg numeric;
 rate_at_load numeric;
 cruise_hour_kg numeric;
 contingency_kg numeric;
 reserve_kg numeric;
 required_kg numeric;
 tank_kg numeric;
 reference_reserve_minutes integer:=45;
 reference_reserve_burn_factor numeric:=0.60;
 contingency_fraction numeric:=0.05;
BEGIN
 IF p_configuration_id IS NULL OR p_configuration_id<=0
 OR p_load_percent IS NULL OR p_load_percent NOT BETWEEN 0 AND 100
 OR p_taxi_out_minutes IS NULL OR p_taxi_out_minutes NOT BETWEEN 0 AND 180
 OR p_climb_minutes IS NULL OR p_climb_minutes NOT BETWEEN 0 AND 180
 OR p_cruise_minutes IS NULL OR p_cruise_minutes NOT BETWEEN 1 AND 1800
 OR p_descent_minutes IS NULL OR p_descent_minutes NOT BETWEEN 0 AND 180
 OR p_taxi_in_minutes IS NULL OR p_taxi_in_minutes NOT BETWEEN 0 AND 180
 THEN RETURN jsonb_build_object('status','invalid_game_fuel_quote_inputs',
  'readOnly',true,'dispatchApproved',false,'accountingApproved',false,
  'ledgerPosted',false);END IF;

 IF (p_taxi_out_minutes+p_climb_minutes+p_cruise_minutes+
     p_descent_minutes+p_taxi_in_minutes)>1800
 THEN RETURN jsonb_build_object('status','blocked_fuel_quote_duration_exceeds_game_limit',
   'readOnly',true,'dispatchApproved',false,'accountingApproved',false,
   'ledgerPosted',false);END IF;
 SELECT * INTO model FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=p_configuration_id;
 IF NOT FOUND OR model.game_calculation_ready IS DISTINCT FROM true
 OR model.tank_capacity_kg IS NULL OR model.tank_capacity_kg<=0
 OR model.cruise_speed_kmh IS NULL OR model.cruise_speed_kmh<=0
 OR model.empty_kg_per_100km IS NULL OR model.half_kg_per_100km IS NULL
 OR model.full_kg_per_100km IS NULL
 OR model.empty_kg_per_100km<=0 OR model.half_kg_per_100km<=0
 OR model.full_kg_per_100km<=0
 THEN RETURN jsonb_build_object('status','blocked_incomplete_fuel_model',
   'readOnly',true,'dispatchApproved',false,'accountingApproved',false,
   'ledgerPosted',false);END IF;
 existing:=airlinerra_game.section9_game_five_phase_fuel_quote_v1(
  p_configuration_id,p_load_percent,p_taxi_out_minutes,p_climb_minutes,
  p_cruise_minutes,p_descent_minutes,p_taxi_in_minutes);
 IF existing->>'status' IS DISTINCT FROM 'game_estimate_only'
 OR existing->>'dispatchApproved' IS DISTINCT FROM 'false'
 OR existing->>'accountingApproved' IS DISTINCT FROM 'false'
 OR existing->>'totalKg' IS NULL
 OR existing->>'modelVersion' IS DISTINCT FROM model.model_version
 THEN RETURN jsonb_build_object('status','blocked_noncomparable_legacy_fuel_quote',
  'readOnly',true,'dispatchApproved',false,'accountingApproved',false,
  'ledgerPosted',false);END IF;
 trip_kg:=(existing->>'totalKg')::numeric;
 tank_kg:=model.tank_capacity_kg;
 IF trip_kg<0 OR trip_kg>1000000 THEN
 RETURN jsonb_build_object('status','blocked_invalid_game_trip_burn',
 'readOnly',true,'dispatchApproved',false,'accountingApproved',false,
 'ledgerPosted',false);END IF;
 rate_at_load:=(existing->>'rateAtChosenLoadKgPer100Km')::numeric;
 cruise_hour_kg:=rate_at_load*model.cruise_speed_kmh/100;
 -- GAME-ONLY neutral reserve proxy. NOT manufacturer-certified,
 -- regulatory alternate/contingency dispatch planning or a refuel order.
 reserve_kg:=ceil(cruise_hour_kg*reference_reserve_burn_factor*
                    reference_reserve_minutes/60*100)/100;
 contingency_kg:=ceil(trip_kg*contingency_fraction*100)/100;
 required_kg:=trip_kg+contingency_kg+reserve_kg;
 RETURN jsonb_build_object(
  'status','game_reserve_aware_fuel_estimate_only',
  'modelVersion','GAME_FUEL_RESERVE_PROXY_V1_2026_11_17',
  'originalModelVersion',model.model_version,
  'sourceKind',model.model_source_kind,
  'modelConfidence',model.model_confidence_class,
  'configurationId',p_configuration_id,
  'aircraftModel',model.model_name,
  'tripBurnKg',round(trip_kg,2),
  'contingencyKg',round(contingency_kg,2),
  'holdingReserveKg',round(reserve_kg,2),
  'minimumPlannedFuelOnBoardKg',round(required_kg,2),
  'tankCapacityKg',tank_kg,
  'tankCapacityMarginKg',round(tank_kg-required_kg,2),
  'withinGameTankIncludingReserve',required_kg<=tank_kg,
  'referenceReserveMinutes',reference_reserve_minutes,
  'referenceReserveBurnFractionOfCruise',reference_reserve_burn_factor,
  'contingencyFractionOfTrip',contingency_fraction,
  'burnFuelCostBaseKg',round(trip_kg,2),
  'reserveConsumedOrBilledNow',false,
  'aircraftActualFuelOnBoardVerified',false,
  'alternateAirportFuelCalculated',false,
  'realWorldFlightReleaseVerified',false,
  'fuelInventoryMovementRecorded',false,
  'fuelPlanningReserveIncluded',true,
  'independentlyValidatedFlightFuel',false,
  'readOnly',true,'dispatchApproved',false,'accountingApproved',false,
  'flightCreated',false,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(bigint,numeric,integer,integer,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_itemized_airport_fee_quote_v1(p_origin_airport_key text, p_destination_airport_key text, p_departure_stand_type text, p_arrival_stand_type text, p_departing_passengers integer, p_turnaround_minutes integer, p_cargo_tonnes numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 origin_row record;dest_row record;
 origin_country text;dest_country text;
 origin_factor numeric;dest_factor numeric;
 item_lines jsonb;
 depart_movement numeric;arrival_landing numeric;
 depart_handling numeric;arrival_parking numeric;
 terminal_atc numeric;enroute_atc numeric;
 passenger_facility numeric;passenger_security numeric;
 international_passenger numeric;origin_cargo numeric;dest_cargo numeric;
 sum_cost numeric;
 cross_border boolean;
BEGIN
 IF p_origin_airport_key IS NULL OR p_destination_airport_key IS NULL
 OR p_origin_airport_key=p_destination_airport_key
 OR p_departure_stand_type NOT IN('terminal','remote','cargo')
 OR p_arrival_stand_type NOT IN('terminal','remote','cargo')
 OR p_departing_passengers IS NULL OR p_departing_passengers NOT BETWEEN 0 AND 1000
 OR p_turnaround_minutes IS NULL OR p_turnaround_minutes NOT BETWEEN 15 AND 360
 OR p_cargo_tonnes IS NULL OR p_cargo_tonnes NOT BETWEEN 0 AND 1000
 THEN RETURN jsonb_build_object('status','invalid_game_airport_fee_quote_inputs',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 SELECT * INTO origin_row
 FROM airlinerra_game.section8_airport_operating_tariffs_v1
 WHERE world_id=1 AND airport_key=p_origin_airport_key;
 SELECT * INTO dest_row
 FROM airlinerra_game.section8_airport_operating_tariffs_v1
 WHERE world_id=1 AND airport_key=p_destination_airport_key;
 SELECT country_iso INTO origin_country FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_origin_airport_key;
 SELECT country_iso INTO dest_country FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_destination_airport_key;
 IF origin_row.price_model_version IS NULL OR dest_row.price_model_version IS NULL
 OR origin_country IS NULL OR dest_country IS NULL
 OR origin_row.evidence_class IS DISTINCT FROM
    'GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'
 OR dest_row.evidence_class IS DISTINCT FROM
    'GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'
 THEN RETURN jsonb_build_object('status','blocked_unavailable_game_airport_tariff',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;

 origin_factor:=CASE p_departure_stand_type
 WHEN 'terminal' THEN origin_row.terminal_stand_multiplier
 WHEN 'remote' THEN origin_row.remote_stand_multiplier
 WHEN 'cargo' THEN origin_row.cargo_stand_multiplier END;
 dest_factor:=CASE p_arrival_stand_type
 WHEN 'terminal' THEN dest_row.terminal_stand_multiplier
 WHEN 'remote' THEN dest_row.remote_stand_multiplier
 WHEN 'cargo' THEN dest_row.cargo_stand_multiplier END;
 IF origin_factor IS NULL OR dest_factor IS NULL
 OR origin_factor<=0 OR dest_factor<=0
 OR origin_row.landing_base_for_reference_aircraft_usd IS NULL
 OR dest_row.landing_base_for_reference_aircraft_usd IS NULL
 OR origin_row.remote_parking_reference_per_day_usd IS NULL
 OR origin_row.passenger_facility_per_departure_usd IS NULL
 OR origin_row.security_per_departing_passenger_usd IS NULL
 OR origin_row.international_processing_per_departing_passenger_usd IS NULL
 OR origin_row.departure_movement_fraction IS NULL
 OR origin_row.ground_handling_fraction IS NULL
 OR origin_row.terminal_navigation_unit_usd IS NULL
 OR dest_row.terminal_navigation_unit_usd IS NULL
 OR dest_row.remote_parking_reference_per_day_usd IS NULL
 OR origin_row.cargo_handling_per_tonne_usd IS NULL
 OR dest_row.cargo_handling_per_tonne_usd IS NULL
 OR origin_row.landing_base_for_reference_aircraft_usd<0
 OR dest_row.landing_base_for_reference_aircraft_usd<0
 THEN RETURN jsonb_build_object('status','blocked_missing_game_airport_fee_inputs',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 cross_border:=origin_country<>dest_country;
 -- Explicit game-tariff proxies (not invoices): departure movement uses
 -- origin base, arrival landing uses destination base. Stand factor changes
 -- ground handling/parking, never landing or passenger taxes.
 depart_movement:=round(origin_row.landing_base_for_reference_aircraft_usd*
  origin_row.departure_movement_fraction,2);
 arrival_landing:=round(dest_row.landing_base_for_reference_aircraft_usd,2);
 depart_handling:=round(origin_row.landing_base_for_reference_aircraft_usd*
  origin_row.ground_handling_fraction*origin_factor,2);
 arrival_parking:=round(dest_row.remote_parking_reference_per_day_usd*
  p_turnaround_minutes/1440.0*dest_factor,2);
 -- This line includes both terminal units. En-route ATC uses an explicit
 -- proxy: 35% of their sum. It is NOT a published en-route tariff.
 terminal_atc:=round(origin_row.terminal_navigation_unit_usd+
  dest_row.terminal_navigation_unit_usd,2);
 enroute_atc:=round(terminal_atc*0.35,2);
 passenger_facility:=round(p_departing_passengers*
  origin_row.passenger_facility_per_departure_usd,2);
 passenger_security:=round(p_departing_passengers*
  origin_row.security_per_departing_passenger_usd,2);
 international_passenger:=round(p_departing_passengers*
  CASE WHEN cross_border THEN
   origin_row.international_processing_per_departing_passenger_usd
  ELSE 0 END,2);
 origin_cargo:=round(p_cargo_tonnes*origin_row.cargo_handling_per_tonne_usd,2);
 dest_cargo:=round(p_cargo_tonnes*dest_row.cargo_handling_per_tonne_usd,2);
 item_lines:=jsonb_build_object(
  'departureAirportMovementUsd',depart_movement,
  'arrivalLandingUsd',arrival_landing,
  'departureGroundHandlingUsd',depart_handling,
  'arrivalStandParkingUsd',arrival_parking,
  'departureTerminalAirTrafficControlUsd',terminal_atc,
  'enrouteAirTrafficControlUsd',enroute_atc,
  'departingPassengerFacilityUsd',passenger_facility,
  'departingPassengerSecurityUsd',passenger_security,
  'internationalPassengerProcessingUsd',international_passenger,
  'originCargoHandlingUsd',origin_cargo,
  'destinationCargoHandlingUsd',dest_cargo);
 sum_cost:=depart_movement+arrival_landing+depart_handling+arrival_parking+
  terminal_atc+enroute_atc+passenger_facility+passenger_security+
  international_passenger+origin_cargo+dest_cargo;
 IF sum_cost IS NULL OR sum_cost<0 OR sum_cost>100000000
 OR EXISTS(
  SELECT 1 FROM jsonb_each_text(item_lines) a
  WHERE a.value::numeric<0 OR a.value::numeric>100000000)
 THEN RETURN jsonb_build_object('status','blocked_negative_or_incomplete_tariff',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 RETURN jsonb_build_object(
  'status','game_airport_fee_breakdown_estimate_only',
  'modelVersion','GAME_ITEMIZED_AIRPORT_TARIFF_V1_2026_11_17',
  'originAirport',p_origin_airport_key,'destinationAirport',p_destination_airport_key,
  'originTariffVersion',origin_row.price_model_version,
  'destinationTariffVersion',dest_row.price_model_version,
  'departureStand',p_departure_stand_type,'arrivalStand',p_arrival_stand_type,
  'groundMinutes',p_turnaround_minutes,'departingPassengers',p_departing_passengers,
  'international',cross_border,
  'feeLinesUsd',item_lines,'totalFeeEstimateUsd',round(sum_cost,2),
  'sourceClass','EXISTING_SECTION8_GAME_TARIFF_NOT_REAL_AIRPORT_INVOICE',
  'enrouteAtcSource','NEUTRAL_GAME_PROXY_35_PERCENT_OF_BOTH_TERMINAL_FEES',
  'actualAircraftWeightAdjustmentVerified',false,
  'actualAirTrafficControlInvoiceVerified',false,
  'actualStandBillingVerified',false,
  'cargoBillingVerified',p_cargo_tonnes=0,
  'readOnly',true,'readyForActualExpensePosting',false,
  'accountingApproved',false,'ledgerPosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_game_itemized_airport_fee_quote_v1(text,text,text,text,integer,integer,numeric) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_completed_flight_game_cost_preview_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 flight record;
 dep record;
 arr record;
 usage record;
 origin_fees record;
 destination_fees record;
 fuel jsonb;airport_quote jsonb;
 fuel_price numeric;
 fuel_price_count integer;
 actual_ticket_seats integer;
 ticket_quote_total numeric;
 elapsed_minutes integer;
 taxi_out_min integer;
 climb_min integer;
 descent_min integer;
 taxi_in_min integer;
 cruise_min integer;
 estimated_fuel_usd numeric;
 estimated_airport_usd numeric;
 estimate_total_usd numeric;
 outbound_fees numeric;
 arrival_fees numeric;
 cross_border boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_GAME_FLIGHT_COST_PREVIEW_ONLY';END IF;
 IF p_physical_flight_id IS NULL OR
  p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_PHYSICAL_FLIGHT_COST_ID';END IF;

 SELECT o.*,s.configuration_id,s.version AS live_schedule_version,
  s.departure_stand_type,s.arrival_stand_type,
  s.status AS schedule_status,s.operationally_verified,
  airline.world_id AS airline_world_id,
  origin.country_iso AS origin_country,
  destination.country_iso AS destination_country
 INTO flight
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.airlines airline
  ON airline.id=o.airline_id AND airline.world_id=1
 JOIN airlinerra_game.airport_reference_profiles origin
  ON origin.world_id=1 AND origin.airport_key=o.origin_airport_key
 JOIN airlinerra_game.airport_reference_profiles destination
  ON destination.world_id=1 AND destination.airport_key=o.destination_airport_key
 WHERE o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
  AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
  AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::int;
 IF NOT FOUND OR flight.world_id<>1 OR flight.schedule_status<>'active'
  OR flight.operationally_verified IS DISTINCT FROM true
  OR flight.live_schedule_version<>flight.schedule_version
  OR flight.source_kind<>'game_verified_saleable_schedule_v1'
  OR flight.booking_status<>'closed'
  OR flight.verified_passenger_seats IS NULL OR
     flight.verified_passenger_seats<=0
  OR flight.origin_country IS NULL OR flight.destination_country IS NULL
 THEN RETURN jsonb_build_object('status','blocked_unverified_completed_flight',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 SELECT * INTO dep FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id AND phase='departed';
 SELECT * INTO arr FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id AND phase='arrived';
 SELECT * INTO usage FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id;
 IF dep.engine_event_id IS NULL OR arr.engine_event_id IS NULL
 OR usage.physical_flight_id IS NULL
 OR dep.schedule_id IS DISTINCT FROM flight.schedule_id
 OR arr.schedule_id IS DISTINCT FROM flight.schedule_id
 OR dep.schedule_version IS DISTINCT FROM flight.schedule_version
 OR arr.schedule_version IS DISTINCT FROM flight.schedule_version
 OR dep.airline_id IS DISTINCT FROM flight.airline_id
 OR arr.airline_id IS DISTINCT FROM flight.airline_id
 OR usage.airline_id IS DISTINCT FROM flight.airline_id
 OR usage.arrived_engine_event_id IS DISTINCT FROM arr.engine_event_id
 OR usage.departed_engine_event_id IS DISTINCT FROM dep.engine_event_id
 OR arr.actual_event_utc<=dep.actual_event_utc
 OR arr.actual_event_utc>clock_timestamp()
 THEN RETURN jsonb_build_object('status','blocked_missing_verified_operated_arrival',
   'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(seats_requested) FILTER(
   WHERE reservation_status='reserved'),0)::int,
   coalesce(sum(seats_requested*quoted_fare_usd) FILTER(
   WHERE reservation_status='reserved'),0)::numeric
 INTO actual_ticket_seats,ticket_quote_total
 FROM airlinerra_game.section9_passenger_reservation_batches_v1
 WHERE occurrence_id=flight.id;
 IF actual_ticket_seats IS DISTINCT FROM flight.booked_seats
  OR actual_ticket_seats>flight.verified_passenger_seats
 THEN RETURN jsonb_build_object('status','blocked_passenger_reservation_mismatch',
   'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;

 SELECT * INTO origin_fees FROM airlinerra_game.section8_airport_operating_tariffs_v1
 WHERE world_id=1 AND airport_key=flight.origin_airport_key;
 SELECT * INTO destination_fees FROM airlinerra_game.section8_airport_operating_tariffs_v1
 WHERE world_id=1 AND airport_key=flight.destination_airport_key;
 IF origin_fees.price_model_version IS NULL
 OR destination_fees.price_model_version IS NULL
 OR origin_fees.evidence_class IS DISTINCT FROM
    'GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'
 OR destination_fees.evidence_class IS DISTINCT FROM
    'GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'
 THEN RETURN jsonb_build_object('status','blocked_unavailable_game_airport_tariffs',
   'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;

 -- An existing economy research dataset uses a neutral $0.95/kg
 -- GAME assumption. Its entries are only a pricing reference, not
 -- authoritative fuel-market or actual uploaded airport receipts.
 SELECT count(*),min(fuel_price_assumption_usd_per_kg)
 INTO fuel_price_count,fuel_price
 FROM airlinerra.aircraft_expansion_group3_economics_v1
 WHERE fuel_price_assumption_usd_per_kg>0;
 IF fuel_price_count<1 OR fuel_price IS NULL OR
 EXISTS(
 SELECT 1 FROM airlinerra.aircraft_expansion_group3_economics_v1
 WHERE fuel_price_assumption_usd_per_kg IS DISTINCT FROM fuel_price)
 THEN RETURN jsonb_build_object('status','blocked_unstable_game_fuel_price_assumption',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;

 elapsed_minutes:=ceil(extract(epoch FROM(
   arr.actual_event_utc-dep.actual_event_utc))/60)::int;
 IF elapsed_minutes NOT BETWEEN 30 AND 1800 THEN
  RETURN jsonb_build_object('status','blocked_flight_duration_outside_game_fuel_model',
   'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 -- Explicit provisional phase estimates. Never real dispatch phases.
 taxi_out_min:=least(9,greatest(3,floor(elapsed_minutes*0.16)::int));
 taxi_in_min:=least(6,greatest(3,floor(elapsed_minutes*0.10)::int));
 climb_min:=least(15,greatest(10,floor(elapsed_minutes*0.22)::int));
 descent_min:=least(15,greatest(10,floor(elapsed_minutes*0.22)::int));
 cruise_min:=elapsed_minutes-taxi_out_min-taxi_in_min-climb_min-descent_min;
 IF cruise_min<1 THEN RETURN jsonb_build_object(
  'status','blocked_flight_too_short_for_game_phase_model',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 fuel:=airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(
   flight.configuration_id,
   round(actual_ticket_seats::numeric/flight.verified_passenger_seats*100,2),
   taxi_out_min,climb_min,cruise_min,descent_min,taxi_in_min);
 IF fuel->>'status' IS DISTINCT FROM 'game_reserve_aware_fuel_estimate_only'
 OR fuel->>'dispatchApproved' IS DISTINCT FROM 'false'
 OR fuel->>'accountingApproved' IS DISTINCT FROM 'false'
 OR fuel->>'totalKg' IS NULL
 OR fuel->>'withinGameTankIncludingReserve' IS DISTINCT FROM 'true'
 OR fuel->>'fuelPlanningReserveIncluded' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_fuel_model_not_ready_for_game_estimate',
   'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 estimated_fuel_usd:=round((fuel->>'tripBurnKg')::numeric*fuel_price,2);

 airport_quote:=airlinerra_game.section9_game_itemized_airport_fee_quote_v1(
  flight.origin_airport_key,flight.destination_airport_key,
  flight.departure_stand_type,flight.arrival_stand_type,
  actual_ticket_seats,flight.turnaround_minutes,0);
 IF airport_quote->>'status' IS DISTINCT FROM 'game_airport_fee_breakdown_estimate_only'
 OR airport_quote->>'readyForActualExpensePosting' IS DISTINCT FROM 'false'
 OR airport_quote->>'accountingApproved' IS DISTINCT FROM 'false'
 OR jsonb_typeof(airport_quote->'feeLinesUsd')<>'object'
 THEN RETURN jsonb_build_object('status','blocked_incomplete_game_airport_cost_inputs',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 estimated_airport_usd:=(airport_quote->>'totalFeeEstimateUsd')::numeric;
 IF estimated_airport_usd<0 OR estimated_airport_usd>100000000
 THEN RETURN jsonb_build_object('status','blocked_invalid_game_airport_cost_total',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 estimate_total_usd:=estimated_fuel_usd+estimated_airport_usd;
 RETURN jsonb_build_object(
  'status','game_only_completed_flight_cost_estimate',
  'physicalFlightId',p_physical_flight_id,
  'sourceVersion','GAME_COST_PREVIEW_V1_NEVER_POST',
  'bookedPassengers',actual_ticket_seats,
  'quotedTicketFareUsd',ticket_quote_total,
  'fuelKgEstimate',fuel->'tripBurnKg',
  'fuelReserveKg',fuel->'holdingReserveKg',
  'fuelContingencyKg',fuel->'contingencyKg',
  'minimumPlannedFuelOnBoardKg',fuel->'minimumPlannedFuelOnBoardKg',
  'withinGameTankIncludingReserve',fuel->'withinGameTankIncludingReserve',
  'fuelQuoteModelVersion',fuel->'modelVersion',
  'fuelPriceAssumptionUsdPerKg',fuel_price,
  'fuelPriceBasis','EXISTING_GROUP3_GAME_ESTIMATE_GENERALIZED_PROVISIONALLY',
  'fuelCostEstimateUsd',estimated_fuel_usd,
  'airportCostEstimateUsd',estimated_airport_usd,
  'airportFeeLinesUsd',airport_quote->'feeLinesUsd',
  'airportFeeQuoteModelVersion',airport_quote->'modelVersion',
  'enrouteATCCostUsesGameProxy',true,
  'operatingCostEstimateUsd',estimate_total_usd,
  'airportTariffSource','SECTION8_PROVISIONAL_GAME_TARIFF_NOT_REAL_BILL',
  'originTariffVersion',origin_fees.price_model_version,
  'destinationTariffVersion',destination_fees.price_model_version,
  'phaseModelSource','PROVISIONAL_NONAIRCRAFTSPECIFIC_GAME_COEFFICIENTS',
  'fuelReserveIncluded',true,
  'fuelPlanningReserveIncluded',true,
  'reserveFuelChargedAsBurn',false,
  'feeLinesAreItemized',true,
  'crewCostsIncluded',false,'maintenanceChargesIncluded',false,
  'ownershipChargesIncluded',false,
  'realWorldOperatingCostVerified',false,
  'readyForActualExpensePosting',false,
  'readOnly',true,'accountingApproved',false,
  'dispatchApproved',false,'ledgerPosted',false,
  'revenueRecognized',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_completed_flight_game_cost_preview_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_actual_ticket_postarrival_finance_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 occurrence record;
 receipt record;
 arrival record;
 old record;
 review jsonb;
 quote jsonb;
 now_guard jsonb;
 actual_seats integer;
 ticket_income numeric(16,2);
 fuel_est numeric(16,2);
 airport_est numeric(16,2);
 total_est numeric(16,2);
 inserted integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_VERIFIED_ARRIVAL_PREPARATION_TRUSTED_WORKER_ONLY';
 END IF;
 IF p_physical_flight_id IS NULL
 OR p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ACTUAL_TICKET_FINANCE_PHYSICAL_FLIGHT_ID';END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(
  583729,pg_catalog.hashtext(p_physical_flight_id))
 THEN RETURN jsonb_build_object('status','finance_preparation_running',
   'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 SELECT o.id,o.schedule_id,o.airline_id,o.flight_local_date,o.weekly_entry,
   o.booked_seats,o.verified_passenger_seats,o.booking_status,o.source_kind,
   s.status AS schedule_status,s.operationally_verified,
   o.schedule_version,s.version AS current_schedule_version,
   cap.cargo_held_tonnes,cap.passengers_held
 INTO occurrence
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
  ON cap.physical_flight_id=p_physical_flight_id
  AND cap.schedule_id=o.schedule_id AND cap.airline_id=o.airline_id
 WHERE o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
 AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
 AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::int
 FOR SHARE OF o,s,cap;
 IF NOT FOUND OR occurrence.booking_status<>'closed'
 OR occurrence.source_kind<>'game_verified_saleable_schedule_v1'
 OR occurrence.schedule_status<>'active'
 OR occurrence.operationally_verified IS DISTINCT FROM true
 OR occurrence.schedule_version IS DISTINCT FROM occurrence.current_schedule_version
 OR occurrence.verified_passenger_seats IS NULL
 OR occurrence.verified_passenger_seats<1
 OR occurrence.booked_seats>occurrence.verified_passenger_seats
 OR occurrence.passengers_held<occurrence.booked_seats
 OR occurrence.cargo_held_tonnes IS DISTINCT FROM 0
 THEN RETURN jsonb_build_object('status','blocked_unverified_arrival_or_unsupported_cargo',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 SELECT r.* INTO receipt
 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 r
 WHERE r.physical_flight_id=p_physical_flight_id;
 SELECT m.* INTO arrival
 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.flight_occurrence_id=p_physical_flight_id
 AND m.phase='arrived';
 IF receipt.physical_flight_id IS NULL OR arrival.engine_event_id IS NULL
 OR receipt.airline_id<>occurrence.airline_id
 OR arrival.airline_id<>occurrence.airline_id
 OR receipt.arrived_engine_event_id<>arrival.engine_event_id
 OR receipt.source_kind<>'signed_operated_game_arrival_usage_v1'
 THEN RETURN jsonb_build_object('status','blocked_missing_signed_arrival_and_aircraft_usage',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 now_guard:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF now_guard->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR arrival.actual_event_utc>(now_guard->>'gameHourUtc')::timestamptz
 THEN RETURN jsonb_build_object('status','blocked_unverified_postarrival_game_hour',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1
 WHERE physical_flight_id=p_physical_flight_id)
 THEN RETURN jsonb_build_object('status','blocked_already_posted_do_not_prepare_twice',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 review:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(
  p_physical_flight_id);
 quote:=airlinerra_game.section9_completed_flight_game_cost_preview_v1(
  p_physical_flight_id);
 IF review->>'status' IS DISTINCT FROM 'postarrival_ticket_totals_reconciled'
 OR review->>'reconciled' IS DISTINCT FROM 'true'
 OR review->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR review->>'financeAlreadyPosted' IS DISTINCT FROM 'false'
 OR quote->>'status' IS DISTINCT FROM 'game_only_completed_flight_cost_estimate'
 OR quote->>'sourceVersion' IS DISTINCT FROM 'GAME_COST_PREVIEW_V1_NEVER_POST'
 OR quote->>'readOnly' IS DISTINCT FROM 'true'
 OR quote->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR quote->>'readyForActualExpensePosting' IS DISTINCT FROM 'false'
 OR quote->>'accountingApproved' IS DISTINCT FROM 'false'
 OR quote->>'fuelPlanningReserveIncluded' IS DISTINCT FROM 'true'
 OR quote->>'withinGameTankIncludingReserve' IS DISTINCT FROM 'true'
 OR quote->>'reserveFuelChargedAsBurn' IS DISTINCT FROM 'false'
 OR quote->>'feeLinesAreItemized' IS DISTINCT FROM 'true'
 OR jsonb_typeof(quote->'airportFeeLinesUsd') IS DISTINCT FROM 'object'
 OR (quote->>'airportCostEstimateUsd')::numeric IS NULL
 OR (SELECT round(sum(value::numeric),2)
      FROM jsonb_each_text(quote->'airportFeeLinesUsd'))
      IS DISTINCT FROM (quote->>'airportCostEstimateUsd')::numeric
 THEN RETURN jsonb_build_object('status','blocked_ticket_or_provisional_cost_evidence',
  'ticketProofStatus',review->>'status',
  'costProofStatus',quote->>'status',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 IF review->>'physicalFlightId' IS DISTINCT FROM p_physical_flight_id
 OR quote->>'physicalFlightId' IS DISTINCT FROM p_physical_flight_id
 OR (quote->>'bookedPassengers')::integer
   IS DISTINCT FROM (review->>'ticketPassengers')::integer
 OR (quote->>'quotedTicketFareUsd')::numeric
   IS DISTINCT FROM (review->>'ticketIncomeUsd')::numeric
 THEN RAISE EXCEPTION USING ERRCODE='23505',
 MESSAGE='SECTION9_POSTARRIVAL_TICKET_COST_PROOFS_DISAGREE';END IF;

 actual_seats:=(review->>'ticketPassengers')::integer;
 ticket_income:=(review->>'ticketIncomeUsd')::numeric(16,2);
 fuel_est:=(quote->>'fuelCostEstimateUsd')::numeric(16,2);
 airport_est:=(quote->>'airportCostEstimateUsd')::numeric(16,2);
 total_est:=(quote->>'operatingCostEstimateUsd')::numeric(16,2);
 IF actual_seats<>occurrence.booked_seats
 OR ticket_income<0 OR ticket_income>1000000000
 OR fuel_est<=0 OR fuel_est>100000000
 OR airport_est<0 OR airport_est>100000000
 OR total_est IS DISTINCT FROM fuel_est+airport_est
 THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_POSTARRIVAL_FINANCE_GAME_ESTIMATE_INCONSISTENT';END IF;
 INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1(
  physical_flight_id,airline_id,schedule_id,flight_local_date,
  arrival_event_id,aircraft_usage_receipt_flight_id,
  passenger_count,ticket_quote_usd,
  provisional_fuel_cost_usd,provisional_airport_cost_usd,
  provisional_operating_cost_usd,ticket_reconciliation_proof,
  provisional_game_cost_proof
 ) VALUES(
  p_physical_flight_id,occurrence.airline_id,occurrence.schedule_id,
  occurrence.flight_local_date,arrival.engine_event_id,receipt.physical_flight_id,
  actual_seats,ticket_income,fuel_est,airport_est,total_est,review,quote
 )
 ON CONFLICT(physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 SELECT * INTO old
 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF NOT FOUND OR old.airline_id IS DISTINCT FROM occurrence.airline_id
 OR old.schedule_id IS DISTINCT FROM occurrence.schedule_id
 OR old.flight_local_date IS DISTINCT FROM occurrence.flight_local_date
 OR old.arrival_event_id IS DISTINCT FROM arrival.engine_event_id
 OR old.aircraft_usage_receipt_flight_id IS DISTINCT FROM receipt.physical_flight_id
 OR old.passenger_count IS DISTINCT FROM actual_seats
 OR old.ticket_quote_usd IS DISTINCT FROM ticket_income
 OR old.provisional_fuel_cost_usd IS DISTINCT FROM fuel_est
 OR old.provisional_airport_cost_usd IS DISTINCT FROM airport_est
 OR old.provisional_operating_cost_usd IS DISTINCT FROM total_est
 OR old.ticket_reconciliation_proof IS DISTINCT FROM review
 OR old.provisional_game_cost_proof IS DISTINCT FROM quote
 OR old.preparation_status<>'UNPOSTED_GAME_ESTIMATE'
 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_REPLAYED_ACTUAL_FINANCE_PREPARATION_PROOF_CHANGED';END IF;
 RETURN jsonb_build_object(
  'status',CASE WHEN inserted=1 THEN 'actual_ticket_estimate_prepared'
   ELSE 'actual_ticket_estimate_replayed' END,
  'physicalFlightId',p_physical_flight_id,
  'passengers',actual_seats,
  'ticketIncomeEstimateUsd',ticket_income,
  'fuelCostEstimateUsd',fuel_est,
  'airportCostEstimateUsd',airport_est,
  'gameOperatingCostEstimateUsd',total_est,
  'created',inserted=1,'replayed',inserted=0,
  'source','SIGNED_ARRIVAL_BOOKED_TICKETS_PROVISIONAL_GAME_TARIFF',
  'requiresFuelAccountingRelease',true,
  'awaitsIndependentFinancialSettlement',true,
  'readyToPost',false,'ledgerPosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_prepare_actual_ticket_postarrival_finance_v1(text) FROM PUBLIC,anon,authenticated,service_role;
