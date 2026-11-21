BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_reserve_maintenance_relocation_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_check text, p_airport text, p_provider text, p_start timestamp with time zone, p_expected_total numeric, p_request uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE q jsonb; trip uuid; prior record; cap int; service_start timestamptz; service_end timestamptz; funds numeric; committed numeric; v_now timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELOCATION_RESERVATION_ONLY';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory i JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.owner_player_id=p_player AND a.world_id=1 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE i.id=p_aircraft AND i.airline_id=p_airline AND i.fleet_status='in_service' AND i.ownership_type IN ('owned','leased') FOR UPDATE OF i;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='RELOCATION_AIRCRAFT_NOT_OWNED';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND reservation_enabled AND execution_enabled) THEN RETURN jsonb_build_object('status','relocation_execution_not_released','created',false,'ledgerPosted',false);END IF;
 IF p_start IS NULL OR p_start<>date_trunc('second',p_start) OR p_expected_total IS NULL OR p_request IS NULL THEN RETURN jsonb_build_object('status','relocation_confirmation_required','created',false);END IF;
 SELECT * INTO prior FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE airline_id=p_airline AND request_key=p_request;
 IF FOUND THEN
  IF prior.aircraft_inventory_id<>p_aircraft OR prior.provider_key<>p_provider OR prior.provider_airport_key<>p_airport OR prior.check_code<>p_check OR prior.departure_utc<>p_start OR prior.quoted_total_usd<>p_expected_total THEN RETURN jsonb_build_object('status','relocation_request_key_conflict','created',false);END IF;
  RETURN jsonb_build_object('status',prior.status,'tripId',prior.id,'created',false,'replayed',true,'ledgerPosted',false);
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=p_aircraft AND status='reserved') THEN RETURN jsonb_build_object('status','aircraft_relocation_already_reserved','created',false);END IF;
 q:=airlinerra_game.section9_owned_maintenance_relocation_quote_v1(p_player,p_airline,p_aircraft,p_check,p_airport,p_provider,p_start);
 IF q->>'status' IS DISTINCT FROM 'maintenance_relocation_quote' OR q->>'totalEstimatedUsd' IS NULL OR jsonb_array_length(q->'preliminaryBlockers')<>0 THEN RETURN jsonb_build_object('status','relocation_quote_blocked','created',false,'quote',q);END IF;
 IF (q->>'totalEstimatedUsd')::numeric<>p_expected_total THEN RETURN jsonb_build_object('status','relocation_price_changed','created',false,'quote',q);END IF;
 IF airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(p_player,p_airline,p_aircraft,(q#>>'{outbound,departureUtc}')::timestamptz,(q#>>'{outbound,arrivalUtc}')::timestamptz)->>'gameMaintenanceClear' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','outbound_maintenance_not_ready','created',false,'ledgerPosted',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE aircraft_inventory_id=p_aircraft AND status IN ('scheduled','in_progress','payment_required')) THEN RETURN jsonb_build_object('status','aircraft_maintenance_already_reserved','created',false);END IF;
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=1 AND airport_key IN(q->>'originAirportKey',p_airport) ORDER BY airport_key FOR UPDATE;
 PERFORM pg_advisory_xact_lock(583734,hashtext(p_provider));
 service_start:=(q#>>'{maintenance,startUtc}')::timestamptz;service_end:=(q#>>'{maintenance,endUtc}')::timestamptz;cap:=(q#>>'{provider,designCapacity}')::int;
 IF (SELECT count(*) FROM airlinerra_game.section9_game_maintenance_jobs_v1 j WHERE provider_key=p_provider AND status IN ('scheduled','in_progress','payment_required') AND game_start_utc<service_end AND (game_end_utc>service_start OR status='payment_required'))+(SELECT count(*) FROM airlinerra_game.section9_maintenance_relocation_trips_v1 t WHERE provider_key=p_provider AND status='reserved' AND (quote#>>'{maintenance,startUtc}')::timestamptz<service_end AND (quote#>>'{maintenance,endUtc}')::timestamptz>service_start)>=cap THEN RETURN jsonb_build_object('status','provider_capacity_unavailable','created',false);END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline FOR UPDATE;
 SELECT coalesce(sum(amount_usd),0) INTO funds FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 SELECT coalesce(sum(quoted_cost_usd),0) INTO committed FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND status IN ('scheduled','in_progress','payment_required');
 committed:=committed+(SELECT coalesce(sum(quoted_total_usd),0) FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE airline_id=p_airline AND status='reserved');
 IF funds-committed<p_expected_total THEN RETURN jsonb_build_object('status','relocation_insufficient_funds','created',false);END IF;
 BEGIN
 INSERT INTO airlinerra_game.section9_maintenance_relocation_trips_v1(airline_id,aircraft_inventory_id,owner_player_id,request_key,origin_airport_key,provider_airport_key,provider_key,check_code,departure_utc,available_utc,quoted_total_usd,quote)
 VALUES(p_airline,p_aircraft,p_player,p_request,q->>'originAirportKey',p_airport,p_provider,p_check,p_start,(q#>>'{return,availableUtc}')::timestamptz,p_expected_total,q) RETURNING id INTO trip;
 INSERT INTO airlinerra_game.section6_dated_relocation_slots_v1(trip_id,leg,airport_key,direction,movement_utc,local_date,weekday,minute_of_day)
 VALUES(trip,'outbound',q->>'originAirportKey','departure',(q#>>'{outbound,departureUtc}')::timestamptz,current_date,0,0),
 (trip,'outbound',p_airport,'arrival',(q#>>'{outbound,arrivalUtc}')::timestamptz,current_date,0,0),
 (trip,'return',p_airport,'departure',(q#>>'{return,departureUtc}')::timestamptz,current_date,0,0),
 (trip,'return',q->>'originAirportKey','arrival',(q#>>'{return,arrivalUtc}')::timestamptz,current_date,0,0);
 EXCEPTION WHEN raise_exception THEN
 IF SQLERRM LIKE 'RELOCATION_%' THEN RETURN jsonb_build_object('status','relocation_slot_reservation_blocked','created',false,'reason',SQLERRM,'ledgerPosted',false);END IF;RAISE;
 END;
 RETURN jsonb_build_object('status','reserved','created',true,'tripId',trip,'slotsReserved',4,'passengers',0,'ticketRevenueUsd',0,'ledgerPosted',false,'executionVerified',false);
END $function$;
COMMIT;
