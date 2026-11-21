-- Persist dated replacement slot pairs while the signed dispatcher remains gated.
ALTER TABLE airlinerra_game.section9_disruption_release_v1
 ADD COLUMN IF NOT EXISTS replacement_reservation_enabled boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_replacement_slot_pairs_v1(
 occurrence_id uuid PRIMARY KEY REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id) ON DELETE CASCADE,
 world_id smallint NOT NULL CHECK(world_id=1),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 original_departure_utc timestamptz NOT NULL,
 original_arrival_utc timestamptz NOT NULL,
 revised_departure_utc timestamptz NOT NULL,
 revised_arrival_utc timestamptz NOT NULL,
 available_utc timestamptz NOT NULL,
 reserved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(revised_departure_utc>original_departure_utc AND revised_arrival_utc>revised_departure_utc
 AND revised_arrival_utc-revised_departure_utc=original_arrival_utc-original_departure_utc
 AND available_utc>=revised_arrival_utc)
);
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_dated_replacement_slots_v1(
 occurrence_id uuid NOT NULL REFERENCES airlinerra_game.section9_replacement_slot_pairs_v1(occurrence_id) ON DELETE CASCADE,
 world_id smallint NOT NULL CHECK(world_id=1),airport_key text NOT NULL,
 stand_type text NOT NULL CHECK(stand_type IN('terminal','remote','cargo')),
 direction text NOT NULL CHECK(direction IN('departure','arrival')),
 movement_utc timestamptz NOT NULL, local_date date NOT NULL,
 weekday smallint NOT NULL CHECK(weekday=extract(isodow FROM local_date)::int-1),
 minute_of_day smallint NOT NULL CHECK(minute_of_day BETWEEN 0 AND 1430 AND minute_of_day%10=0),
 PRIMARY KEY(occurrence_id,direction),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.section6_airport_slot_capacity_v1(world_id,airport_key)
);
CREATE INDEX IF NOT EXISTS section9_replacement_slots_capacity_idx ON airlinerra_game.section9_dated_replacement_slots_v1(world_id,airport_key,stand_type,direction,local_date,minute_of_day);
CREATE INDEX IF NOT EXISTS section9_replacement_pairs_aircraft_idx ON airlinerra_game.section9_replacement_slot_pairs_v1(aircraft_inventory_id,revised_departure_utc,available_utc);
ALTER TABLE airlinerra_game.section9_replacement_slot_pairs_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_dated_replacement_slots_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_replacement_slot_pairs_v1,airlinerra_game.section9_dated_replacement_slots_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_dated_replacement_slot_check_v1(
 p_world smallint,p_airport text,p_stand text,p_direction text,p_time timestamptz
) RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO pg_catalog,airlinerra_game AS $$
WITH c AS (
 SELECT a.*,p_time AT TIME ZONE p.timezone_iana AS local_dt,
 CASE p_stand WHEN 'terminal' THEN a.terminal_stands WHEN 'remote' THEN a.remote_stands WHEN 'cargo' THEN a.cargo_stands END AS hour_limit,
 CASE p_stand WHEN 'terminal' THEN a.terminal_per_direction_10m WHEN 'remote' THEN a.remote_per_direction_10m WHEN 'cargo' THEN a.cargo_per_direction_10m END AS window_limit
 FROM airlinerra_game.section6_airport_slot_capacity_v1 a
 JOIN airlinerra_game.section5_airport_operating_policy_v1 p USING(world_id,airport_key)
 WHERE a.world_id=p_world AND a.airport_key=p_airport AND p_direction IN('departure','arrival')
), b AS (
 SELECT c.*,extract(isodow FROM local_dt)::int-1 AS dow,
 extract(hour FROM local_dt)::int*60+(extract(minute FROM local_dt)::int/10)*10 AS minute_bucket FROM c
 WHERE local_dt IS NOT NULL
), usage AS (
 SELECT b.*,w.h+r.h AS used_hour,w.m+r.m AS used_window
 FROM b
 CROSS JOIN LATERAL (
 SELECT count(*) FILTER(WHERE s.minute_of_day/60=b.minute_bucket/60) h,
 count(*) FILTER(WHERE s.minute_of_day=b.minute_bucket) m
 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 s
 WHERE s.world_id=p_world AND s.airport_key=p_airport AND s.stand_type=p_stand AND s.direction=p_direction AND s.weekday=b.dow
 ) w
 CROSS JOIN LATERAL (
 SELECT count(*) FILTER(WHERE s.minute_of_day/60=b.minute_bucket/60) h,
 count(*) FILTER(WHERE s.minute_of_day=b.minute_bucket) m
 FROM (
 SELECT world_id,airport_key,stand_type,direction,local_date,minute_of_day FROM airlinerra_game.section6_dated_relocation_slots_v1
 UNION ALL
 SELECT world_id,airport_key,stand_type,direction,local_date,minute_of_day FROM airlinerra_game.section9_dated_replacement_slots_v1
 ) s WHERE s.world_id=p_world AND s.airport_key=p_airport AND s.stand_type=p_stand AND s.direction=p_direction AND s.local_date=b.local_dt::date
 ) r
)
SELECT coalesce((SELECT hour_limit>used_hour AND window_limit>used_window FROM usage),false);
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_dated_replacement_slot_check_v1(smallint,text,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

-- Shared-capacity backstop for new ordinary reservations; no effect on capacity
-- decisions when no replacement slots exist. Existing weekly slots are retained
-- conservatively until the dated release/accounting integration is implemented.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_replacement_capacity_backstop_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE cap record; day_key date; w_h int;w_m int; d_h int;d_m int; h_lim int;m_lim int;
BEGIN
 SELECT * INTO cap FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=NEW.world_id AND c.airport_key=NEW.airport_key FOR UPDATE;
 IF NOT FOUND THEN RETURN NEW; END IF;
 h_lim:=CASE NEW.stand_type WHEN 'terminal' THEN cap.terminal_stands WHEN 'remote' THEN cap.remote_stands ELSE cap.cargo_stands END;
 m_lim:=CASE NEW.stand_type WHEN 'terminal' THEN cap.terminal_per_direction_10m WHEN 'remote' THEN cap.remote_per_direction_10m ELSE cap.cargo_per_direction_10m END;
 FOR day_key IN SELECT DISTINCT s.local_date FROM airlinerra_game.section9_dated_replacement_slots_v1 s
 WHERE s.world_id=NEW.world_id AND s.airport_key=NEW.airport_key AND s.stand_type=NEW.stand_type AND s.direction=NEW.direction
 AND s.weekday=NEW.weekday AND s.minute_of_day/60=NEW.minute_of_day/60
 AND s.movement_utc>=coalesce(airlinerra_game.section9_verified_world_instant_v1(),'-infinity'::timestamptz)
 LOOP
  IF TG_TABLE_NAME='section6_dated_relocation_slots_v1' THEN
    IF day_key<>NEW.local_date THEN CONTINUE; END IF;
  END IF;
  SELECT count(*) FILTER(WHERE s.minute_of_day/60=NEW.minute_of_day/60),count(*) FILTER(WHERE s.minute_of_day=NEW.minute_of_day)
  INTO w_h,w_m FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 s
  WHERE s.world_id=NEW.world_id AND s.airport_key=NEW.airport_key AND s.stand_type=NEW.stand_type AND s.direction=NEW.direction AND s.weekday=NEW.weekday;
  SELECT count(*) FILTER(WHERE s.minute_of_day/60=NEW.minute_of_day/60),count(*) FILTER(WHERE s.minute_of_day=NEW.minute_of_day)
  INTO d_h,d_m FROM (
   SELECT world_id,airport_key,stand_type,direction,local_date,minute_of_day FROM airlinerra_game.section6_dated_relocation_slots_v1
   UNION ALL SELECT world_id,airport_key,stand_type,direction,local_date,minute_of_day FROM airlinerra_game.section9_dated_replacement_slots_v1
  ) s WHERE s.world_id=NEW.world_id AND s.airport_key=NEW.airport_key AND s.stand_type=NEW.stand_type AND s.direction=NEW.direction AND s.local_date=day_key;
  IF w_h+d_h>h_lim OR w_m+d_m>m_lim THEN RAISE EXCEPTION 'SECTION9_CONFLICT_WITH_DATED_REPLACEMENT_SLOT';END IF;
 END LOOP;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_replacement_capacity_backstop_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER section9_weekly_replacement_backstop AFTER INSERT ON airlinerra_game.section6_weekly_airport_slot_reservations_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_replacement_capacity_backstop_v1();
CREATE TRIGGER section9_relocation_replacement_backstop AFTER INSERT ON airlinerra_game.section6_dated_relocation_slots_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_replacement_capacity_backstop_v1();

CREATE OR REPLACE FUNCTION airlinerra_game.section9_reserve_replacement_slot_pair_v1(p_occurrence uuid,p_max_delay_minutes integer DEFAULT 240)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE o record; existing record; planned jsonb; d timestamptz; a timestamptz; ready timestamptz; now_utc timestamptz; physical text; n integer; technical integer;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_REPLACEMENT_RESERVATION';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_disruption_release_v1 WHERE world_id=1 AND replacement_reservation_enabled) THEN
  RETURN jsonb_build_object('status','replacement_reservation_not_released','reserved',false);
 END IF;
 SELECT x.*,s.configuration_id,s.departure_stand_type,s.arrival_stand_type
 INTO o FROM airlinerra_game.section9_dated_flight_occurrences_v1 x
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=x.schedule_id AND s.airline_id=x.airline_id AND s.aircraft_inventory_id=x.aircraft_inventory_id AND s.version=x.schedule_version
 WHERE x.id=p_occurrence AND x.world_id=1 AND x.booking_status='open' AND x.source_kind='game_verified_saleable_schedule_v1' AND s.status='active' AND s.operationally_verified
 FOR UPDATE OF x;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','replacement_occurrence_unavailable','reserved',false);END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=o.aircraft_inventory_id FOR UPDATE;
 physical:=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=physical)
 THEN RETURN jsonb_build_object('status','flight_already_operated','reserved',false);END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_replacement_slot_pairs_v1 WHERE occurrence_id=p_occurrence;
 IF FOUND THEN RETURN jsonb_build_object('status','replacement_pair_already_reserved','reserved',true,'replayed',true,'departureUtc',existing.revised_departure_utc,'arrivalUtc',existing.revised_arrival_utc,'availableUtc',existing.available_utc);END IF;
 SELECT technical_delay_minutes INTO technical FROM airlinerra_game.section9_flight_disruption_decisions_v1 WHERE occurrence_id=p_occurrence AND physical_flight_id=physical;
 IF technical IS NULL OR technical<=0 THEN RETURN jsonb_build_object('status','positive_technical_delay_required','reserved',false);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR now_utc<o.departure_utc-interval '10 minutes' OR now_utc>o.departure_utc+make_interval(mins=>p_max_delay_minutes)
 THEN RETURN jsonb_build_object('status','replacement_outside_window','reserved',false);END IF;
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c WHERE c.world_id=o.world_id
 AND c.airport_key IN(o.origin_airport_key,o.destination_airport_key) ORDER BY c.airport_key FOR UPDATE;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>2 THEN RETURN jsonb_build_object('status','replacement_airport_capacity_missing','reserved',false);END IF;
 planned:=airlinerra_game.section9_preview_replacement_slot_pair_v1(o.world_id,o.origin_airport_key,o.destination_airport_key,o.configuration_id,o.departure_stand_type,o.arrival_stand_type,o.departure_utc,o.arrival_utc,greatest(now_utc,o.departure_utc+make_interval(mins=>technical)),o.turnaround_minutes,p_max_delay_minutes);
 IF planned->>'status'<>'replacement_slot_pair_preview' THEN RETURN planned||jsonb_build_object('reserved',false);END IF;
 d:=(planned->>'departureUtc')::timestamptz;a:=(planned->>'arrivalUtc')::timestamptz;ready:=(planned->>'availableUtc')::timestamptz;
 -- Do not allow a reservation to overlap another dated aircraft assignment.
 -- Consequentially delayed legs require the later atomic rotation integration.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 x LEFT JOIN airlinerra_game.section9_replacement_slot_pairs_v1 p ON p.occurrence_id=x.id
 WHERE x.aircraft_inventory_id=o.aircraft_inventory_id AND x.id<>o.id AND x.booking_status IN('open','closed')
 AND tstzrange(coalesce(p.revised_departure_utc,x.departure_utc),coalesce(p.available_utc,x.arrival_utc+make_interval(mins=>x.turnaround_minutes)),'[)') && tstzrange(d,ready,'[)'))
 THEN RETURN jsonb_build_object('status','replacement_requires_rotation_replan','reserved',false);END IF;
 INSERT INTO airlinerra_game.section9_replacement_slot_pairs_v1(occurrence_id,world_id,aircraft_inventory_id,original_departure_utc,original_arrival_utc,revised_departure_utc,revised_arrival_utc,available_utc)
 VALUES(o.id,o.world_id,o.aircraft_inventory_id,o.departure_utc,o.arrival_utc,d,a,ready);
 INSERT INTO airlinerra_game.section9_dated_replacement_slots_v1(occurrence_id,world_id,airport_key,stand_type,direction,movement_utc,local_date,weekday,minute_of_day)
 SELECT o.id,o.world_id,m.airport_key,m.stand_type,m.direction,m.movement_utc,z.local_dt::date,(extract(isodow FROM z.local_dt)::int-1)::smallint,(extract(hour FROM z.local_dt)::int*60+(extract(minute FROM z.local_dt)::int/10)*10)::smallint
 FROM (VALUES(o.origin_airport_key,o.departure_stand_type,'departure',d),(o.destination_airport_key,o.arrival_stand_type,'arrival',a)) m(airport_key,stand_type,direction,movement_utc)
 JOIN airlinerra_game.section5_airport_operating_policy_v1 pol ON pol.world_id=o.world_id AND pol.airport_key=m.airport_key
 CROSS JOIN LATERAL(SELECT m.movement_utc AT TIME ZONE pol.timezone_iana AS local_dt) z;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>2 THEN RAISE EXCEPTION 'REPLACEMENT_PAIR_NOT_ATOMIC';END IF;
 RETURN planned||jsonb_build_object('status','replacement_pair_reserved','reserved',true,'replayed',false,'readOnly',false,'slotsReserved',true);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_reserve_replacement_slot_pair_v1(uuid,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_release_cancelled_replacement_pair_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
BEGIN
 IF NEW.booking_status='cancelled' AND OLD.booking_status IS DISTINCT FROM NEW.booking_status THEN
 DELETE FROM airlinerra_game.section9_replacement_slot_pairs_v1 WHERE occurrence_id=NEW.id;
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_release_cancelled_replacement_pair_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER section9_release_cancelled_replacement_pair AFTER UPDATE OF booking_status ON airlinerra_game.section9_dated_flight_occurrences_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_release_cancelled_replacement_pair_v1();
