BEGIN;
-- Read-only one-off maintenance trip quote, not a commercial schedule.
-- Passenger load and ticket revenue are always zero. No reservation or ledger writes.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_maintenance_relocation_quote_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_check text,p_airport text,p_provider text,p_start timestamptz DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE f record; pos jsonb; offers jsonb; offer jsonb; origin text; v_now timestamptz; dep timestamptz; arr timestamptz; service_start timestamptz; service_end timestamptz; ret_dep timestamptz; ret_arr timestamptz; available_at timestamptz; out_q jsonb; back_q jsonb; screen_out jsonb; screen_back jsonb; slot_proof jsonb; licence_out jsonb; licence_back jsonb; total numeric; reasons text[]:=ARRAY[]::text[]; turnaround int:=45; mins int; check_cost numeric; balance numeric; reserved numeric;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELOCATION_QUOTE_ONLY';END IF;
 SELECT i.configuration_id INTO f FROM airlinerra_game.airline_aircraft_inventory i JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.world_id=1 AND a.owner_player_id=p_player JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE i.id=p_aircraft AND i.airline_id=p_airline AND i.fleet_status='in_service' AND i.ownership_type IN ('owned','leased');
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='RELOCATION_AIRCRAFT_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 dep:=coalesce(p_start,date_trunc('minute',v_now)+interval '10 minutes');
 IF dep<v_now+interval '1 minute' OR dep>v_now+interval '7 days' THEN RETURN jsonb_build_object('status','invalid_relocation_start','readOnly',true,'ledgerPosted',false);END IF;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,p_aircraft,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR pos->>'airportKey' IS NULL THEN RETURN jsonb_build_object('status','relocation_aircraft_position_unavailable','readOnly',true,'ledgerPosted',false);END IF;
 origin:=pos->>'airportKey';
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 a WHERE a.world_id=1 AND a.airport_key=origin AND a.operationally_authorized AND a.dispatch_eligible_by_airport_admission) THEN RETURN jsonb_build_object('status','relocation_origin_unavailable','readOnly',true,'ledgerPosted',false);END IF;
 offers:=airlinerra_game.section9_owned_ai_maintenance_quotes_v1(p_player,p_airline,p_aircraft,p_check,p_airport);
 SELECT value INTO offer FROM jsonb_array_elements(offers->'quotes') WHERE value->>'providerKey'=p_provider AND value->>'airportKey'=p_airport;
 IF offer IS NULL THEN RETURN jsonb_build_object('status','invalid_provider_offer','readOnly',true,'ledgerPosted',false);END IF;
 mins:=(offer->>'durationMinutes')::int;check_cost:=(offer->>'priceUsd')::numeric;
 IF origin=p_airport THEN RETURN jsonb_build_object('status','relocation_not_required','originAirportKey',origin,'provider',offer,'readOnly',true,'ledgerPosted',false);END IF;
 out_q:=airlinerra_game.section9_owned_route_commercial_forecast_v1(p_player,p_airline,p_aircraft,origin,p_airport,'remote','remote',turnaround,0,0);
 back_q:=airlinerra_game.section9_owned_route_commercial_forecast_v1(p_player,p_airline,p_aircraft,p_airport,origin,'remote','remote',turnaround,0,0);
 IF out_q->>'status' IS DISTINCT FROM 'route_phase1_forecast' OR back_q->>'status' IS DISTINCT FROM 'route_phase1_forecast' OR out_q->>'estimatedPassengers' IS DISTINCT FROM '0' OR back_q->>'estimatedPassengers' IS DISTINCT FROM '0' THEN RETURN jsonb_build_object('status','relocation_cost_model_unavailable','readOnly',true,'ledgerPosted',false);END IF;
 arr:=dep+make_interval(mins=>(out_q#>>'{phases,totalMinutes}')::int);
 service_start:=arr+make_interval(mins=>turnaround);
 service_end:=service_start+make_interval(mins=>mins);
 ret_dep:=service_end+make_interval(mins=>turnaround);
 ret_arr:=ret_dep+make_interval(mins=>(back_q#>>'{phases,totalMinutes}')::int);
 available_at:=ret_arr+make_interval(mins=>turnaround);
 total:=(out_q->>'directOperatingCostUsd')::numeric+(back_q->>'directOperatingCostUsd')::numeric+check_cost;
 IF out_q#>>'{fuel,withinGameTankIncludingReserve}' IS DISTINCT FROM 'true' OR back_q#>>'{fuel,withinGameTankIncludingReserve}' IS DISTINCT FROM 'true' THEN reasons:=array_append(reasons,'FUEL_RANGE_NOT_CONFIRMED');END IF;
 screen_out:=airlinerra_game.section5_universal_route_restriction_gate_v1(1::smallint,origin,p_airport,f.configuration_id,dep,arr,NULL,NULL);
 screen_back:=airlinerra_game.section5_universal_route_restriction_gate_v1(1::smallint,p_airport,origin,f.configuration_id,ret_dep,ret_arr,NULL,NULL);
 IF screen_out->>'gameHardBlocked' IS DISTINCT FROM 'false' OR screen_back->>'gameHardBlocked' IS DISTINCT FROM 'false' OR screen_out->>'needsReview' IS DISTINCT FROM 'false' OR screen_back->>'needsReview' IS DISTINCT FROM 'false' THEN reasons:=array_append(reasons,'AIRPORT_RESTRICTION_SCREEN_REQUIRES_REVIEW');END IF;
 licence_out:=airlinerra_game.section9_game_route_licence_scope_v1(p_airline,origin,p_airport,(dep AT TIME ZONE 'Europe/Berlin')::date,0);
 licence_back:=airlinerra_game.section9_game_route_licence_scope_v1(p_airline,p_airport,origin,(ret_dep AT TIME ZONE 'Europe/Berlin')::date,0);
 IF licence_out->>'allowed' IS DISTINCT FROM 'true' OR licence_back->>'allowed' IS DISTINCT FROM 'true' THEN reasons:=array_append(reasons,'GAME_ROUTE_LICENCE_SCOPE_NOT_CONFIRMED');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j WHERE j.aircraft_inventory_id=p_aircraft AND j.status IN ('scheduled','in_progress','payment_required') AND j.game_start_utc<available_at AND (j.game_end_utc>v_now OR j.status='payment_required')) THEN reasons:=array_append(reasons,'EXISTING_MAINTENANCE_RESERVATION');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.status='active' AND s.version=o.schedule_version WHERE o.aircraft_inventory_id=p_aircraft AND o.airline_id=p_airline AND o.departure_utc>=v_now AND o.departure_utc<dep) THEN reasons:=array_append(reasons,'FUTURE_POSITION_NOT_CONFIRMED');END IF;
 -- Split the check to honour the existing maximum maintenance-window horizon.
 slot_proof:=airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(p_player,p_airline,p_aircraft,dep,service_start);
 IF slot_proof->>'slotClear' IS DISTINCT FROM 'true' THEN reasons:=array_append(reasons,'OUTBOUND_AIRCRAFT_SCHEDULE_CONFLICT');END IF;
 slot_proof:=airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(p_player,p_airline,p_aircraft,service_start,service_end);
 IF slot_proof->>'slotClear' IS DISTINCT FROM 'true' THEN reasons:=array_append(reasons,'MAINTENANCE_AIRCRAFT_SCHEDULE_CONFLICT');END IF;
 slot_proof:=airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(p_player,p_airline,p_aircraft,service_end,available_at);
 IF slot_proof->>'slotClear' IS DISTINCT FROM 'true' THEN reasons:=array_append(reasons,'RETURN_AIRCRAFT_SCHEDULE_CONFLICT');END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_game_maintenance_jobs_v1 j WHERE j.provider_key=p_provider AND j.status IN ('scheduled','in_progress','payment_required') AND j.game_start_utc<service_end AND (j.game_end_utc>service_start OR j.status='payment_required')) >= (offer->>'designCapacity')::int THEN reasons:=array_append(reasons,'PROVIDER_CAPACITY_UNAVAILABLE');END IF;
 SELECT coalesce(sum(amount_usd),0) INTO balance FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 SELECT coalesce(sum(quoted_cost_usd),0) INTO reserved FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND status IN ('scheduled','in_progress','payment_required');
 IF balance-reserved<total THEN reasons:=array_append(reasons,'INSUFFICIENT_AVAILABLE_FUNDS');END IF;
 RETURN jsonb_build_object('status','maintenance_relocation_quote','readOnly',true,'ledgerPosted',false,'bookable',false,'aircraftInventoryId',p_aircraft,'originAirportKey',origin,'providerAirportKey',p_airport,'provider',offer,
 'outbound',jsonb_build_object('departureUtc',dep,'arrivalUtc',arr,'availableUtc',service_start,'flightMinutes',out_q#>'{phases,totalMinutes}','distanceKm',out_q#>'{phases,distanceKm}','fuelBurnKg',out_q#>'{fuel,tripBurnKg}','requiredFuelOnboardKg',out_q#>'{fuel,minimumPlannedFuelOnBoardKg}','fuelCostUsd',out_q->'fuelCostUsd','airportFeesUsd',out_q->'airportFeesUsd','feeLinesUsd',out_q->'feeLinesUsd','totalUsd',out_q->'directOperatingCostUsd'),
 'maintenance',jsonb_build_object('startUtc',service_start,'endUtc',service_end,'durationMinutes',mins,'priceUsd',check_cost),
 'return',jsonb_build_object('departureUtc',ret_dep,'arrivalUtc',ret_arr,'availableUtc',available_at,'flightMinutes',back_q#>'{phases,totalMinutes}','distanceKm',back_q#>'{phases,distanceKm}','fuelBurnKg',back_q#>'{fuel,tripBurnKg}','requiredFuelOnboardKg',back_q#>'{fuel,minimumPlannedFuelOnBoardKg}','fuelCostUsd',back_q->'fuelCostUsd','airportFeesUsd',back_q->'airportFeesUsd','feeLinesUsd',back_q->'feeLinesUsd','totalUsd',back_q->'directOperatingCostUsd'),
 'totalEstimatedUsd',round(total,2),'totalDowntimeMinutes',round(extract(epoch FROM available_at-dep)/60)::int,'passengers',0,'ticketRevenueUsd',0,'turnaroundMinutes',turnaround,'preliminaryBlockers',to_jsonb(reasons),'airportSlotsReserved',false,'providerCapacityReserved',false,'positionChanged',false,'expensesExcluded',jsonb_build_array('crew costs deferred','ownership overhead','maintenance hangar parking assumed included in provider tariff'),'note','Planning estimate only. One-off slot reservation and signed relocation dispatch are not released.');
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_maintenance_relocation_quote_v1(uuid,uuid,uuid,text,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;