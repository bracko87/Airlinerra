-- REVIEW ONLY: one-way storage planning for already authorized airports.
-- Apply after aircraft_storage_facilities_review.sql in a disposable DB.
-- No changes to commercial eligibility or actual scheduling.
BEGIN;
CREATE FUNCTION airlinerra_game.aircraft_storage_relocation_quote_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_airport text,p_departure timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE cfg bigint; facility record; pos jsonb; origin text; instant timestamptz;
 q jsonb; gate jsonb; arrival timestamptz; reasons text[]:=ARRAY[]::text[];
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT i.configuration_id INTO cfg
 FROM airlinerra_game.airline_aircraft_inventory i
 JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE i.id=p_aircraft AND i.airline_id=p_airline AND i.ownership_type='owned' AND i.fleet_status='in_service';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='STORAGE_AIRCRAFT_NOT_ELIGIBLE';END IF;
 SELECT * INTO facility FROM airlinerra_game.aircraft_storage_facilities_v1
 WHERE world_id=1 AND airport_key=p_airport AND review_state='approved';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_facility_not_approved','bookable',false);END IF;
 instant:=airlinerra_game.section9_verified_world_instant_v1();
 IF instant IS NULL OR p_departure IS NULL OR p_departure<instant+interval '1 minute' OR p_departure>instant+interval '7 days'
 THEN RETURN jsonb_build_object('status','storage_departure_unverified','bookable',false);END IF;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,p_aircraft,(instant AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR pos->>'airportKey' IS NULL
 THEN RETURN jsonb_build_object('status','storage_position_unverified','bookable',false);END IF;
 origin:=pos->>'airportKey';
 IF origin=p_airport THEN RETURN jsonb_build_object('status','already_at_storage_airport','bookable',false,'airportKey',origin);END IF;
 -- Dedicated airport admission must be implemented across phase, tariff,
 -- restriction and signed movement writers before removing this guard.
 IF facility.admission_scope<>'existing_commercial' OR
 (SELECT count(*) FROM airlinerra_game.airport_unified_operations_v1 a
 WHERE a.world_id=1 AND a.airport_key IN (origin,p_airport) AND a.operationally_authorized AND a.dispatch_eligible_by_airport_admission)<>2
 THEN RETURN jsonb_build_object('status','storage_only_relocation_not_released','bookable',false);END IF;
 q:=airlinerra_game.section9_owned_route_commercial_forecast_v1(p_player,p_airline,p_aircraft,origin,p_airport,'remote','remote',45,0,0);
 IF q->>'status' IS DISTINCT FROM 'route_phase1_forecast' OR q->>'estimatedPassengers' IS DISTINCT FROM '0'
 OR q#>>'{phases,totalMinutes}' IS NULL
 THEN RETURN jsonb_build_object('status','storage_cost_model_unavailable','bookable',false);END IF;
 arrival:=p_departure+make_interval(mins=>(q#>>'{phases,totalMinutes}')::int);
 IF q#>>'{fuel,withinGameTankIncludingReserve}' IS DISTINCT FROM 'true' THEN reasons:=array_append(reasons,'FUEL_RANGE_NOT_CONFIRMED');END IF;
 gate:=airlinerra_game.section5_universal_route_restriction_gate_v1(1::smallint,origin,p_airport,cfg,p_departure,arrival,NULL,NULL);
 IF airlinerra_game.section9_game_route_restrictions_valid_v1(origin,p_airport,jsonb_build_object('weeklyTimetableChecked',true,'gameHardBlocked',(gate->>'gameHardBlocked')::boolean,'occurrences',jsonb_build_array(gate))) IS DISTINCT FROM true
 THEN reasons:=array_append(reasons,'AIRPORT_RESTRICTIONS_NOT_CONFIRMED');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s WHERE s.airline_id=p_airline AND s.aircraft_inventory_id=p_aircraft AND s.status='active')
 THEN reasons:=array_append(reasons,'ACTIVE_ROUTES_REQUIRE_CLOSURE_OR_REASSIGNMENT');END IF;
 RETURN jsonb_build_object('status','storage_relocation_quote','bookable',false,'readOnly',true,
 'originAirportKey',origin,'destinationAirportKey',p_airport,'departureUtc',p_departure,'arrivalUtc',arrival,
 'distanceKm',q#>'{phases,distanceKm}','flightMinutes',q#>'{phases,totalMinutes}',
 'fuelBurnKg',q#>'{fuel,tripBurnKg}','fuelCostUsd',q->'fuelCostUsd','airportFeesUsd',q->'airportFeesUsd',
 'directOperatingCostUsd',q->'directOperatingCostUsd','passengers',0,'ticketRevenueUsd',0,
 'preliminaryBlockers',to_jsonb(reasons),'storageCapacityUnlimited',true,
 'positionChanged',false,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_relocation_quote_v1(uuid,uuid,uuid,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
