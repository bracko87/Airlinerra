BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_completed_flight_game_cost_preview_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 phase_profile jsonb;
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
 phase_profile:=airlinerra_game.section9_game_route_phase_profile_v1(flight.configuration_id,flight.origin_airport_key,flight.destination_airport_key,elapsed_minutes);
 IF phase_profile IS NULL THEN RETURN jsonb_build_object('status','blocked_invalid_game_fuel_flight_duration','readOnly',true,'ledgerPosted',false);END IF;
 taxi_out_min:=(phase_profile->>'taxiOutMinutes')::int;
 climb_min:=(phase_profile->>'climbMinutes')::int;
 cruise_min:=(phase_profile->>'cruiseMinutes')::int;
 descent_min:=(phase_profile->>'descentMinutes')::int;
 taxi_in_min:=(phase_profile->>'taxiInMinutes')::int;
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
 OR fuel->>'tripBurnKg' IS NULL
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
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 phase_profile jsonb;
 r record;custody record; fuel_model record;
 clock_proof jsonb;fuel jsonb;
 hours_old numeric;total_minutes integer;
 taxi_out_min integer;taxi_in_min integer;climb_min integer;descent_min integer;cruise_min integer;
 qty_trip numeric(14,3);qty_min numeric(14,3);
 source_valid boolean:=false;
 origin_can_supply boolean:=false;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FUEL_PREFLIGHT_TRUSTED_GAME_WORKER_ONLY';END IF;
 IF p_physical_flight_id IS NULL OR
  p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_GAME_FUEL_FLIGHT_ID';END IF;

 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;
 SELECT o.id AS occurrence_id,o.airline_id,o.schedule_id,o.aircraft_inventory_id,
   o.schedule_version,o.weekly_entry,o.flight_local_date,
   o.departure_utc,o.arrival_utc,o.origin_airport_key,o.destination_airport_key,
   o.verified_passenger_seats,o.booked_seats,o.booking_status,o.source_kind,
   s.version AS active_schedule_version,s.status AS active_schedule_status,
   s.operationally_verified,s.configuration_id,
   fleet.fleet_status,fleet.configuration_id AS fleet_configuration_id,
   cap.passenger_capacity,cap.passengers_held,cap.cargo_held_tonnes,
   cap.schedule_version AS cap_version,cap.departure_utc AS cap_departure,
   cap.arrival_utc AS cap_arrival
 INTO r
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=o.aircraft_inventory_id AND fleet.airline_id=o.airline_id
 LEFT JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
  ON cap.physical_flight_id=p_physical_flight_id AND cap.airline_id=o.airline_id
 WHERE o.world_id=1
  AND o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
  AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
  AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::integer;
 IF NOT FOUND OR r.active_schedule_status IS DISTINCT FROM 'active'
  OR r.operationally_verified IS DISTINCT FROM true
  OR r.active_schedule_version IS DISTINCT FROM r.schedule_version
  OR r.fleet_status IS DISTINCT FROM 'in_service'
  OR r.fleet_configuration_id IS DISTINCT FROM r.configuration_id
  OR r.source_kind IS DISTINCT FROM 'game_verified_saleable_schedule_v1'
  OR r.booking_status NOT IN ('open','closed')
  OR r.verified_passenger_seats IS NULL OR r.verified_passenger_seats<=0
  OR r.booked_seats>r.verified_passenger_seats
  OR r.passenger_capacity IS DISTINCT FROM r.verified_passenger_seats
  OR r.passengers_held<r.booked_seats
  OR r.passengers_held>r.passenger_capacity
  OR r.cargo_held_tonnes IS DISTINCT FROM 0
  OR r.cap_version IS DISTINCT FROM r.schedule_version
  OR r.cap_departure IS DISTINCT FROM r.departure_utc
  OR r.cap_arrival IS DISTINCT FROM r.arrival_utc
  OR r.arrival_utc<=r.departure_utc
 THEN RETURN jsonb_build_object('status','blocked_unverified_operating_flight',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);
 END IF;

 SELECT * INTO fuel_model
 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=r.configuration_id;
 IF NOT FOUND OR fuel_model.game_calculation_ready IS DISTINCT FROM true
 OR fuel_model.tank_capacity_kg IS NULL
 OR fuel_model.fuel_game_family IS NULL
 THEN RETURN jsonb_build_object('status','blocked_incomplete_game_aircraft_fuel_model',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;
 total_minutes:=ceil(extract(epoch from(r.arrival_utc-r.departure_utc))/60)::integer;
 phase_profile:=airlinerra_game.section9_game_route_phase_profile_v1(r.configuration_id,r.origin_airport_key,r.destination_airport_key,total_minutes);
 IF phase_profile IS NULL THEN RETURN jsonb_build_object('status','blocked_invalid_game_fuel_flight_duration','readOnly',true,'ledgerPosted',false);END IF;
 taxi_out_min:=(phase_profile->>'taxiOutMinutes')::int;
 climb_min:=(phase_profile->>'climbMinutes')::int;
 cruise_min:=(phase_profile->>'cruiseMinutes')::int;
 descent_min:=(phase_profile->>'descentMinutes')::int;
 taxi_in_min:=(phase_profile->>'taxiInMinutes')::int;
 IF cruise_min<1 THEN RETURN jsonb_build_object(
   'status','blocked_game_fuel_flight_too_short_for_phase_model',
   'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;

 fuel:=airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(
   r.configuration_id,
   round(r.booked_seats::numeric/r.verified_passenger_seats*100,2),
   taxi_out_min,climb_min,cruise_min,descent_min,taxi_in_min);
 IF fuel->>'status' IS DISTINCT FROM 'game_reserve_aware_fuel_estimate_only'
  OR fuel->>'fuelPlanningReserveIncluded' IS DISTINCT FROM 'true'
  OR fuel->>'withinGameTankIncludingReserve' IS DISTINCT FROM 'true'
  OR fuel->>'accountingApproved' IS DISTINCT FROM 'false'
  OR fuel->>'dispatchApproved' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object('status','blocked_fuel_tank_or_game_model',
  'gameOnly',true,'fuelVerifiedForGame',false,
  'quoteStatus',fuel->>'status',
  'withinGameTankIncludingReserve',fuel->>'withinGameTankIncludingReserve',
  'readOnly',true,'ledgerPosted',false);END IF;
 qty_trip:=(fuel->>'tripBurnKg')::numeric(14,3);
 qty_min:=(fuel->>'minimumPlannedFuelOnBoardKg')::numeric(14,3);
 IF qty_trip<=0 OR qty_min<=qty_trip THEN
 RAISE EXCEPTION USING ERRCODE='23514',
  MESSAGE='SECTION9_INVALID_FUEL_TRIP_AND_RESERVE_PROOF';END IF;

 -- The airport's generic fuel_available only indicates that *some* fuel
 -- service exists. It is not proof of this aircraft's fuel grade or balance.
 SELECT coalesce(fac.fuel_available,false) INTO origin_can_supply
 FROM airlinerra_game.airport_facilities fac
 WHERE fac.world_id=1 AND fac.airport_key=r.origin_airport_key;
 origin_can_supply:=coalesce(origin_can_supply,false);

 -- Lock the physical fuel balance until the dispatcher either records
 -- the signed departure and its fuel receipt or rolls back.
 SELECT * INTO custody
 FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1 c
 WHERE c.aircraft_inventory_id=r.aircraft_inventory_id
 AND c.airline_id=r.airline_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object(
   'status','blocked_missing_verified_aircraft_fuel_onboard',
   'physicalFlightId',p_physical_flight_id,
   'minimumPlannedFuelOnBoardKg',qty_min,
   'plannedTripBurnKg',qty_trip,
   'airportFuelServiceListed',origin_can_supply,
   'fuelOnBoardKnown',false,'fuelVerifiedForGame',false,
   'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF custody.configuration_id IS DISTINCT FROM r.configuration_id
 OR custody.world_id<>1
 OR custody.at_airport_key IS DISTINCT FROM r.origin_airport_key
 OR custody.fuel_game_family IS DISTINCT FROM fuel_model.fuel_game_family
 OR custody.onboard_kg>fuel_model.tank_capacity_kg
 OR custody.game_hour_utc>(clock_proof->>'gameHourUtc')::timestamptz
 THEN RETURN jsonb_build_object(
  'status','blocked_fuel_custody_location_configuration_or_clock_mismatch',
  'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;

 IF custody.source_event_kind='approved_game_fuel_load' THEN
  SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_approved_fuel_load_receipts_v1 t
   WHERE t.source_event_id=custody.source_event_id
   AND t.source_status='game_authority_approved'
   AND t.airline_id=custody.airline_id
   AND t.aircraft_inventory_id=custody.aircraft_inventory_id
   AND t.at_airport_key=custody.at_airport_key
   AND t.fuel_family=custody.fuel_game_family
   AND t.fuel_after_load_kg=custody.onboard_kg
   AND t.game_hour_utc=custody.game_hour_utc
   AND t.game_supplier_reference=custody.evidence_reference
  ) INTO source_valid;
 ELSIF custody.source_event_kind='signed_arrival_burn' THEN
  SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 a
   WHERE a.arrival_engine_event_id=custody.source_event_id
   AND a.airline_id=custody.airline_id
   AND a.aircraft_inventory_id=custody.aircraft_inventory_id
   AND a.location_airport_key=custody.at_airport_key
   AND a.onboard_after_arrival_kg=custody.onboard_kg
  ) INTO source_valid;
 END IF;
 IF source_valid IS DISTINCT FROM true THEN RETURN jsonb_build_object(
   'status','blocked_missing_authorized_fuel_custody_source',
   'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF custody.onboard_kg<qty_min THEN RETURN jsonb_build_object(
   'status','blocked_insufficient_aircraft_fuel_including_reserve',
   'physicalFlightId',p_physical_flight_id,
   'fuelOnBoardKg',custody.onboard_kg,
   'minimumPlannedFuelOnBoardKg',qty_min,
   'plannedTripBurnKg',qty_trip,
   'airportFuelServiceListed',origin_can_supply,
   'fuelVerifiedForGame',false,
   'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 d
  WHERE d.physical_flight_id=p_physical_flight_id
 ) THEN RETURN jsonb_build_object(
  'status','blocked_departure_fuel_proof_already_recorded',
  'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 RETURN jsonb_build_object(
 'status','verified_game_fuel_onboard_available_for_planned_trip',
 'physicalFlightId',p_physical_flight_id,
 'airlineId',r.airline_id,'aircraftInventoryId',r.aircraft_inventory_id,
 'originAirport',r.origin_airport_key,'destinationAirport',r.destination_airport_key,
 'configurationId',r.configuration_id,
 'fuelGameFamily',custody.fuel_game_family,
 'fuelCustodyRevision',custody.revision,
 'fuelSourceEventId',custody.source_event_id,
 'fuelOnBoardKg',custody.onboard_kg,
 'plannedTripBurnKg',qty_trip,
 'plannedContingencyKg',(fuel->>'contingencyKg')::numeric,
 'plannedHoldingReserveKg',(fuel->>'holdingReserveKg')::numeric,
 'minimumPlannedFuelOnBoardKg',qty_min,
 'tankCapacityKg',fuel_model.tank_capacity_kg,
 'fuelQuoteModelVersion',fuel->>'modelVersion',
 'airportFuelServiceListed',origin_can_supply,
 'fuelVerifiedForGame',true,'fuelGradeCertifiedForRealAircraft',false,
 'gameOnly',true,'readOnly',true,'ledgerPosted',false,
 'dispatchApprovedByThisCheck',false);
END $function$;
COMMIT;
