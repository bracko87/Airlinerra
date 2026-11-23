-- Exact current deployed Group 1 schedule-save function plus narrow fail-closed Group 2 preflight.
-- Group 1 transaction/slot logic kept unchanged.
CREATE OR REPLACE FUNCTION airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(p_player_id uuid, p_airline_id uuid, p_aircraft_inventory_id uuid, p_flight_number text, p_origin_key text, p_destination_key text, p_reference_departure_utc timestamp with time zone, p_reference_arrival_utc timestamp with time zone, p_weekly_schedule jsonb, p_existing_draft_id uuid DEFAULT NULL::uuid, p_departure_stand text DEFAULT 'terminal'::text, p_arrival_stand text DEFAULT 'terminal'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE previous_origin text; previous_destination text; model_use_type text;
 existing_count integer; result jsonb; slot_preview jsonb; saved_schedule_id uuid;
 group2_preview jsonb;
BEGIN
 IF p_departure_stand IS NULL OR p_arrival_stand IS NULL OR
  p_departure_stand NOT IN ('terminal','remote','cargo') OR
  p_arrival_stand NOT IN ('terminal','remote','cargo')
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION6_INVALID_STAND_CHOICE'; END IF;
 SELECT c.use_type INTO model_use_type FROM airlinerra_game.airline_aircraft_inventory i
 JOIN airlinerra.aircraft_configurations c ON c.id=i.configuration_id
 WHERE i.id=p_aircraft_inventory_id AND i.airline_id=p_airline_id;
 IF model_use_type='cargo' AND (p_departure_stand<>'cargo' OR p_arrival_stand<>'cargo') OR
    model_use_type='passenger' AND (p_departure_stand='cargo' OR p_arrival_stand='cargo')
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='SECTION6_INCOMPATIBLE_AIRCRAFT_STAND'; END IF;
 -- Group 2 airports are prepared, not admitted to active scheduling. Run
 -- authenticated-owner aircraft preflight only to return a useful blocker.
 -- This branch executes before any schedule draft or slot mutation.
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 g
  WHERE g.airport_key IN(p_origin_key,p_destination_key)
 ) THEN
  group2_preview:=airlinerra_game.group2_owned_aircraft_route_preflight_v1(
   p_player_id,p_airline_id,p_aircraft_inventory_id,
   p_origin_key,p_destination_key,p_reference_departure_utc,
   p_reference_arrival_utc,p_weekly_schedule,p_departure_stand,p_arrival_stand);
  RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='SECTION6_GROUP2_NOT_YET_ADMITTED',
   DETAIL=left(coalesce(group2_preview->>'routeSafetyDecision',
    group2_preview->>'decision','GROUP2_OWNER_PREFLIGHT_UNAVAILABLE'),120);
 END IF;
 IF p_existing_draft_id IS NOT NULL THEN
  SELECT origin_airport_key,destination_airport_key INTO previous_origin,previous_destination
  FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE id=p_existing_draft_id AND airline_id=p_airline_id;
 END IF;
 -- Lock ALL old and new airports in deterministic order before any slot mutation.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN
  (p_origin_key,p_destination_key,previous_origin,previous_destination)
 ORDER BY c.airport_key FOR UPDATE;
 SELECT count(*) INTO existing_count FROM airlinerra_game.section6_airport_slot_capacity_v1
 WHERE world_id=1 AND airport_key IN (p_origin_key,p_destination_key);
 IF existing_count<>2 THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='SECTION6_AIRPORT_CAPACITY_NOT_CONFIGURED'; END IF;
 result:=airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
  p_player_id,p_airline_id,p_aircraft_inventory_id,p_flight_number,
  p_origin_key,p_destination_key,p_reference_departure_utc,p_reference_arrival_utc,
  p_weekly_schedule,p_existing_draft_id);
 saved_schedule_id:=(result->>'scheduleId')::uuid;
 -- Replacing the old reservation and the new one is atomic.
 DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
 WHERE schedule_id=saved_schedule_id;
 slot_preview:=airlinerra_game.section6_weekly_slot_preflight_v1(
  1::smallint,p_origin_key,p_destination_key,p_reference_departure_utc,p_reference_arrival_utc,
  p_weekly_schedule,p_departure_stand,p_arrival_stand,NULL);
 IF (slot_preview->>'available')::boolean IS DISTINCT FROM true THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='SECTION6_SLOT_UNAVAILABLE'; END IF;
 INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1(
  schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT saved_schedule_id,1,p.airport_key,p.stand_type,p.direction,p.weekday,p.minute_of_day
 FROM airlinerra_game.section6_weekly_slot_proposals_v1(
  1::smallint,p_origin_key,p_destination_key,p_reference_departure_utc,p_reference_arrival_utc,
  p_weekly_schedule,p_departure_stand,p_arrival_stand) p;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1 SET
  departure_stand_type=p_departure_stand,arrival_stand_type=p_arrival_stand
 WHERE id=saved_schedule_id;
 RETURN result||jsonb_build_object('slotsReserved',true,'slotModel','weekly_stand_capacity_v1',
  'message','Weekly airport slots reserved for this draft; operational flight activation remains blocked.');
END $function$;

