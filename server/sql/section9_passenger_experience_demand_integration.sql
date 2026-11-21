-- Integrate passenger experience collection and reputation-adjusted future direct bookings.
-- Existing seats, ticket price, settlement and itinerary holds remain unchanged.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_airline_reputation_v1(p_airline uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
 WITH clock AS (SELECT airlinerra_game.section9_verified_world_instant_v1() AS now_utc),
 stats AS (
 SELECT coalesce(sum(e.passengers),0) samples,coalesce(sum(e.score*e.passengers),0) weighted,
 count(*) events,coalesce(sum(e.passengers) FILTER(WHERE e.event_kind='arrived'),0) flown,
 coalesce(sum(e.passengers) FILTER(WHERE e.event_kind='cancelled'),0) cancelled,
 coalesce(sum(e.passengers) FILTER(WHERE e.event_kind='connection_rebooked'),0) rebooked,
 coalesce(sum(e.passengers) FILTER(WHERE e.event_kind='connection_lost'),0) lost
 FROM airlinerra_game.section9_passenger_experience_events_v1 e CROSS JOIN clock
 WHERE e.airline_id=p_airline AND e.happened_at>clock.now_utc-interval '90 days' AND e.happened_at<=clock.now_utc
 ), metric AS (SELECT *,round((weighted+70*200)/(samples+200),2) reputation FROM stats)
 SELECT jsonb_build_object('status','airline_reputation_game_estimate','reputation',reputation,'baseline',70,'windowDays',90,'priorPassengerExperiences',200,
 'passengerExperiences',samples,'experienceEvents',events,'arrivedPassengers',flown,'cancelledPassengers',cancelled,'rebookedPassengers',rebooked,'lostConnectionPassengers',lost,
 'averageSatisfaction',CASE WHEN samples>0 THEN round(weighted/samples,2) ELSE NULL END,
 'potentialDemandMultiplier',round(greatest(0.75,least(1.15,1+(reputation-70)/200)),4),
 'demandEffectEnabled',coalesce((SELECT collection_enabled AND demand_effect_enabled FROM airlinerra_game.section9_passenger_experience_release_v1 WHERE world_id=1),false),'modelVersion','GAME_PASSENGER_EXPERIENCE_V1')
 FROM metric CROSS JOIN clock WHERE clock.now_utc IS NOT NULL AND EXISTS(SELECT 1 FROM airlinerra_game.airlines a WHERE a.id=p_airline AND a.world_id=1);
$function$;
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
 base_target integer; reputation jsonb; reputation_multiplier numeric:=1; reputation_enabled boolean:=false;
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
 base_target:=(quoted->>'fullWindowTargetSeats')::integer;
 reputation:=airlinerra_game.section9_airline_reputation_v1(occ.airline_id);
 reputation_enabled:=coalesce((reputation->>'demandEffectEnabled')::boolean,false);
 IF reputation_enabled AND reputation->>'status'='airline_reputation_game_estimate' THEN
  reputation_multiplier:=greatest(0.75,least(1.15,coalesce((reputation->>'potentialDemandMultiplier')::numeric,1)));
 END IF;
 full_target:=least(occ.verified_passenger_seats,greatest(0,floor(base_target*reputation_multiplier)::integer));
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
 'baseFullWindowTargetSeats',base_target,
 'airlineReputation',reputation->'reputation',
 'reputationDemandMultiplier',reputation_multiplier,
 'reputationDemandEffectEnabled',reputation_enabled,
 'targetSeatsAsOfGameHour',progress_target,
 'newPassengerSeatsSuggested',unheld_target,
 'daysBeforeDeparture',round(remaining_seconds/86400,3),
 'passengerBookingsCreated',0,'revenuePosted',false,'ledgerPosted',false);
END $function$;
-- A dedicated bounded collector runs separately from movement and settlement,
-- so a scoring failure cannot roll back an otherwise valid flight.
SELECT cron.schedule('airlinerra-game-passenger-experience-v1','3,8,13,18,23,28,33,38,43,48,53,58 * * * *',
 'SELECT airlinerra_game.section9_collect_passenger_experience_v1(100);');
