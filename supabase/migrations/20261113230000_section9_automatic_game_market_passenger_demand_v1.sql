-- Airlinerra GAME-ONLY automatic passenger demand.
-- Reuses Section 7 origin market and seasonal priorities, not real observed
-- airline sales; market capture and price sensitivity are explicit
-- versioned gameplay assumptions.
-- Quotes are deterministic and budget-aware across competing in-game
-- flights; reservations only enter the existing trusted atomic writer.
-- An existing staged connecting itinerary hold counts against seat inventory
-- before the model adds direct-route demand. Never book those seats twice.
-- This job is fail-closed until flight operation AND financial settlement
-- are independently released. Crew remains deferred.
-- No direct SQL grants for browsers and no upfront ticket revenue.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_market_passenger_quote_v1(p_origin text, p_destination text, p_game_date date, p_fare_usd numeric, p_flight_minutes integer, p_verified_seats integer, p_market_seats integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 market jsonb;
 market_daily numeric;
 reference_fare numeric;
 price_factor numeric;
 seat_share numeric;
 stable_spread numeric;
 capture_rate numeric:=0.35;
 full_seats integer;
BEGIN
 IF p_origin IS NULL OR p_destination IS NULL OR p_origin=p_destination
 OR p_game_date IS NULL OR p_game_date NOT BETWEEN date '2000-01-01' AND date '2199-12-31'
 OR p_fare_usd IS NULL OR p_fare_usd NOT BETWEEN 1 AND 100000
 OR p_flight_minutes IS NULL OR p_flight_minutes NOT BETWEEN 15 AND 4320
 OR p_verified_seats IS NULL OR p_verified_seats NOT BETWEEN 1 AND 1000
 OR p_market_seats IS NULL OR p_market_seats NOT BETWEEN 1 AND 1000000
 OR p_market_seats<p_verified_seats
 THEN RETURN jsonb_build_object('status','invalid_game_demand_inputs',
   'modelVersion','GAME_ONLY_PASSENGER_CAPTURE_V1',
   'readOnly',true,'passengerBookingsCreated',0,'ledgerPosted',false);
 END IF;
 -- Existing Section 7 model: route budget and seasonal destination priorities.
 -- No invented route traffic values from an empty market-demand table.
 market:=airlinerra_game.section9_route_market_preview_v1(
  1::smallint,p_origin,p_destination,extract(month from p_game_date)::smallint);
 IF market->>'model' IS DISTINCT FROM 'section9_monthly_market_preview_v1'
 OR market->>'originAirportKey' IS DISTINCT FROM p_origin
 OR market->>'destinationAirportKey' IS DISTINCT FROM p_destination
 OR market->>'month' IS DISTINCT FROM extract(month from p_game_date)::text
 OR market->>'directPassengersPerDay' IS NULL
 OR jsonb_typeof(market->'directPassengersPerDay')<>'number'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_market',
   'readOnly',true,'passengerBookingsCreated',0,'ledgerPosted',false);
 END IF;
 market_daily:=least(1000000,greatest(0,(market->>'directPassengersPerDay')::numeric));
 -- Game assumptions, NOT historical airline prices or real bookings.
 -- The flight's existing verified schedule duration supplies a neutral
 -- comparative fare to discourage unrealistically expensive tickets.
 reference_fare:=greatest(45,least(650,45+p_flight_minutes*0.65));
 price_factor:=greatest(0.25,least(1.20,
   sqrt(reference_fare/greatest(1,p_fare_usd))));
 seat_share:=p_verified_seats::numeric/p_market_seats::numeric;
 -- Stable per route + date (not a changing random call on cron retry).
 -- ±7.5% variation keeps dates from looking identical.
 stable_spread:=0.925+0.15*(get_byte(
  decode(md5(p_origin||'>'||p_destination||':'||p_game_date::text),'hex'),0)::numeric/255);
 full_seats:=least(p_verified_seats,greatest(0,
  floor(market_daily*capture_rate*seat_share*price_factor*stable_spread)::integer));
 RETURN jsonb_build_object(
 'status','game_market_demand_estimate',
 'modelVersion','GAME_ONLY_PASSENGER_CAPTURE_V1',
 'evidenceType','SECTION7_GAME_ESTIMATE_NOT_REAL_WORLD_BOOKINGS',
 'readOnly',true,
 'date',p_game_date,'origin',p_origin,'destination',p_destination,
 'totalRouteMarketPassengersPerDay',market_daily,
 'assumedGameMarketCaptureFraction',capture_rate,
 'priceReferenceGameUsd',round(reference_fare,2),
 'priceSensitivityFactor',round(price_factor,4),
 'marketSeatShare',round(seat_share,4),
 'dailyVariabilityFactor',round(stable_spread,4),
 'fullWindowTargetSeats',full_seats,
 'aircraftSeats',p_verified_seats,
 'realWorldDemandVerified',false,
 'actualAirlineCompetitionModeled',false,
 'passengerBookingsCreated',0,'ticketRevenuePosted',false,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_game_market_passenger_quote_v1(text,text,date,numeric,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_flight_demand_target_v1(p_occurrence uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 occ record;inv record;market_seats integer;quoted jsonb;
 verified_hour jsonb;now_utc timestamptz;
 window_result jsonb;
 remaining_seconds numeric;booking_fraction numeric;
 full_target integer;progress_target integer;unheld_target integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_GAME_DEMAND_QUOTE_ENGINE_ONLY';END IF;
 IF p_occurrence IS NULL THEN RETURN jsonb_build_object(
 'status','blocked_missing_occurrence','readOnly',true,
 'bookingsCreated',false,'ledgerPosted',false);END IF;
 verified_hour:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF verified_hour->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'readOnly',true,'bookingsCreated',false,'ledgerPosted',false);END IF;
 now_utc:=(verified_hour->>'gameHourUtc')::timestamptz;

 SELECT o.*,s.reference_departure_utc,s.reference_arrival_utc,
  s.status schedule_status,s.operationally_verified,
  s.version current_version,
  f.fleet_status,
  plan.economy_fare_usd,plan.version commercial_version
 INTO occ
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
 ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory f
 ON f.id=o.aircraft_inventory_id AND f.airline_id=o.airline_id
 JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
 ON plan.schedule_id=o.schedule_id AND plan.airline_id=o.airline_id
 WHERE o.id=p_occurrence;
 IF NOT FOUND OR occ.source_kind<>'game_verified_saleable_schedule_v1'
 OR occ.booking_status<>'open'
 OR occ.schedule_status<>'active'
 OR occ.operationally_verified IS DISTINCT FROM true
 OR occ.current_version<>occ.schedule_version
 OR occ.fleet_status<>'in_service'
 OR occ.economy_fare_usd IS NULL OR occ.economy_fare_usd<=0
 OR occ.verified_passenger_seats IS NULL OR occ.verified_passenger_seats<=0
 OR occ.reference_arrival_utc<=occ.reference_departure_utc
 THEN RETURN jsonb_build_object('status','blocked_unverified_saleable_occurrence',
  'readOnly',true,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT * INTO inv FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id=occ.schedule_id::text||':'||
   occ.flight_local_date::text||':'||occ.weekly_entry::text;
 IF NOT FOUND OR inv.airline_id<>occ.airline_id
 OR inv.schedule_id<>occ.schedule_id
 OR inv.schedule_version<>occ.schedule_version
 OR inv.commercial_version<>occ.commercial_version
 OR inv.passenger_capacity<>occ.verified_passenger_seats
 OR inv.passengers_held<occ.booked_seats
 OR inv.passengers_held>inv.passenger_capacity
 OR inv.departure_utc<>occ.departure_utc
 OR inv.status<>'preflight_only'
 THEN RETURN jsonb_build_object('status','blocked_capacity_or_bookings_not_reconciled',
  'readOnly',true,'bookingsCreated',false,'ledgerPosted',false);END IF;
 window_result:=airlinerra_game.section9_verified_saleable_departure_window_v1(
  occ.schedule_id,occ.flight_local_date,occ.weekly_entry,now_utc);
 IF window_result->>'withinWindow' IS DISTINCT FROM 'true'
 OR EXISTS(
 SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.schedule_id=occ.schedule_id
 AND m.flight_local_date=occ.flight_local_date
 AND m.weekly_entry=occ.weekly_entry)
 THEN RETURN jsonb_build_object('status','blocked_outside_real_booking_window',
  'readOnly',true,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(o.verified_passenger_seats),0)::integer INTO market_seats
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.world_id=1
 AND o.flight_local_date=occ.flight_local_date
 AND o.origin_airport_key=occ.origin_airport_key
 AND o.destination_airport_key=occ.destination_airport_key
 AND o.source_kind='game_verified_saleable_schedule_v1'
 AND o.booking_status IN('open','closed')
 AND o.verified_passenger_seats>0;
 IF market_seats<occ.verified_passenger_seats
 THEN RETURN jsonb_build_object('status','blocked_shared_route_market_capacity',
  'readOnly',true,'bookingsCreated',false,'ledgerPosted',false);END IF;
 quoted:=airlinerra_game.section9_game_market_passenger_quote_v1(
  occ.origin_airport_key,occ.destination_airport_key,occ.flight_local_date,
  occ.economy_fare_usd,
  greatest(15,ceil(extract(epoch FROM (
    occ.reference_arrival_utc-occ.reference_departure_utc))/60)::integer),
  occ.verified_passenger_seats,market_seats);
 IF quoted->>'status' IS DISTINCT FROM 'game_market_demand_estimate'
 THEN RETURN jsonb_build_object('status','blocked_missing_game_market_model',
   'readOnly',true,'bookingsCreated',false,'ledgerPosted',false);END IF;
 full_target:=(quoted->>'fullWindowTargetSeats')::integer;
 remaining_seconds:=extract(epoch FROM(occ.departure_utc-now_utc));
 booking_fraction:=greatest(0,least(1,1-remaining_seconds/604800));
 progress_target:=least(occ.verified_passenger_seats,greatest(0,
  floor(full_target*(0.10+0.90*booking_fraction))::integer));
 -- Inventory held includes both actual booked tickets and unissued
 -- connecting itinerary holds. Subtract ALL held seats to avoid
 -- generating demand on top of existing itinerary allocations.
 unheld_target:=greatest(0,least(
  progress_target-inv.passengers_held,
  inv.passenger_capacity-inv.passengers_held));
 RETURN jsonb_build_object(
 'status','verified_demand_target_game_estimate',
 'modelVersion','GAME_ONLY_PASSENGER_CAPTURE_V1',
 'occurrenceId',occ.id,
 'routeMarketBasis',quoted->>'evidenceType',
 'readOnly',true,'gameHourUtc',now_utc,
 'referenceFareUsd',quoted->'priceReferenceGameUsd',
 'totalRouteMarketDailyPassengers',quoted->'totalRouteMarketPassengersPerDay',
 'bookablePassengerCapacity',occ.verified_passenger_seats,
 'alreadyBookedSeats',occ.booked_seats,
 'allHeldAndBookedSeats',inv.passengers_held,
 'fullWindowTargetSeats',full_target,
 'targetSeatsAsOfGameHour',progress_target,
 'newPassengerSeatsSuggested',unheld_target,
 'daysBeforeDeparture',round(remaining_seconds/86400,3),
 'passengerBookingsCreated',0,'revenuePosted',false,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_verified_flight_demand_target_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_reserve_verified_flight_demand_v1(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 release_row record;exec_row record;ready_row record;
 v_clock jsonb;rec record;forecast jsonb;booked jsonb;
 book_key text;
 desired integer;scanned integer:=0;processed integer:=0;
 new_seats integer:=0;skipped integer:=0;
 blocked integer:=0;reason text;
 warnings jsonb:='{}'::jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_AUTO_DEMAND_BOOKING_POSTGRES_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_AUTO_DEMAND_BOOKING_INVALID_LIMIT';END IF;
 v_clock:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF v_clock->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'scanned',0,'bookedSeats',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 SELECT release_state,enabled_at,crew_mode INTO release_row
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO exec_row
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO ready_row
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF release_row.release_state IS DISTINCT FROM 'enabled'
 OR release_row.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR release_row.enabled_at IS NULL
 OR exec_row.release_state IS DISTINCT FROM 'enabled'
 OR exec_row.enabled_at IS NULL
 OR ready_row.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR ready_row.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR ready_row.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_flight_operation_release',
  'scanned',0,'bookedSeats',0,'ledgerPosted',false,'movementRecorded',false);
 END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10031) THEN
 RETURN jsonb_build_object('status','demand_worker_already_running',
  'scanned',0,'bookedSeats',0,'ledgerPosted',false,'movementRecorded',false);END IF;

 FOR rec IN
  SELECT o.id,o.schedule_id,o.flight_local_date,o.weekly_entry,
   o.departure_utc,o.schedule_id::text||':'||
      o.flight_local_date::text||':'||o.weekly_entry::text as physical_key
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
    ON s.id=o.schedule_id AND s.airline_id=o.airline_id
  WHERE o.world_id=1 AND o.booking_status='open'
   AND o.source_kind='game_verified_saleable_schedule_v1'
   AND s.status='active' AND s.operationally_verified=true
   AND o.departure_utc>(v_clock->>'gameHourUtc')::timestamptz
   AND o.departure_utc<=(v_clock->>'gameHourUtc')::timestamptz+interval '7 days'
  ORDER BY o.schedule_id,o.flight_local_date,o.weekly_entry
  LIMIT p_limit
 LOOP
  scanned:=scanned+1;
  -- Lock inventory FIRST, matching the direct-ticket and itinerary writer.
  PERFORM 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
  WHERE cap.physical_flight_id=rec.physical_key FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_AUTO_DEMAND_MISSING_CAPACITY';END IF;
  forecast:=airlinerra_game.section9_verified_flight_demand_target_v1(rec.id);
  IF forecast->>'status' IS DISTINCT FROM 'verified_demand_target_game_estimate'
  OR forecast->>'readOnly' IS DISTINCT FROM 'true'
  OR forecast->>'ledgerPosted' IS DISTINCT FROM 'false'
  THEN
   blocked:=blocked+1;
   reason:=coalesce(forecast->>'status','missing_game_demand_quote');
   warnings:=jsonb_set(warnings,ARRAY[reason],
    to_jsonb(coalesce((warnings->>reason)::int,0)+1),true);
   CONTINUE;
  END IF;
  desired:=(forecast->>'newPassengerSeatsSuggested')::int;
  IF desired IS NULL OR desired<0 OR desired>1000
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_INVALID_AUTO_DEMAND_QUANTITY';END IF;
  IF desired=0 THEN skipped:=skipped+1;CONTINUE;END IF;
  -- One deterministic key per five-minute period and flight.
  -- Replaying the worker cannot make a second reservation for that key.
  book_key:='auto.demand.v1.'||replace(rec.id::text,'-','')||'.'||
    to_char(date_trunc('minute',
     (v_clock->>'gameHourUtc')::timestamptz) AT TIME ZONE 'UTC',
     'YYYYMMDDHH24MI');
  IF EXISTS(SELECT 1
     FROM airlinerra_game.section9_passenger_reservation_batches_v1 b
     WHERE b.reservation_key=book_key AND b.occurrence_id=rec.id)
  THEN skipped:=skipped+1;CONTINUE;END IF;
  booked:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
    rec.id,book_key,'economy',desired);
  IF booked->>'status'='game_passenger_seats_reserved'
   AND booked->>'seatsReservedNow'=desired::text
   AND booked->>'chargedNow'='false'
   AND booked->>'ledgerPosted'='false'
   AND booked->>'revenueRecognizedNow'='false'
  THEN processed:=processed+1;new_seats:=new_seats+desired;
  ELSIF booked->>'status' IN ('blocked_insufficient_available_seats',
    'blocked_stale_or_unverified_saleable_inventory',
    'blocked_slots_or_flight_already_operated',
    'blocked_booking_window_or_unreleased_engine')
   AND booked->>'ledgerPosted'='false'
   AND booked->>'chargedNow'='false'
  THEN
   blocked:=blocked+1;
   reason:=booked->>'status';
   warnings:=jsonb_set(warnings,ARRAY[reason],
      to_jsonb(coalesce((warnings->>reason)::int,0)+1),true);
  ELSE RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_UNSAFE_AUTOMATIC_DEMAND_BOOKING_RESPONSE';END IF;
 END LOOP;
 RETURN jsonb_build_object('status','automatic_game_passenger_demand_processed',
 'gameHourUtc',v_clock->>'gameHourUtc',
 'modelVersion','GAME_ONLY_PASSENGER_CAPTURE_V1',
 'scanned',scanned,'bookingBatchesCreated',processed,
 'bookedSeats',new_seats,'skipped',skipped,'blocked',blocked,
 'blockerCounts',warnings,
 'revenueRecognized',false,'ledgerPosted',false,'movementRecorded',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_reserve_verified_flight_demand_v1(integer) FROM PUBLIC,anon,authenticated,service_role;

DO $demand_cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job
 WHERE jobname='airlinerra-game-route-passenger-demand-v1') THEN
  PERFORM cron.schedule('airlinerra-game-route-passenger-demand-v1',
    '*/5 * * * *',
    'SELECT airlinerra_game.section9_auto_reserve_verified_flight_demand_v1(50);');
 END IF;
END $demand_cron$;
