BEGIN;
-- One-off relocation reservation foundation. Release remains disabled until
-- movement, maintenance and expense settlement are verified end to end.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_relocation_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),reservation_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_relocation_release_v1 VALUES(1,false) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_maintenance_relocation_trips_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 owner_player_id uuid NOT NULL,request_key uuid NOT NULL,
 origin_airport_key text NOT NULL,provider_airport_key text NOT NULL CHECK(provider_airport_key<>origin_airport_key),
 provider_key text NOT NULL,check_code text NOT NULL REFERENCES airlinerra_game.maintenance_check_policy_v1(check_code),
 departure_utc timestamptz NOT NULL,available_utc timestamptz NOT NULL CHECK(available_utc>departure_utc),
 quoted_total_usd numeric(14,2) NOT NULL CHECK(quoted_total_usd>0),
 quote jsonb NOT NULL CHECK(quote->>'passengers'='0' AND quote->>'ticketRevenueUsd'='0'),
 status text NOT NULL DEFAULT 'reserved' CHECK(status IN ('reserved','cancelled','completed')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airline_id,request_key)
);
CREATE UNIQUE INDEX IF NOT EXISTS section9_one_reserved_relocation_per_tail_v1 ON airlinerra_game.section9_maintenance_relocation_trips_v1(aircraft_inventory_id) WHERE status='reserved';
CREATE TABLE IF NOT EXISTS airlinerra_game.section6_dated_relocation_slots_v1(
 trip_id uuid NOT NULL REFERENCES airlinerra_game.section9_maintenance_relocation_trips_v1(id) ON DELETE CASCADE,
 leg text NOT NULL CHECK(leg IN ('outbound','return')),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL,stand_type text NOT NULL DEFAULT 'remote' CHECK(stand_type='remote'),
 direction text NOT NULL CHECK(direction IN ('arrival','departure')),
 movement_utc timestamptz NOT NULL,local_date date NOT NULL,
 weekday smallint NOT NULL CHECK(weekday BETWEEN 0 AND 6),
 minute_of_day smallint NOT NULL CHECK(minute_of_day BETWEEN 0 AND 1430 AND minute_of_day%10=0),
 PRIMARY KEY(trip_id,leg,direction),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.section6_airport_slot_capacity_v1(world_id,airport_key),
 CHECK(weekday=extract(isodow FROM local_date)::int-1)
);
CREATE INDEX IF NOT EXISTS section6_dated_relocation_slot_window_v1 ON airlinerra_game.section6_dated_relocation_slots_v1(world_id,airport_key,stand_type,direction,local_date,minute_of_day);
ALTER TABLE airlinerra_game.section9_relocation_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_maintenance_relocation_trips_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section6_dated_relocation_slots_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_relocation_release_v1,airlinerra_game.section9_maintenance_relocation_trips_v1,airlinerra_game.section6_dated_relocation_slots_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section6_relocation_slot_guard_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE cap record; local_ts timestamp; tz text; weekly_hour int; weekly_window int; dated_hour int; dated_window int;
BEGIN
 SELECT * INTO cap FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key FOR UPDATE;
 IF NOT FOUND OR cap.remote_stands<=0 OR cap.remote_per_direction_10m<=0 THEN RAISE EXCEPTION 'RELOCATION_REMOTE_CAPACITY_UNAVAILABLE';END IF;
 SELECT timezone_iana INTO tz FROM airlinerra_game.section5_airport_operating_policy_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key;
 IF tz IS NULL THEN RAISE EXCEPTION 'RELOCATION_AIRPORT_TIMEZONE_UNAVAILABLE';END IF;
 local_ts:=NEW.movement_utc AT TIME ZONE tz;
 NEW.local_date:=local_ts::date; NEW.weekday:=extract(isodow FROM local_ts)::int-1;
 NEW.minute_of_day:=extract(hour FROM local_ts)::int*60+(extract(minute FROM local_ts)::int/10)*10;
 SELECT count(*) FILTER(WHERE minute_of_day/60=NEW.minute_of_day/60),count(*) FILTER(WHERE minute_of_day=NEW.minute_of_day) INTO weekly_hour,weekly_window
 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key AND stand_type=NEW.stand_type AND direction=NEW.direction AND weekday=NEW.weekday;
 SELECT count(*) FILTER(WHERE minute_of_day/60=NEW.minute_of_day/60),count(*) FILTER(WHERE minute_of_day=NEW.minute_of_day) INTO dated_hour,dated_window
 FROM airlinerra_game.section6_dated_relocation_slots_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key AND stand_type=NEW.stand_type AND direction=NEW.direction AND local_date=NEW.local_date;
 IF weekly_hour+dated_hour+1>cap.remote_stands OR weekly_window+dated_window+1>cap.remote_per_direction_10m THEN RAISE EXCEPTION 'RELOCATION_AIRPORT_SLOT_UNAVAILABLE';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section6_relocation_slot_guard_v1() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS section6_relocation_slot_guard ON airlinerra_game.section6_dated_relocation_slots_v1;
