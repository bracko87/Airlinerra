-- Protected persistent schedule-draft foundation for Airlinerra World 1.
-- This DOES NOT activate flight operations or substitute crew/slots/rights checks.
CREATE TABLE IF NOT EXISTS airlinerra_game.airline_flight_schedule_drafts_v1 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE CASCADE,
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 flight_number text NOT NULL CHECK(flight_number ~ '^[A-Z0-9]{2}[0-9]{1,4}$'),
 origin_airport_key text NOT NULL,
 destination_airport_key text NOT NULL,
 reference_departure_utc timestamptz NOT NULL,
 reference_arrival_utc timestamptz NOT NULL,
 weekly_schedule jsonb NOT NULL CHECK(jsonb_typeof(weekly_schedule)='array'),
 restriction_snapshot jsonb NOT NULL,
 status text NOT NULL DEFAULT 'draft' CHECK(status='draft'),
 operationally_verified boolean NOT NULL DEFAULT false CHECK(operationally_verified=false),
 version integer NOT NULL DEFAULT 1 CHECK(version>=1),
 created_by_player_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT airline_flight_schedule_origin_fkey FOREIGN KEY (world_id,origin_airport_key)
  REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key),
 CONSTRAINT airline_flight_schedule_destination_fkey FOREIGN KEY (world_id,destination_airport_key)
  REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key),
 CONSTRAINT airline_flight_schedule_distinct_airports CHECK(origin_airport_key<>destination_airport_key),
 CONSTRAINT airline_flight_schedule_valid_duration CHECK(reference_arrival_utc>reference_departure_utc AND
  reference_arrival_utc<=reference_departure_utc+interval '72 hours'),
 CONSTRAINT airline_flight_schedule_unique_number UNIQUE(airline_id,flight_number)
);
CREATE INDEX IF NOT EXISTS airline_flight_drafts_by_aircraft_v1_idx
 ON airlinerra_game.airline_flight_schedule_drafts_v1(airline_id,aircraft_inventory_id);
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airline_flight_schedule_drafts_v1 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
 p_player_id uuid,p_airline_id uuid,p_aircraft_inventory_id uuid,
 p_flight_number text,p_origin_airport_key text,p_destination_airport_key text,
 p_reference_departure_utc timestamptz,p_reference_arrival_utc timestamptz,
 p_weekly_schedule jsonb,p_existing_draft_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $function$
DECLARE
 owner_row record; fleet_row record; gate jsonb;
 saved_id uuid; saved_version integer;
BEGIN
 IF p_player_id IS NULL OR p_airline_id IS NULL OR p_aircraft_inventory_id IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_AIRLINE_OR_AIRCRAFT'; END IF;
 SELECT a.id,a.world_id,a.owner_player_id,a.iata_code,w.state AS membership_state
 INTO owner_row
 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w
 ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 WHERE a.id=p_airline_id FOR SHARE OF a,w;
 IF NOT FOUND OR owner_row.owner_player_id IS DISTINCT FROM p_player_id
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='AIRLINE_NOT_OWNED_BY_VERIFIED_PLAYER'; END IF;
 IF owner_row.world_id<>1 OR owner_row.membership_state<>'active'
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRLINE_WORLD_NOT_ACTIVE_FOR_SCHEDULING'; END IF;
 IF owner_row.iata_code IS NULL OR p_flight_number IS NULL OR
    p_flight_number !~ '^[A-Z0-9]{2}[0-9]{1,4}$' OR
    left(p_flight_number,2)<>owner_row.iata_code
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_AIRLINE_FLIGHT_NUMBER'; END IF;
 SELECT i.id,i.airline_id,i.configuration_id,i.fleet_status
 INTO fleet_row FROM airlinerra_game.airline_aircraft_inventory i
 WHERE i.id=p_aircraft_inventory_id AND i.airline_id=p_airline_id
 FOR SHARE;
 IF NOT FOUND OR fleet_row.fleet_status<>'in_service'
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_NOT_OWNED_LEASED_OR_IN_SERVICE'; END IF;
 IF p_existing_draft_id IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE id=p_existing_draft_id AND airline_id=p_airline_id AND status='draft')
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SCHEDULE_DRAFT_NOT_OWNED_OR_EDITABLE'; END IF;
 gate:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  owner_row.world_id,p_origin_airport_key,p_destination_airport_key,
  fleet_row.configuration_id,p_reference_departure_utc,p_reference_arrival_utc,p_weekly_schedule);
 IF gate IS NULL OR gate->>'weeklyTimetableChecked'<>'true' OR
   (gate->>'gameHardBlocked')::boolean IS DISTINCT FROM false OR
   (gate->>'occurrenceCount')::int IS DISTINCT FROM jsonb_array_length(p_weekly_schedule)*4
 THEN RAISE EXCEPTION USING ERRCODE='P0001',
  MESSAGE='SCHEDULE_BLOCKED_BY_AIRPORT_OR_AIRCRAFT_RULE',
  DETAIL=left(coalesce(gate->>'decision','NO_VALID_RESTRICTION_RESULT'),120); END IF;
 IF p_existing_draft_id IS NULL THEN
  INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
   world_id,airline_id,aircraft_inventory_id,configuration_id,
   flight_number,origin_airport_key,destination_airport_key,
   reference_departure_utc,reference_arrival_utc,weekly_schedule,
   restriction_snapshot,created_by_player_id)
  VALUES(1,p_airline_id,p_aircraft_inventory_id,fleet_row.configuration_id,
   p_flight_number,p_origin_airport_key,p_destination_airport_key,
   p_reference_departure_utc,p_reference_arrival_utc,p_weekly_schedule,
   gate,p_player_id)
  RETURNING id,version INTO saved_id,saved_version;
 ELSE
  UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
  SET aircraft_inventory_id=p_aircraft_inventory_id,
   configuration_id=fleet_row.configuration_id,flight_number=p_flight_number,
   origin_airport_key=p_origin_airport_key,destination_airport_key=p_destination_airport_key,
   reference_departure_utc=p_reference_departure_utc,
   reference_arrival_utc=p_reference_arrival_utc,
   weekly_schedule=p_weekly_schedule,restriction_snapshot=gate,
   updated_at=now(),version=version+1
  WHERE id=p_existing_draft_id AND airline_id=p_airline_id AND status='draft'
  RETURNING id,version INTO saved_id,saved_version;
  IF saved_id IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SCHEDULE_DRAFT_NOT_EDITABLE'; END IF;
 END IF;
 RETURN jsonb_build_object('scheduleId',saved_id,'version',saved_version,
  'status','draft','operationallyVerified',false,'canActivateNormalFlight',false,
  'weeklyOccurrencesScreened',(gate->>'occurrenceCount')::int,
  'gameHardBlocked',false,'needsReview',coalesce((gate->>'needsReview')::boolean,true),
  'decision',gate->>'decision','message','Server-owned flight schedule draft saved; no flight activated.');
END;
$function$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
 uuid,uuid,uuid,text,text,text,timestamptz,timestamptz,jsonb,uuid
) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
uuid,uuid,uuid,text,text,text,timestamptz,timestamptz,jsonb,uuid) IS
'Private write transaction for genuine airline-owned in-service aircraft, with verified player ID supplied exclusively by authenticated server and mandatory four-week runway/curfew/noise check. Stores draft only, never activates.';
