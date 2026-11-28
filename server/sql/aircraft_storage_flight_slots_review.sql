-- REVIEW ONLY. One-way storage flight slot reservations, no flight execution.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_only_movement_limits_v1(
 world_id smallint NOT NULL CHECK(world_id=1),
 airport_key text NOT NULL,
 movements_per_direction_hour integer NOT NULL CHECK(movements_per_direction_hour>0),
 movements_per_direction_10m integer NOT NULL CHECK(movements_per_direction_10m>0 AND movements_per_direction_10m<=movements_per_direction_hour),
 approval_reference text NOT NULL CHECK(btrim(approval_reference)<>''),
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_airport_operational_profiles_v1(world_id,airport_key)
);
CREATE TABLE airlinerra_game.aircraft_storage_flight_slots_v1(
 request_id uuid NOT NULL REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 world_id smallint NOT NULL CHECK(world_id=1),
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 direction text NOT NULL CHECK(direction IN ('departure','arrival')),
 movement_utc timestamptz NOT NULL,
 local_date date NOT NULL, weekday smallint NOT NULL CHECK(weekday BETWEEN 0 AND 6),
 minute_of_day smallint NOT NULL CHECK(minute_of_day BETWEEN 0 AND 1439 AND minute_of_day%10=0),
 PRIMARY KEY(request_id,direction)
);
ALTER TABLE airlinerra_game.aircraft_storage_only_movement_limits_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_storage_flight_slots_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_only_movement_limits_v1,airlinerra_game.aircraft_storage_flight_slots_v1 FROM PUBLIC,anon,authenticated,service_role;
-- Caller holds the existing airport capacity row lock, or the dedicated
-- storage movement-limit row lock. Count all remote movements, not stored planes.
CREATE FUNCTION airlinerra_game.assert_storage_remote_slot_v1(p_airport text,p_day date,p_weekday integer,p_minute integer,p_direction text,p_hour_limit integer,p_window_limit integer,p_extra integer)
RETURNS void LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE h bigint; m bigint;
BEGIN
 SELECT count(*) FILTER(WHERE minute_of_day/60=p_minute/60),count(*) FILTER(WHERE minute_of_day=p_minute)
 INTO h,m FROM (
 SELECT minute_of_day FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
 WHERE world_id=1 AND airport_key=p_airport AND stand_type='remote' AND direction=p_direction AND weekday=p_weekday
 UNION ALL SELECT minute_of_day FROM airlinerra_game.section6_dated_relocation_slots_v1
 WHERE world_id=1 AND airport_key=p_airport AND stand_type='remote' AND direction=p_direction AND local_date=p_day
 UNION ALL SELECT minute_of_day FROM airlinerra_game.section9_dated_replacement_slots_v1
 WHERE world_id=1 AND airport_key=p_airport AND stand_type='remote' AND direction=p_direction AND local_date=p_day
 UNION ALL SELECT minute_of_day FROM airlinerra_game.aircraft_storage_flight_slots_v1
 WHERE world_id=1 AND airport_key=p_airport AND direction=p_direction AND local_date=p_day
 ) all_slots;
 IF p_hour_limit IS NULL OR p_window_limit IS NULL OR h+p_extra>p_hour_limit OR m+p_extra>p_window_limit
 THEN RAISE EXCEPTION 'STORAGE_FLIGHT_SLOT_UNAVAILABLE';END IF;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.assert_storage_remote_slot_v1(text,date,integer,integer,text,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.reserve_aircraft_storage_slots_v1(p_player uuid,p_airline uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; endpoint record; cap record; tz text; local_ts timestamp; day_key date; dow integer; minute_key integer; h integer; m integer; n integer; v_now timestamptz; q jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 -- Same airline -> aircraft -> request lock order as request creation.
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT t.* INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 t WHERE t.id=p_request AND t.airline_id=p_airline AND t.owner_player_id=p_player;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=p_airline AND fleet_status='in_service' AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aircraft_unavailable','slotsReserved',0);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 IF r.status<>'awaiting_slot_and_dispatch_release' THEN RETURN jsonb_build_object('status','request_not_pending','slotsReserved',0);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR r.departure_utc<v_now+interval '1 minute' THEN RETURN jsonb_build_object('status','request_departure_expired','slotsReserved',0);END IF;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(r.destination_airport_key,'storage_inbound')->>'eligible' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','storage_admission_blocked','slotsReserved',0);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=r.aircraft_inventory_id AND status='active')
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=r.aircraft_inventory_id AND status IN ('scheduled','in_progress','payment_required'))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND status='reserved')
 THEN RETURN jsonb_build_object('status','aircraft_commitment_conflict','slotsReserved',0);END IF;
 q:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,r.aircraft_inventory_id,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 IF q->>'verified' IS DISTINCT FROM 'true' OR q->>'atGroundAirport' IS DISTINCT FROM 'true' OR q->>'airportKey' IS DISTINCT FROM r.origin_airport_key
 THEN RETURN jsonb_build_object('status','aircraft_position_changed','slotsReserved',0);END IF;
 SELECT count(*) INTO n FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=r.id;
 IF n=2 THEN RETURN jsonb_build_object('status','storage_slots_reserved','slotsReserved',2,'replayed',true,'flightScheduled',false);END IF;
 IF n<>0 THEN RAISE EXCEPTION 'STORAGE_PARTIAL_SLOT_RESERVATION';END IF;
 -- All shared commercial rows first, in stable order, then dedicated rows.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=1 AND airport_key IN(r.origin_airport_key,r.destination_airport_key) ORDER BY airport_key FOR UPDATE;
 PERFORM 1 FROM airlinerra_game.aircraft_storage_only_movement_limits_v1 WHERE world_id=1 AND airport_key=r.destination_airport_key FOR UPDATE;
 BEGIN
 FOR endpoint IN SELECT * FROM (VALUES (r.origin_airport_key,'departure',r.departure_utc),(r.destination_airport_key,'arrival',r.arrival_utc)) e(airport_key,direction,movement_utc) ORDER BY airport_key LOOP
  tz:=NULL; h:=NULL; m:=NULL;
  IF endpoint.direction='arrival' AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=endpoint.airport_key AND admission_scope='relocation_only') THEN
   SELECT p.timezone_iana,l.movements_per_direction_hour,l.movements_per_direction_10m INTO tz,h,m
   FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 p
   JOIN airlinerra_game.aircraft_storage_only_movement_limits_v1 l USING(world_id,airport_key)
   WHERE p.world_id=1 AND p.airport_key=endpoint.airport_key;
   -- Do not create commercial slot capacity or grant commercial access.
  ELSE
   SELECT p.timezone_iana,c.remote_stands,c.remote_per_direction_10m INTO tz,h,m
   FROM airlinerra_game.section6_airport_slot_capacity_v1 c JOIN airlinerra_game.section5_airport_operating_policy_v1 p USING(world_id,airport_key)
   JOIN airlinerra_game.airport_unified_operations_v1 u USING(world_id,airport_key)
   WHERE c.world_id=1 AND c.airport_key=endpoint.airport_key AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission;
  END IF;
  IF tz IS NULL OR h IS NULL OR m IS NULL OR h<=0 OR m<=0 OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=tz)
  THEN RAISE EXCEPTION 'STORAGE_MOVEMENT_PROFILE_UNAVAILABLE';END IF;
  local_ts:=endpoint.movement_utc AT TIME ZONE tz;day_key:=local_ts::date;
  dow:=extract(isodow FROM local_ts)::int-1;minute_key:=extract(hour FROM local_ts)::int*60+(extract(minute FROM local_ts)::int/10)*10;
  PERFORM airlinerra_game.assert_storage_remote_slot_v1(endpoint.airport_key,day_key,dow,minute_key,endpoint.direction,h,m,1);
  INSERT INTO airlinerra_game.aircraft_storage_flight_slots_v1 VALUES(r.id,1,endpoint.airport_key,endpoint.direction,endpoint.movement_utc,day_key,dow,minute_key);
 END LOOP;
 EXCEPTION WHEN raise_exception THEN
 IF SQLERRM IN ('STORAGE_FLIGHT_SLOT_UNAVAILABLE','STORAGE_MOVEMENT_PROFILE_UNAVAILABLE') THEN RETURN jsonb_build_object('status',SQLERRM,'slotsReserved',0,'flightScheduled',false);END IF;RAISE;
 END;
 RETURN jsonb_build_object('status','storage_slots_reserved','slotsReserved',2,'replayed',false,'flightScheduled',false,'dispatchAuthorized',false,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.reserve_aircraft_storage_slots_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

-- Backstop existing commercial, maintenance and replacement inserts.
-- Uses the same capacity row lock; transactions which conflict abort.
CREATE FUNCTION airlinerra_game.guard_existing_slots_against_storage_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE cap record; d date; instant timestamptz;
BEGIN
 IF NEW.stand_type<>'remote' THEN RETURN NEW;END IF;
 SELECT * INTO cap FROM airlinerra_game.section6_airport_slot_capacity_v1
 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key FOR UPDATE;
 IF NOT FOUND THEN
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key)
 THEN RAISE EXCEPTION 'STORAGE_ONLY_COMMERCIAL_SLOT_BLOCKED';END IF;
 RETURN NEW;END IF;
 instant:=coalesce(airlinerra_game.section9_verified_world_instant_v1(),'-infinity'::timestamptz);
 FOR d IN SELECT DISTINCT local_date FROM airlinerra_game.aircraft_storage_flight_slots_v1
 WHERE world_id=NEW.world_id AND airport_key=NEW.airport_key AND direction=NEW.direction AND weekday=NEW.weekday
 AND minute_of_day/60=NEW.minute_of_day/60 AND movement_utc>=instant LOOP
 IF TG_TABLE_NAME<>'section6_weekly_airport_slot_reservations_v1' THEN
 IF d<>NEW.local_date THEN CONTINUE;END IF;END IF;
 PERFORM airlinerra_game.assert_storage_remote_slot_v1(NEW.airport_key,d,NEW.weekday,NEW.minute_of_day,NEW.direction,cap.remote_stands,cap.remote_per_direction_10m,0);
 END LOOP;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_existing_slots_against_storage_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER storage_weekly_slot_backstop AFTER INSERT ON airlinerra_game.section6_weekly_airport_slot_reservations_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_existing_slots_against_storage_v1();
CREATE TRIGGER storage_maintenance_slot_backstop AFTER INSERT ON airlinerra_game.section6_dated_relocation_slots_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_existing_slots_against_storage_v1();
CREATE TRIGGER storage_replacement_slot_backstop AFTER INSERT ON airlinerra_game.section9_dated_replacement_slots_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_existing_slots_against_storage_v1();
CREATE FUNCTION airlinerra_game.release_cancelled_storage_slots_v1() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status='cancelled' THEN
 DELETE FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=NEW.id;
 END IF;RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.release_cancelled_storage_slots_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER release_cancelled_storage_slots AFTER UPDATE OF status ON airlinerra_game.aircraft_storage_relocation_requests_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.release_cancelled_storage_slots_v1();
COMMIT;
