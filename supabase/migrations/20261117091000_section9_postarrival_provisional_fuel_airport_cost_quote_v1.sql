-- Read-only POST-ARRIVAL game cost estimate for every flight, not a
-- posting mechanism. Current 5-phase fuel profile uses provisional
-- coefficients and has dispatch/accounting approval DISABLED.
-- Assumed USD/kg fuel price derives from existing Group 3 game economy
-- data ($0.95/kg as of Nov 17), not an actual aircraft fuel invoice.
-- Airport game tariff lines are from the versioned Section 8 price model,
-- not real airport charges. Crew excluded in Phase 1 by game design.
-- All private worker functions remain inaccessible to players, anon and
-- external API service role. No financial ledger writes.
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
 fuel jsonb;
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
 fuel:=airlinerra_game.section9_game_five_phase_fuel_quote_v1(
   flight.configuration_id,
   round(actual_ticket_seats::numeric/flight.verified_passenger_seats*100,2),
   taxi_out_min,climb_min,cruise_min,descent_min,taxi_in_min);
 IF fuel->>'status' IS DISTINCT FROM 'game_estimate_only'
 OR fuel->>'dispatchApproved' IS DISTINCT FROM 'false'
 OR fuel->>'accountingApproved' IS DISTINCT FROM 'false'
 OR fuel->>'totalKg' IS NULL
 OR fuel->>'withinModelTankWithoutReserve' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_fuel_model_not_ready_for_game_estimate',
   'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 estimated_fuel_usd:=round((fuel->>'totalKg')::numeric*fuel_price,2);
 cross_border:=flight.origin_country<>flight.destination_country;
 -- Versioned AIRPORT GAME TARIFF assumptions; not actual vendor bills.
 outbound_fees:=
  origin_fees.landing_base_for_reference_aircraft_usd*
    origin_fees.departure_movement_fraction+
  origin_fees.terminal_navigation_unit_usd+
  actual_ticket_seats*(origin_fees.passenger_facility_per_departure_usd+
    origin_fees.security_per_departing_passenger_usd+
    CASE WHEN cross_border
      THEN origin_fees.international_processing_per_departing_passenger_usd
      ELSE 0 END);
 arrival_fees:=destination_fees.landing_base_for_reference_aircraft_usd*
     (1+destination_fees.ground_handling_fraction)+
     destination_fees.terminal_navigation_unit_usd;
 IF outbound_fees IS NULL OR arrival_fees IS NULL OR
  outbound_fees<0 OR arrival_fees<0 THEN
 RETURN jsonb_build_object('status','blocked_incomplete_game_airport_cost_inputs',
  'readOnly',true,'accountingApproved',false,'ledgerPosted',false);END IF;
 estimated_airport_usd:=round(outbound_fees+arrival_fees,2);
 estimate_total_usd:=estimated_fuel_usd+estimated_airport_usd;
 RETURN jsonb_build_object(
  'status','game_only_completed_flight_cost_estimate',
  'physicalFlightId',p_physical_flight_id,
  'sourceVersion','GAME_COST_PREVIEW_V1_NEVER_POST',
  'bookedPassengers',actual_ticket_seats,
  'quotedTicketFareUsd',ticket_quote_total,
  'fuelKgEstimate',fuel->'totalKg',
  'fuelPriceAssumptionUsdPerKg',fuel_price,
  'fuelPriceBasis','EXISTING_GROUP3_GAME_ESTIMATE_GENERALIZED_PROVISIONALLY',
  'fuelCostEstimateUsd',estimated_fuel_usd,
  'airportCostEstimateUsd',estimated_airport_usd,
  'operatingCostEstimateUsd',estimate_total_usd,
  'airportTariffSource','SECTION8_PROVISIONAL_GAME_TARIFF_NOT_REAL_BILL',
  'originTariffVersion',origin_fees.price_model_version,
  'destinationTariffVersion',destination_fees.price_model_version,
  'phaseModelSource','PROVISIONAL_NONAIRCRAFTSPECIFIC_GAME_COEFFICIENTS',
  'fuelReserveIncluded',false,
  'crewCostsIncluded',false,'maintenanceChargesIncluded',false,
  'ownershipChargesIncluded',false,
  'realWorldOperatingCostVerified',false,
  'readyForActualExpensePosting',false,
  'readOnly',true,'accountingApproved',false,
  'dispatchApproved',false,'ledgerPosted',false,
  'revenueRecognized',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_completed_flight_game_cost_preview_v1(text)
 FROM PUBLIC,anon,authenticated,service_role;
