-- Section 9: private physical aircraft movement/event ledger.
-- Flight plans and forecast results are NOT operated-flight events.
-- Every real movement requires separately authenticated game-engine evidence
-- AND a previously activated, operationally-verified flight schedule.
-- Existing draft-only production flight restrictions remain in force.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_operated_flight_movements_v1(
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 engine_event_id text PRIMARY KEY
  CHECK(length(engine_event_id) BETWEEN 12 AND 128
   AND engine_event_id~'^[A-Za-z0-9._:-]+$'),
 event_hmac_sha256 text NOT NULL
  CHECK(event_hmac_sha256~'^[a-f0-9]{64}$'),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES
   airlinerra_game.airline_aircraft_inventory(id),
 schedule_id uuid NOT NULL REFERENCES
   airlinerra_game.airline_flight_schedule_drafts_v1(id),
 schedule_version int NOT NULL CHECK(schedule_version>=1),
 weekly_entry int NOT NULL CHECK(weekly_entry BETWEEN 1 AND 7),
 flight_local_date date NOT NULL CHECK(flight_local_date BETWEEN
   DATE '2000-01-01' AND DATE '2199-12-31'),
 flight_occurrence_id text NOT NULL,
 phase text NOT NULL CHECK(phase IN ('departed','arrived')),
 origin_airport_key text NOT NULL,
 destination_airport_key text NOT NULL,
 scheduled_departure_utc timestamptz NOT NULL,
 scheduled_arrival_utc timestamptz NOT NULL,
 actual_event_utc timestamptz NOT NULL,
 source_kind text NOT NULL DEFAULT 'signed_operated_game_flight_v1'
  CHECK(source_kind='signed_operated_game_flight_v1'),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(flight_occurrence_id,phase),
 CHECK(origin_airport_key<>destination_airport_key),
 CHECK(scheduled_arrival_utc>scheduled_departure_utc),
 FOREIGN KEY(world_id,origin_airport_key) REFERENCES
  airlinerra_game.approved_game_airports(world_id,airport_key),
 FOREIGN KEY(world_id,destination_airport_key) REFERENCES
  airlinerra_game.approved_game_airports(world_id,airport_key),
 CHECK(flight_occurrence_id=schedule_id::text||':'||
  flight_local_date::text||':'||weekly_entry::text)
);
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_operated_flight_movements_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_movements_aircraft_order_idx
 ON airlinerra_game.section9_operated_flight_movements_v1(
  aircraft_inventory_id,actual_event_utc,engine_event_id);
CREATE INDEX IF NOT EXISTS section9_movements_origin_fk_idx
 ON airlinerra_game.section9_operated_flight_movements_v1(
  world_id,origin_airport_key);
CREATE INDEX IF NOT EXISTS section9_movements_destination_fk_idx
 ON airlinerra_game.section9_operated_flight_movements_v1(
  world_id,destination_airport_key);
CREATE INDEX IF NOT EXISTS section9_movements_schedule_fk_idx
 ON airlinerra_game.section9_operated_flight_movements_v1(schedule_id);
CREATE INDEX IF NOT EXISTS section9_movements_airline_fk_idx
 ON airlinerra_game.section9_operated_flight_movements_v1(airline_id);