CREATE TRIGGER section6_relocation_slot_guard BEFORE INSERT ON airlinerra_game.section6_dated_relocation_slots_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section6_relocation_slot_guard_v1();
CREATE OR REPLACE FUNCTION airlinerra_game.section6_weekly_relocation_capacity_guard_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE cap record; weekly_hour int; weekly_window int; peak_hour int; peak_window int;
BEGIN
 IF NEW.stand_type<>'remote' THEN RETURN NEW;END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section6_dated_relocation_slots_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key AND stand_type=NEW.stand_type AND direction=NEW.direction AND weekday=NEW.weekday AND minute_of_day/60=NEW.minute_of_day/60) THEN RETURN NEW;END IF;
 SELECT * INTO cap FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'SECTION6_AIRPORT_CAPACITY_NOT_CONFIGURED';END IF;
 SELECT coalesce(max(n),0) INTO peak_hour FROM (SELECT count(*) n FROM airlinerra_game.section6_dated_relocation_slots_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key AND stand_type=NEW.stand_type AND direction=NEW.direction AND weekday=NEW.weekday AND minute_of_day/60=NEW.minute_of_day/60 AND movement_utc>=airlinerra_game.section9_verified_world_instant_v1() GROUP BY local_date) q;
 SELECT coalesce(max(n),0) INTO peak_window FROM (SELECT count(*) n FROM airlinerra_game.section6_dated_relocation_slots_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key AND stand_type=NEW.stand_type AND direction=NEW.direction AND weekday=NEW.weekday AND minute_of_day=NEW.minute_of_day AND movement_utc>=airlinerra_game.section9_verified_world_instant_v1() GROUP BY local_date) q;
 IF peak_hour=0 AND peak_window=0 THEN RETURN NEW;END IF;
 SELECT count(*) FILTER(WHERE minute_of_day/60=NEW.minute_of_day/60),count(*) FILTER(WHERE minute_of_day=NEW.minute_of_day) INTO weekly_hour,weekly_window FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key AND stand_type=NEW.stand_type AND direction=NEW.direction AND weekday=NEW.weekday;
 IF weekly_hour+peak_hour+1>cap.remote_stands OR weekly_window+peak_window+1>cap.remote_per_direction_10m THEN RAISE EXCEPTION 'SECTION6_SLOT_CONFLICT_WITH_DATED_RELOCATION';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section6_weekly_relocation_capacity_guard_v1() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS section6_weekly_relocation_capacity_guard ON airlinerra_game.section6_weekly_airport_slot_reservations_v1;
CREATE TRIGGER section6_weekly_relocation_capacity_guard BEFORE INSERT ON airlinerra_game.section6_weekly_airport_slot_reservations_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section6_weekly_relocation_capacity_guard_v1();
CREATE OR REPLACE FUNCTION airlinerra_game.section9_reserve_maintenance_relocation_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_check text,p_airport text,p_provider text,p_start timestamptz,p_expected_total numeric,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE q jsonb; trip uuid; prior record; cap int; service_start timestamptz; service_end timestamptz; funds numeric; committed numeric; v_now timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELOCATION_RESERVATION_ONLY';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory i JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.owner_player_id=p_player AND a.world_id=1 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE i.id=p_aircraft AND i.airline_id=p_airline AND i.fleet_status='in_service' AND i.ownership_type IN ('owned','leased') FOR UPDATE OF i;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='RELOCATION_AIRCRAFT_NOT_OWNED';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND reservation_enabled) THEN RETURN jsonb_build_object('status','relocation_execution_not_released','created',false,'ledgerPosted',false);END IF;
 IF p_start IS NULL OR p_expected_total IS NULL OR p_request IS NULL THEN RETURN jsonb_build_object('status','relocation_confirmation_required','created',false);END IF;
 SELECT * INTO prior FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE airline_id=p_airline AND request_key=p_request;
 IF FOUND THEN
  IF prior.aircraft_inventory_id<>p_aircraft OR prior.provider_key<>p_provider OR prior.provider_airport_key<>p_airport OR prior.check_code<>p_check OR prior.departure_utc<>p_start OR prior.quoted_total_usd<>p_expected_total THEN RETURN jsonb_build_object('status','relocation_request_key_conflict','created',false);END IF;
  RETURN jsonb_build_object('status',prior.status,'tripId',prior.id,'created',false,'replayed',true,'ledgerPosted',false);
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=p_aircraft AND status='reserved') THEN RETURN jsonb_build_object('status','aircraft_relocation_already_reserved','created',false);END IF;
 q:=airlinerra_game.section9_owned_maintenance_relocation_quote_v1(p_player,p_airline,p_aircraft,p_check,p_airport,p_provider,p_start);
 IF q->>'status' IS DISTINCT FROM 'maintenance_relocation_quote' OR q->>'totalEstimatedUsd' IS NULL OR jsonb_array_length(q->'preliminaryBlockers')<>0 THEN RETURN jsonb_build_object('status','relocation_quote_blocked','created',false,'quote',q);END IF;
 IF (q->>'totalEstimatedUsd')::numeric<>p_expected_total THEN RETURN jsonb_build_object('status','relocation_price_changed','created',false,'quote',q);END IF;
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
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_reserve_maintenance_relocation_v1(uuid,uuid,uuid,text,text,text,timestamptz,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;