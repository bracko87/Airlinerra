-- Section 6 / Airlinerra game capacity: stand-based, no real-world movements research.
-- This migration is additive; flight operations remain gated by Section 5.
CREATE TABLE IF NOT EXISTS airlinerra_game.section6_airport_slot_capacity_v1 (
 world_id smallint NOT NULL,
 airport_key text NOT NULL,
 terminal_stands integer NOT NULL CHECK (terminal_stands>=0),
 remote_stands integer NOT NULL CHECK (remote_stands>=0),
 cargo_stands integer NOT NULL CHECK (cargo_stands>=0),
 terminal_per_direction_10m integer NOT NULL CHECK (terminal_per_direction_10m>=0),
 remote_per_direction_10m integer NOT NULL CHECK (remote_per_direction_10m>=0),
 cargo_per_direction_10m integer NOT NULL CHECK (cargo_per_direction_10m>=0),
 model_version text NOT NULL DEFAULT 'stand_hourly_v1',
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(world_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key)
);
ALTER TABLE airlinerra_game.section6_airport_slot_capacity_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section6_airport_slot_capacity_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section6_airport_slot_capacity_v1 IS
 'Game-only limits; each eligible stand supplies one arrival and one departure per hour, distributed over 10-minute windows using standard half-up rounding. No physical parking/turnaround simulation.';

CREATE OR REPLACE FUNCTION airlinerra_game.section6_refresh_airport_capacity_v1(
 p_world_id smallint,p_airport_key text
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
BEGIN
 INSERT INTO airlinerra_game.section6_airport_slot_capacity_v1(
  world_id,airport_key,terminal_stands,remote_stands,cargo_stands,
  terminal_per_direction_10m,remote_per_direction_10m,cargo_per_direction_10m)
 SELECT f.world_id,f.airport_key,
  CASE WHEN f.scheduled_passenger_service AND f.contact_stand_count>0 THEN f.contact_stand_count ELSE 0 END,
  CASE WHEN f.scheduled_passenger_service AND f.remote_stand_count>0 THEN f.remote_stand_count ELSE 0 END,
  CASE WHEN f.cargo_handling_available AND f.cargo_stand_count>0 THEN f.cargo_stand_count ELSE 0 END,
  CASE WHEN f.scheduled_passenger_service AND f.contact_stand_count>0
       THEN greatest(1,floor(f.contact_stand_count::numeric/6+0.5)::integer) ELSE 0 END,
  CASE WHEN f.scheduled_passenger_service AND f.remote_stand_count>0
       THEN greatest(1,floor(f.remote_stand_count::numeric/6+0.5)::integer) ELSE 0 END,
  CASE WHEN f.cargo_handling_available AND f.cargo_stand_count>0
       THEN greatest(1,floor(f.cargo_stand_count::numeric/6+0.5)::integer) ELSE 0 END
 FROM airlinerra_game.airport_facilities f
 WHERE f.world_id=p_world_id AND f.airport_key=p_airport_key
 ON CONFLICT(world_id,airport_key) DO UPDATE SET
  terminal_stands=excluded.terminal_stands,
  remote_stands=excluded.remote_stands,
  cargo_stands=excluded.cargo_stands,
  terminal_per_direction_10m=excluded.terminal_per_direction_10m,
  remote_per_direction_10m=excluded.remote_per_direction_10m,
  cargo_per_direction_10m=excluded.cargo_per_direction_10m,
  model_version='stand_hourly_v1',updated_at=now();
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section6_refresh_airport_capacity_v1(smallint,text)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section6_refresh_facility_trigger_v1()
RETURNS trigger LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
BEGIN
 PERFORM airlinerra_game.section6_refresh_airport_capacity_v1(NEW.world_id,NEW.airport_key);
 RETURN NEW;
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section6_refresh_facility_trigger_v1()
 FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS section6_capacity_on_facility_change_v1 ON airlinerra_game.airport_facilities;
CREATE TRIGGER section6_capacity_on_facility_change_v1
AFTER INSERT OR UPDATE OF contact_stand_count,remote_stand_count,cargo_stand_count,
 scheduled_passenger_service,cargo_handling_available
ON airlinerra_game.airport_facilities
FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section6_refresh_facility_trigger_v1();

SELECT airlinerra_game.section6_refresh_airport_capacity_v1(f.world_id,f.airport_key)
 FROM airlinerra_game.airport_facilities f;
