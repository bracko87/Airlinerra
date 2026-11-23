-- Read-only Group 2 scheduling preflight with trusted PLAYER + airline + inventory ownership.
-- Intentional stop at admission boundary: never issues draft/slot/movement writes.
CREATE OR REPLACE FUNCTION airlinerra_game.group2_owned_aircraft_route_preflight_v1(
 p_player_id uuid,p_airline_id uuid,p_aircraft_inventory_id uuid,
 p_origin_key text,p_destination_key text,
 p_reference_departure_utc timestamptz,p_reference_arrival_utc timestamptz,
 p_weekly_schedule jsonb,p_departure_stand text,p_arrival_stand text
) RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $$
DECLARE ac record; preview jsonb; group2_count int;
BEGIN
 IF p_player_id IS NULL OR p_airline_id IS NULL OR p_aircraft_inventory_id IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_MISSING_VERIFIED_OWNER',
 'canSaveSchedule',false,'canReserve',false,'canActivateFlights',false);END IF;
 SELECT a.id,a.world_id,a.owner_player_id,i.configuration_id,i.fleet_status,c.use_type
 INTO ac FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships m
  ON m.player_id=a.owner_player_id AND m.world_id=a.world_id
 JOIN airlinerra_game.airline_aircraft_inventory i
  ON i.airline_id=a.id AND i.id=p_aircraft_inventory_id
 JOIN airlinerra.aircraft_configurations c ON c.id=i.configuration_id
 WHERE a.world_id=1 AND a.id=p_airline_id AND a.owner_player_id=p_player_id
 AND m.state='active';
 IF ac.id IS NULL THEN RETURN jsonb_build_object(
  'decision','BLOCKED_NOT_OWNED_ACTIVE_AIRLINE_OR_AIRCRAFT',
  'canSaveSchedule',false,'canReserve',false,'canActivateFlights',false);END IF;
 IF ac.fleet_status<>'in_service' THEN RETURN jsonb_build_object(
  'decision','BLOCKED_AIRCRAFT_NOT_IN_SERVICE','canSaveSchedule',false,
  'canReserve',false,'canActivateFlights',false);END IF;
 IF (ac.use_type='passenger' AND (p_departure_stand='cargo' OR p_arrival_stand='cargo'))
 OR (ac.use_type='cargo' AND (p_departure_stand<>'cargo' OR p_arrival_stand<>'cargo'))
 THEN RETURN jsonb_build_object('decision','BLOCKED_INCOMPATIBLE_STAND_TYPE',
 'canSaveSchedule',false,'canReserve',false,'canActivateFlights',false);END IF;
 SELECT count(*) INTO group2_count
 FROM airlinerra_game.airport_group2_game_profiles_v1 g
 WHERE g.airport_key IN(p_origin_key,p_destination_key);
 IF group2_count<>2 THEN RETURN jsonb_build_object(
  'decision','BLOCKED_ROUTE_NOT_TWO_GROUP2_AIRPORTS',
  'canSaveSchedule',false,'canReserve',false,'canActivateFlights',false);END IF;
 preview:=airlinerra_game.group2_combined_route_safety_preview_v1(
  p_origin_key,p_destination_key,ac.configuration_id,
  p_reference_departure_utc,p_reference_arrival_utc,
  p_weekly_schedule,p_departure_stand,p_arrival_stand);
 RETURN jsonb_build_object(
  'decision','BLOCKED_GROUP2_AIRPORT_NOT_ADMITTED',
  'routeSafetyDecision',preview->>'decision',
  'routeSafetyPreview',preview,
  'ownedAirlineAndAircraftVerified',true,
  'aircraftConfigurationId',ac.configuration_id,
  'airportCommercialApproval',false,
  'liveSlotReservationAuthority',false,
  'aircraftMovementRelease',false,
  'canSaveSchedule',false,
  'canReserve',false,
  'canActivateFlights',false,
  'reviewRequired',coalesce((preview->>'decision') LIKE 'REVIEW_%',false),
  'previewOnly',true
 );
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.group2_owned_aircraft_route_preflight_v1(
 uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)
 FROM PUBLIC,anon,authenticated;
DO $$
DECLARE r jsonb;
BEGIN
 r:=airlinerra_game.group2_owned_aircraft_route_preflight_v1(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000003',
  'OURAIRPORTS:20581','OURAIRPORTS:46583',
  '2026-11-10T14:00:00Z','2026-11-10T19:00:00Z',
  '[{"day":1,"time":"06:00"}]'::jsonb,'terminal','terminal');
 IF r->>'decision'<>'BLOCKED_NOT_OWNED_ACTIVE_AIRLINE_OR_AIRCRAFT'
 OR r->>'canSaveSchedule'<>'false'
 THEN RAISE EXCEPTION 'GROUP2_OWNER_ROUTE_PREFLIGHT_POSTCHECK_FAILED';END IF;
END $$;