-- Mutable projection of the append-only, signed flight movement history.
-- All location updates happen atomically with an inserted movement event.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aircraft_current_position_v1(
 aircraft_inventory_id uuid PRIMARY KEY REFERENCES
  airlinerra_game.airline_aircraft_inventory(id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 location_status text NOT NULL CHECK(location_status IN ('grounded','in_flight')),
 airport_key text,
 current_flight_occurrence_id text,
 last_event_utc timestamptz NOT NULL,
 last_departure_utc timestamptz,
 last_arrival_utc timestamptz,
 last_engine_event_id text NOT NULL REFERENCES
  airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(
 (location_status='grounded' AND airport_key IS NOT NULL
    AND current_flight_occurrence_id IS NULL)
 OR
 (location_status='in_flight' AND airport_key IS NULL
    AND current_flight_occurrence_id IS NOT NULL)),
 FOREIGN KEY(world_id,airport_key) REFERENCES
  airlinerra_game.approved_game_airports(world_id,airport_key)
);
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aircraft_current_position_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_current_aircraft_airline_idx
 ON airlinerra_game.section9_aircraft_current_position_v1(airline_id);
CREATE INDEX IF NOT EXISTS section9_current_position_airport_fk_idx
 ON airlinerra_game.section9_aircraft_current_position_v1(world_id,airport_key);
CREATE INDEX IF NOT EXISTS section9_current_position_event_fk_idx
 ON airlinerra_game.section9_aircraft_current_position_v1(last_engine_event_id);

CREATE OR REPLACE FUNCTION airlinerra_game.section9_immutable_movement_event_v1()
 RETURNS trigger LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
BEGIN
 RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_MOVEMENT_EVENT_IMMUTABLE';
END $f$;
DROP TRIGGER IF EXISTS section9_operated_movement_immutable
 ON airlinerra_game.section9_operated_flight_movements_v1;
CREATE TRIGGER section9_operated_movement_immutable
 BEFORE UPDATE OR DELETE ON airlinerra_game.section9_operated_flight_movements_v1
 FOR EACH ROW EXECUTE FUNCTION
  airlinerra_game.section9_immutable_movement_event_v1();
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_immutable_movement_event_v1()
 FROM PUBLIC,anon,authenticated;

-- Pure deterministic state transition used by the actual write function.
-- May be tested against synthetic states WITHOUT bypassing real schedule
-- status constraints, flight activation, or the game clock.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aircraft_movement_decision_v1(
 p_phase text,p_state text,p_current_airport text,
 p_current_occurrence text,p_last_event_utc timestamptz,
 p_last_departure_utc timestamptz,p_origin text,p_destination text,
 p_occurrence text,p_event_utc timestamptz
) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE reason text;
BEGIN
 IF p_phase NOT IN ('departed','arrived') OR
  p_state NOT IN ('grounded','in_flight') OR
  p_origin IS NULL OR p_destination IS NULL OR
  p_origin=p_destination OR p_occurrence IS NULL OR
  p_event_utc IS NULL OR
  p_event_utc::date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_MOVEMENT_TRANSITION';END IF;
 reason:=CASE
  WHEN p_last_event_utc IS NOT NULL AND p_event_utc<=p_last_event_utc
   THEN 'NON_MONOTONIC_AIRCRAFT_EVENT'
  WHEN p_phase='departed' AND p_state='in_flight'
   THEN 'AIRCRAFT_ALREADY_IN_FLIGHT'
  WHEN p_phase='departed' AND p_state='grounded'
   AND p_current_airport IS DISTINCT FROM p_origin
   THEN 'AIRCRAFT_AT_WRONG_AIRPORT'
  WHEN p_phase='arrived' AND p_state<>'in_flight'
   THEN 'AIRCRAFT_HAS_NO_DEPARTURE'
  WHEN p_phase='arrived' AND
   p_current_occurrence IS DISTINCT FROM p_occurrence
   THEN 'ARRIVAL_NOT_FOR_CURRENT_FLIGHT'
  WHEN p_phase='arrived' AND
   (p_last_departure_utc IS NULL OR
    p_event_utc<=p_last_departure_utc)
   THEN 'ARRIVAL_NOT_AFTER_DEPARTURE'
  ELSE NULL END;
 IF reason IS NOT NULL THEN
  RETURN jsonb_build_object('allowed',false,'reason',reason,
   'newState',NULL,'newAirport',NULL);
 END IF;
 RETURN jsonb_build_object('allowed',true,'reason','ok',
  'newState',CASE WHEN p_phase='departed' THEN 'in_flight'
                 ELSE 'grounded' END,
  'newAirport',CASE WHEN p_phase='departed' THEN NULL
                   ELSE p_destination END);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_aircraft_movement_decision_v1(
 text,text,text,text,timestamptz,timestamptz,text,text,text,timestamptz)
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_operated_flight_movements_v1 IS
 'Append-only private flight movement evidence. Never accepts draft schedules, a mere demand forecast, or a browser-provided unsigned event.';
COMMENT ON TABLE airlinerra_game.section9_aircraft_current_position_v1 IS
 'Atomic projection of signed operated-flight movement events; grounded airport may only follow verified arrival, and in_flight has no airport. Original delivery anchor is separate.';
